//! XyDesk host — titik masuk.
//!
//! Alur: daftar ke signaling → tunggu `pair` (verifikasi password) →
//! terima `offer` dari client → jawab → terima kandidat ICE client →
//! terima data channel "input". Sumber video (DXGI) menyusul di `screen.rs`.
//!
//! Identitas: ID perangkat (9 digit, format `123 456 789`) + password pairing
//! (persisten, bisa di-customize via `--set-password` / `--new-password`).

use std::sync::{Arc, Mutex};

use anyhow::{Context, Result};
use clap::Parser;
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::tungstenite::http::HeaderValue;
use tokio_tungstenite::tungstenite::Message;

use webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState;
use xydesk_host::control::{ControlState, EngineState};
use xydesk_host::pairedpeers::{PairedPeers, PeerLabel};
use xydesk_host::pairguard::{self, PairGuard};
use xydesk_host::recover_lock;
use xydesk_host::session::{slot_action, IceCandidate, Session, SlotAction, DISCONNECT_GRACE};

/// SDP ter-serialisasi (objek `{type, sdp}` — identik dgn sisi client).
#[derive(Serialize, Deserialize, Clone, Debug)]
struct SdpMsg {
    #[serde(rename = "type")]
    kind: String,
    sdp: String,
}

/// Kandidat ICE dari signaling.
#[derive(Serialize, Deserialize, Clone, Debug)]
struct IceMsg {
    candidate: String,
    #[serde(rename = "sdpMid", skip_serializing_if = "Option::is_none")]
    sdp_mid: Option<String>,
    #[serde(rename = "sdpMLineIndex", skip_serializing_if = "Option::is_none")]
    sdp_mline_index: Option<u16>,
}

/// Struktur pesan signaling — identik dengan `signaling/protocol.go`.
#[derive(Serialize, Deserialize, Debug, Default)]
struct Msg {
    #[serde(rename = "type")]
    kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    to: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    from: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pin: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    accepted: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    sdp: Option<SdpMsg>,
    #[serde(skip_serializing_if = "Option::is_none")]
    candidate: Option<IceMsg>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<String>,
    /// Nama perangkat pengirim (mis. "Redmi Note 12"), dikirim client pada
    /// pesan `pair`. Untuk label di panel host saja — tidak pernah dipakai
    /// untuk memutuskan penerimaan pairing.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    name: Option<String>,
    /// Platform pengirim: "android" | "ios" | "windows" | "linux" | "macos" |
    /// "web". Sama seperti `name`, hanya untuk tampilan.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    platform: Option<String>,
}

type Ws =
    tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>;

async fn send_msg(ws: &mut Ws, msg: &Msg) -> Result<()> {
    ws.send(Message::Text(serde_json::to_string(msg)?)).await?;
    Ok(())
}

/// Batas percobaan sambung-ulang dalam proses sebelum menyerah dan keluar —
/// supaya supervisor Electron meminta token signaling BARU. Token host
/// berumur pendek (≈5 menit, lihat signaling/auth.go); kalau jaringan benar-
/// benar down melewati jendela itu, token lama tidak berguna lagi.
const RECONNECT_MAX_ATTEMPTS: u32 = 10;

/// Jeda antar percobaan sambung-ulang: 1, 2, 4, 8, 16, lalu mentok 30 detik.
fn reconnect_delay(attempt: u32) -> std::time::Duration {
    let shift = attempt.saturating_sub(1).min(5);
    std::time::Duration::from_secs((1u64 << shift).min(30))
}

/// Cabut slot sesi: izin pairing dicabut, status shell kembali "siap", dan
/// peer connection-nya DITUTUP.
///
/// Menutup peer connection adalah bagian yang dulu hilang. Tanpa itu, sesi
/// yang slotnya sudah dicabut terus memegang capture + encoder: loop video
/// hanya berhenti saat pc `Closed`/`Failed`, dan tidak ada yang pernah menutup
/// pc-nya. Di Windows efeknya berlipat — duplikasi DXGI yang menggantung bisa
/// membuat sesi berikutnya mendapat layar hitam.
///
/// `Handle` dibawa dari pemanggil (bukan `Handle::current()` di dalam) karena
/// handler status WebRTC dipanggil dari dalam kita: menaruh tugas di antrean
/// runtime lebih aman daripada memanggil ulang API runtime di tempat yang tidak
/// kita kendalikan.
fn release_slot(
    handle: &tokio::runtime::Handle,
    paired: &Arc<Mutex<PairedPeers>>,
    control: &Arc<Mutex<ControlState>>,
    client: &str,
    session: &Arc<Session>,
) {
    // Hanya kalau sesi yang tercatat di control API masih sesi ini. Tanpa
    // syarat ini, teardown sesi lama menghapus keadaan (dan izin) sesi baru
    // yang sudah streaming — shell lalu bilang "siap" padahal ada orang yang
    // sedang melihat layar.
    if !recover_lock(control).stop_session_if_current(session) {
        return;
    }
    recover_lock(paired).revoke(client);
    let sess = session.clone();
    handle.spawn(async move {
        let _ = sess.close().await;
    });
}

#[derive(Parser, Debug)]
#[command(name = "xydesk-host", about = "XyDesk host — stream layar ke client")]
struct Args {
    /// URL signaling server (mis. wss://signal.xystudio.my.id/ws)
    #[arg(long, default_value = "ws://localhost:8787/ws")]
    url: String,
    /// DeviceId host ini (opsional — otomatis digenerasi & disimpan bila kosong)
    #[arg(long)]
    id: Option<String>,
    /// Nama tampilan host
    #[arg(long, default_value = "XyDesk Host")]
    name: String,
    /// Token signaling host berumur pendek dari aplikasi XyDesk
    #[arg(long)]
    token: Option<String>,
    /// Cetak identitas host sebagai JSON untuk launcher terpadu, lalu keluar
    #[arg(long)]
    identity_json: bool,
    /// Server STUN (kosongkan untuk LAN murni)
    #[arg(long, default_value = "stun:stun.cloudflare.com:3478")]
    stun: String,
    /// Ganti password pairing dengan nilai kustom (min 6 karakter), lalu keluar
    #[arg(long)]
    set_password: Option<String>,
    /// Generasi ulang password acak (persisten), lalu keluar
    #[arg(long)]
    new_password: bool,
    /// Benchmark durasi encode (pola uji, konfigurasi produksi): cetak
    /// avg/p50/p95/max lalu keluar. Ukur budget latency sisi encode.
    #[arg(long, value_name = "FRAME")]
    bench: Option<usize>,
    /// Lebar frame benchmark (default 320; pakai 1920 untuk 1080p)
    #[arg(long, value_name = "PX", default_value_t = xydesk_host::screen::TEST_WIDTH)]
    bench_w: usize,
    /// Tinggi frame benchmark (default 180; pakai 1080 untuk 1080p)
    #[arg(long, value_name = "PX", default_value_t = xydesk_host::screen::TEST_HEIGHT)]
    bench_h: usize,
    /// Port control API lokal untuk shell desktop (127.0.0.1 saja).
    /// 0 = port efemeral (default; shell membaca alamat + token dari stdout).
    #[arg(long, value_name = "PORT", default_value_t = 0)]
    control_port: u16,
}

/// Meta JSON untuk client (layar + audio host) — dikirim lewat data channel
/// input saat sesi dibuka dan setiap kali pilihan layar berubah.
fn meta_json() -> serde_json::Value {
    serde_json::json!({
        "type": "meta",
        "displays": xydesk_host::screen::list_displays(),
        "wanted": xydesk_host::screen::wanted_display(),
        "audio": {
            "available": xydesk_host::audio::capture_available(),
            "pipeline": xydesk_host::audio::capture_status(),
        },
        "mic": {
            "available": xydesk_host::audio::mic_capture_available(),
            "pipeline": xydesk_host::audio::mic_capture_status(),
        }
    })
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // ── Kelola password: --set-password / --new-password (keluar setelahnya) ──
    if let Some(pw) = args.set_password.as_deref().map(str::trim) {
        match xydesk_host::identity::set_password(pw) {
            Ok(()) => {
                println!("[OK] Password pairing diubah menjadi: {pw}");
                return Ok(());
            }
            Err(e) => {
                eprintln!("[GAGAL] {e}");
                std::process::exit(1);
            }
        }
    }
    if args.new_password {
        let pw = xydesk_host::identity::generate_password();
        xydesk_host::identity::set_password(&pw)?;
        println!("[OK] Password pairing baru: {pw}");
        return Ok(());
    }

    // ── Benchmark encode: ukur budget latency sisi encode, lalu keluar ──
    if let Some(n) = args.bench {
        let n = n.clamp(10, 100_000);
        let (w, h) = (args.bench_w.max(64), args.bench_h.max(64));
        let mut enc = xydesk_host::screen::TestPatternEncoder::with_config(
            xydesk_host::screen::prod_encoder_config(),
        )?;
        let mut samples: Vec<f64> = Vec::with_capacity(n);
        for _ in 0..n {
            let t = std::time::Instant::now();
            let data = enc.encode_next(w, h)?;
            samples.push(t.elapsed().as_secs_f64() * 1000.0);
            let _ = data; // hanya ukur kecepatan, frame dibuang
        }
        samples.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let avg = samples.iter().sum::<f64>() / samples.len() as f64;
        let p50 = samples[n / 2];
        let p95 = samples[(n as f64 * 0.95) as usize - 1];
        let max = *samples.last().unwrap_or(&0.0);
        println!("Benchmark encode openh264 (konfigurasi produksi, pola uji {w}x{h}, {n} frame):");
        println!("  avg {avg:.2} ms | p50 {p50:.2} ms | p95 {p95:.2} ms | max {max:.2} ms");
        if avg < 10.0 && w * h >= 1280 * 720 {
            println!("  Target roadmap (<10 ms @1080p60): TERPENUHI di resolusi ini.");
        } else if avg < 10.0 {
            println!("  Target roadmap (<10 ms @1080p60): TERPENUHI di {w}x{h} — ukur ulang @1080p untuk angka final.");
        } else {
            println!(
                "  Target roadmap (<10 ms @1080p60): BELUM — pertimbangkan NVENC/AMF/QuickSync."
            );
        }
        println!(
            "  Catatan: angka ini hanya waktu encode (CPU). Capture DXGI + jaringan + decode client belum terukur."
        );
        return Ok(());
    }

    // ── Identitas: ID perangkat (stabil) + password pairing (persisten) ──
    let device_id = args
        .id
        .clone()
        .unwrap_or_else(xydesk_host::identity::load_or_create_device_id);
    let password = xydesk_host::identity::load_or_create_password();

    if args.identity_json {
        println!(
            "{}",
            serde_json::json!({
                "deviceId": device_id.clone(),
                "password": password.clone(),
            })
        );
        return Ok(());
    }
    let token = args
        .token
        .as_deref()
        .context("--token wajib saat menjalankan Host")?;

    // ── Control API lokal (shell desktop: Electron + Next.js, desktop/) ──
    // Keadaan mesin ini dibagikan ke loop signaling di bawah DAN ke server
    // HTTP (lihat control.rs). Token dicetak sekali — hanya shell yang
    // men-spawn proses ini yang membacanya.
    let control = Arc::new(Mutex::new(ControlState::new(
        device_id.clone(),
        password.clone(),
        args.url.clone(),
    )));
    let control_server = xydesk_host::control::start(control.clone(), args.control_port).await?;
    println!(
        "[control] http://127.0.0.1:{} token={}",
        control_server.addr.port(),
        control_server.token
    );

    println!(
        "[xydesk-host] sumber video: {}",
        xydesk_host::screen::capture_status()
    );
    println!();
    println!("  ╔══════════════════════════════════════════╗");
    println!("  ║   XyDesk Host — siap menerima koneksi    ║");
    println!("  ╠══════════════════════════════════════════╣");
    println!(
        "  ║   ID       : {:<26}║",
        xydesk_host::identity::format_id(&device_id)
    );
    println!("  ║   Password : {:<26}║", password);
    println!("  ╚══════════════════════════════════════════╝");
    println!();
    println!("  Ketik ID + Password ini di aplikasi XyDesk di HP.");
    println!("  Ganti password: xydesk-host --set-password <baru>");
    // Penanda "password lama" (tanpa satu pun huruf kecil) = besar-kecil tidak
    // dihitung oleh host. Berguna untuk HP/APK lama, tetapi memangkas separuh
    // ruang tebakan, jadi diingatkan sekali di startup — bukan dipaksa ganti.
    if xydesk_host::identity::is_legacy_shape(&password) {
        println!(
            "[xydesk-host] Catatan: password ini tidak punya huruf kecil, jadi host tidak membedakan besar/kecil saat memverifikasinya."
        );
        println!("[xydesk-host]        Untuk proteksi penuh, jalankan: xydesk-host --new-password");
    }

    let stun = args.stun.clone();
    // Penjaga brute force pairing — lihat pairguard.rs untuk model ancamannya.
    let mut guard = PairGuard::new(std::time::Instant::now());
    // Siapa yang BOLEH membuka sesi media. `pairguard` membatasi laju tebakan
    // password; registri ini yang memastikan hanya peer yang benar-benar lulus
    // tebakan itu bisa melanjutkan ke `offer`. Lihat pairedpeers.rs.
    //
    // Dibungkus Arc<Mutex<..>> karena bukan hanya loop ini yang mengubahnya:
    // handler status WebRTC (lihat arm "offer") harus bisa melepas slot sesi
    // saat client hilang tanpa mengirim `bye`.
    let paired = Arc::new(Mutex::new(PairedPeers::new()));
    // Registri yang sama juga dipakai aksi control API `stop-session` — satu
    // sumber kebenaran izin, dua pemanggil.
    recover_lock(&control).paired = Some(paired.clone());

    // Host harus SELALU AKTIF. Koneksi signaling bisa putus kapan saja
    // (jaringan putus, deploy server, atau server menutup koneksi yang diam
    // karena kita lambat membalas ping). Loop ini menyambung ulang DALAM
    // proses dengan backoff — proses tidak keluar hanya karena signaling
    // putus. Sebelumnya satu putus = main() return = proses mati, lalu
    // supervisor me-restart — siklus "hidup-mati-hidup-mati" yang terlihat
    // oleh pemakai.
    let mut attempt: u32 = 0;
    loop {
        // Sesi media mati bersama koneksi signaling — mulai bersih tiap putaran.
        let mut active: Option<Arc<Session>> = None;
        recover_lock(&control).state = EngineState::Connecting;

        let mut req = format!("{}?id={}&role=host", args.url, device_id)
            .into_client_request()
            .context("URL tidak valid")?;
        req.headers_mut().insert(
            "Authorization",
            HeaderValue::from_str(&format!("Bearer {token}"))?,
        );

        let mut ws = match connect_async(req).await {
            Ok((ws, _)) => ws,
            // Server menolak token (HTTP 401/403) — token host berumur pendek
            // (≈5 menit). Sambung ulang dengan token lama percuma; keluar agar
            // supervisor meminta token baru.
            Err(tokio_tungstenite::tungstenite::Error::Http(resp)) => {
                let code = resp.status().as_u16();
                eprintln!(
                    "[xydesk-host] signaling menolak token (HTTP {code}) — keluar; supervisor akan meminta token baru"
                );
                return Err(anyhow::anyhow!("signaling menolak token (HTTP {code})"));
            }
            Err(e) => {
                attempt += 1;
                if attempt > RECONNECT_MAX_ATTEMPTS {
                    eprintln!(
                        "[xydesk-host] signaling tak terjangkau setelah {attempt} percobaan — keluar; supervisor akan mencoba lagi"
                    );
                    return Err(anyhow::anyhow!("signaling tak terjangkau: {e}"));
                }
                let delay = reconnect_delay(attempt);
                eprintln!(
                    "[xydesk-host] gagal hubung signaling: {e} — sambung ulang dalam {} dtk",
                    delay.as_secs()
                );
                tokio::time::sleep(delay).await;
                continue;
            }
        };
        attempt = 0;
        println!("[xydesk-host] terhubung ke {}", args.url);

        if send_msg(
            &mut ws,
            &Msg {
                kind: "hello".into(),
                to: Some(device_id.clone()),
                from: Some(args.name.clone()),
                reason: Some("host".into()),
                ..Default::default()
            },
        )
        .await
        .is_err()
        {
            // hello gagal — koneksi mati sebelum sempat dipakai; ulangi.
            continue;
        }

        while let Some(m) = ws.next().await {
            let m = match m {
                Ok(m) => m,
                Err(e) => {
                    eprintln!("[xydesk-host] koneksi error: {e}");
                    break;
                }
            };
            // Balas ping WebSocket: server signaling menutup koneksi yang
            // tidak membalas dalam 90 dtk (pongTimeout di signaling/client.go).
            // Tanpa ini, host idle terputus dan di-restart supervisor tiap
            // ~90 dtk — akar "hidup-mati-hidup-mati".
            if let Message::Ping(p) = &m {
                if ws.send(Message::Pong(p.clone())).await.is_err() {
                    break;
                }
                continue;
            }
            if let Message::Close(_) = &m {
                println!("[xydesk-host] signaling menutup koneksi");
                break;
            }
            let Message::Text(txt) = m else { continue };
            let msg: Msg = match serde_json::from_str(&txt) {
                Ok(v) => v,
                Err(_) => continue,
            };

            match msg.kind.as_str() {
                "welcome" => {
                    println!("[xydesk-host] terdaftar sebagai {}", device_id);
                    recover_lock(&control).state = EngineState::Ready;
                }

                "pair" => {
                    let from = msg.from.unwrap_or_default();
                    let now = std::time::Instant::now();

                    // Gerbang laju SEBELUM password disentuh. Peer yang terkunci
                    // tidak boleh menghabiskan siklus verifikasi, dan yang lebih
                    // penting: tidak boleh mendapat sinyal apa pun soal password.
                    let decision = guard.check(&from, now);
                    if let pairguard::Decision::Denied { reason, retry_in } = decision {
                        println!(
                            "[xydesk-host] pairing DITOLAK dari {from} ({}), coba lagi {} detik",
                            reason.as_str(),
                            retry_in.as_secs()
                        );
                        // Penundaan tetap dipertahankan agar penolakan tidak
                        // terasa lebih cepat daripada kegagalan password biasa.
                        tokio::time::sleep(pairguard::FAILURE_DELAY).await;
                        send_msg(
                            &mut ws,
                            &Msg {
                                kind: "pair-response".into(),
                                to: Some(from),
                                accepted: Some(false),
                                ..Default::default()
                            },
                        )
                        .await?;
                        continue;
                    }

                    // Perbandingan konstan-waktu; lihat identity::verify_password.
                    let ok = msg
                        .pin
                        .as_deref()
                        .map(|p| xydesk_host::identity::verify_password(p, &password))
                        .unwrap_or(false);

                    if ok {
                        guard.record_success(&from);
                        // Izin membuka sesi diberikan DI SINI dan hanya di sini.
                        // Berumur pendek: kalau client tidak melanjutkan ke offer,
                        // password harus dimasukkan ulang.
                        recover_lock(&paired).grant(&from, now);
                        // Label perangkat ("HP apa yang barusan masuk?") dicatat
                        // untuk panel host. Client lama tidak mengirimnya: label
                        // kosong, host menampilkan ID saja, tidak ada yang gagal.
                        let label = PeerLabel::new(msg.name.clone(), msg.platform.clone());
                        recover_lock(&paired).set_label(&from, label.clone());
                        println!(
                            "[xydesk-host] pairing DITERIMA dari {}{}",
                            from,
                            label_suffix(label.as_ref())
                        );
                    } else {
                        let baru_terkunci = guard.record_failure(&from, now);
                        if baru_terkunci {
                            println!(
                                "[xydesk-host] {from} DIKUNCI {} detik setelah {} kali gagal",
                                pairguard::PEER_LOCKOUT.as_secs(),
                                pairguard::MAX_FAILURES_PER_PEER
                            );
                        } else {
                            println!("[xydesk-host] pairing GAGAL dari {from} (password salah)");
                        }
                        if guard.is_globally_locked(now) {
                            println!(
                                "[xydesk-host] PERINGATAN: penguncian global aktif {} detik. \
                             Ada indikasi serangan brute force terdistribusi.",
                                pairguard::GLOBAL_LOCKOUT.as_secs()
                            );
                        }
                        // Penundaan tetap: tidak bergantung isi password maupun
                        // seberapa jauh tebakan cocok, sehingga waktu respons tidak
                        // membocorkan informasi.
                        tokio::time::sleep(pairguard::FAILURE_DELAY).await;
                    }

                    send_msg(
                        &mut ws,
                        &Msg {
                            kind: "pair-response".into(),
                            to: Some(from),
                            accepted: Some(ok),
                            ..Default::default()
                        },
                    )
                    .await?;
                }

                "offer" => {
                    let client = msg.from.clone().unwrap_or_default();
                    let now = std::time::Instant::now();

                    // GERBANG WAJIB. Tanpa ini, penyerang cukup mengirim `offer`
                    // tanpa pernah menebak password: host akan menjawab, membuka
                    // data channel `input`, dan SendInput mulai mengeksekusi
                    // keyboard/mouse di mesin ini. Seluruh pertahanan pairguard
                    // dilewati karena jalur yang dijaga bukan jalur yang dipakai.
                    let gate = recover_lock(&paired).authorize_offer(&client, now);
                    if let Err(reason) = gate {
                        println!(
                            "[xydesk-host] offer DITOLAK dari {client} ({})",
                            reason.as_str()
                        );
                        send_msg(
                            &mut ws,
                            &Msg {
                                kind: "error".into(),
                                to: Some(client),
                                error: Some(reason.as_str().into()),
                                reason: Some("offer".into()),
                                ..Default::default()
                            },
                        )
                        .await?;
                        continue;
                    }

                    let sdp = msg.sdp.clone().context("offer tanpa SDP")?;
                    println!("[xydesk-host] menerima offer dari {client}");

                    let session = Arc::new(Session::new(vec![stun.clone()], vec![]).await?);
                    // Track WAJIB didaftarkan sebelum answer (dilakukan di dalam
                    // `answer_media`): kalau tidak, SDP jawaban tidak berisi m-line
                    // dan client tidak pernah mendapat gambar. Lihat session.rs.
                    // Audio forward aktif bila platform mendukung (WASAPI Windows).
                    let audio_on = xydesk_host::audio::capture_available();
                    // Mic host aktif otomatis bila ada mikrofon yang terdeteksi —
                    // tidak ada toggle (standar remote desktop).
                    let mic_on = xydesk_host::audio::mic_capture_available();
                    let media = session.answer_media(&sdp.sdp, audio_on, mic_on).await?;
                    let video_track = media.video;
                    let audio_track = media.audio;
                    let mic_track = media.mic;
                    let answer = media.sdp;

                    send_msg(
                        &mut ws,
                        &Msg {
                            kind: "answer".into(),
                            to: Some(client.clone()),
                            sdp: Some(SdpMsg {
                                kind: "answer".into(),
                                sdp: answer,
                            }),
                            ..Default::default()
                        },
                    )
                    .await?;

                    // Client bisa hilang tanpa sempat mengirim `bye` (mati listrik,
                    // kereta masuk terowongan, proses di-kill). Tanpa handler ini
                    // slot sesi tetap dianggap terisi dan host menolak SEMUA koneksi
                    // berikutnya dengan "host-sibuk" sampai di-restart manual.
                    //
                    // `Disconnected` TIDAK diperlakukan sama dengan `Failed`: ia
                    // keadaan sementara yang biasa pulih sendiri, dan keputusan
                    // itu diambil di satu tempat (`session::slot_action`) supaya
                    // bisa diuji. Pelepasan slot selalu disertai menutup peer
                    // connection — kalau tidak, capture + encoder sesi yang sudah
                    // ditinggalkan terus hidup tanpa penonton.
                    {
                        let paired = paired.clone();
                        let client = client.clone();
                        let control = control.clone();
                        let sess = session.clone();
                        let handle = tokio::runtime::Handle::current();
                        session.on_state_change(move |state| match slot_action(state) {
                            SlotAction::Keep => {}
                            SlotAction::ReleaseNow => {
                                println!("[xydesk-host] koneksi {client} {state} — slot dilepas");
                                release_slot(&handle, &paired, &control, &client, &sess);
                            }
                            SlotAction::ReleaseAfterGrace => {
                                // Beri masa tenggang sebelum mencabut. Kandidat
                                // ICE dari peer ini masih diterima selama izin
                                // pairnya utuh, jadi koneksi yang pulih sendiri
                                // benar-benar bisa lanjut tanpa pairing ulang.
                                let paired = paired.clone();
                                let control = control.clone();
                                let client = client.clone();
                                let sess = sess.clone();
                                // `Handle` dipakai dua kali: untuk menaruh tugas
                                // dan untuk menaruh teardown-nya nanti — jangan
                                // dipindah ke dalam block async.
                                let timer = handle.clone();
                                handle.spawn(async move {
                                    tokio::time::sleep(DISCONNECT_GRACE).await;
                                    let kini = sess.peer().connection_state();
                                    if kini == RTCPeerConnectionState::Connected {
                                        println!("[xydesk-host] {client} pulih sendiri — sesi lanjut");
                                        return;
                                    }
                                    println!(
                                        "[xydesk-host] {client} tidak pulih dalam {} detik (keadaan {kini}) — slot dilepas",
                                        DISCONNECT_GRACE.as_secs()
                                    );
                                    release_slot(&timer, &paired, &control, &client, &sess);
                                });
                            }
                        });
                    }

                    // Terima input (data channel) di task terpisah.
                    {
                        let session = session.clone();
                        tokio::spawn(async move {
                            match session.receive_input_channel().await {
                                Ok(dc) => {
                                    println!("[xydesk-host] data channel input terbuka");
                                    // Kirim META ke client: daftar layar + status
                                    // audio host. Client memakai ini untuk
                                    // pemilihan monitor dan label audio jujur.
                                    let _ = dc.send_text(meta_json().to_string()).await;
                                    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
                                    dc.on_message(Box::new(move |m| {
                                        if !m.is_string {
                                            let _ = tx.send(m.data.to_vec());
                                        }
                                        Box::pin(async {})
                                    }));
                                    // Injeksi di thread blocking terpisah: SendInput
                                    // adalah syscall sinkron — jangan blokir runtime
                                    // async yang juga melayani video/ICE.
                                    let (inj_tx, inj_rx) = std::sync::mpsc::channel::<
                                        xydesk_host::input::InputEvent,
                                    >();
                                    std::thread::spawn(move || {
                                        let injector = xydesk_host::input::Injector::new();
                                        while let Ok(ev) = inj_rx.recv() {
                                            if !injector.inject(&ev) {
                                                eprintln!("[xydesk-host] inject gagal: {ev:?}");
                                            }
                                        }
                                    });
                                    while let Some(data) = rx.recv().await {
                                        // Pesan rusak dibuang diam-diam (decode → None):
                                        // input korup tidak boleh mematikan sesi.
                                        if let Some(ev) = xydesk_host::input::decode(&data) {
                                            // Papan klip = bukan injeksi SendInput.
                                            // CLIPBOARD_SET menulis ke papan klip
                                            // PC; CLIPBOARD_REQ meminta isinya
                                            // dikirim balik ke klien (model tarik —
                                            // lihat modul `clipboard`).
                                            match ev {
                                            xydesk_host::input::InputEvent::ClipboardSet(text) => {
                                                match tokio::task::spawn_blocking(move || {
                                                    xydesk_host::clipboard::set_text(&text)
                                                })
                                                .await
                                                {
                                                    Ok(Ok(())) => println!(
                                                        "[xydesk-host] papan klip PC diisi dari client"
                                                    ),
                                                    Ok(Err(e)) => eprintln!(
                                                        "[xydesk-host] papan klip gagal diisi: {e:#}"
                                                    ),
                                                    Err(e) => eprintln!(
                                                        "[xydesk-host] task papan klip gagal: {e}"
                                                    ),
                                                }
                                                continue;
                                            }
                                            xydesk_host::input::InputEvent::ClipboardRequest => {
                                                match tokio::task::spawn_blocking(|| {
                                                    xydesk_host::clipboard::get_text()
                                                })
                                                .await
                                                {
                                                    Ok(Ok(text)) => {
                                                        let out = xydesk_host::input::encode_clipboard_set(&text);
                                                        let _ = dc.send(&bytes::Bytes::from(out)).await;
                                                    }
                                                    Ok(Err(e)) => eprintln!(
                                                        "[xydesk-host] papan klip PC gagal dibaca: {e:#}"
                                                    ),
                                                    Err(e) => eprintln!(
                                                        "[xydesk-host] task papan klip gagal: {e}"
                                                    ),
                                                }
                                                continue;
                                            }
                                            _ => {}
                                        }

                                            // Pindah monitor = bukan injeksi: setel
                                            // pilihan + kirim meta terbaru.
                                            if let xydesk_host::input::InputEvent::DisplaySelect(
                                                i,
                                            ) = ev
                                            {
                                                xydesk_host::screen::select_display(i);
                                                let _ = dc.send_text(meta_json().to_string()).await;
                                                continue;
                                            }
                                            let _ = inj_tx.send(ev);
                                        }
                                    }
                                }
                                Err(e) => eprintln!("[xydesk-host] input channel gagal: {e:#}"),
                            }
                        });
                    }

                    // Sumber video: capture layar (Windows DXGI) atau pola uji.
                    // Frame H264 ter-encode diambil dari channel, ditulis ke track
                    // yang sudah terdaftar di dalam `Session::answer` di atas.
                    // Loop streaming + statistik ada di `video::pump_video` (juga
                    // dipakai test integrasi — jalur yang diuji = kode produksi).
                    {
                        let control = control.clone();
                        let session = session.clone();
                        tokio::spawn(async move {
                            let track = video_track;

                            // Channel std (blocking) dari capture TIDAK boleh
                            // di-recv langsung di task async — itu membekukan
                            // worker tokio. Jembatan: thread blocking meneruskan
                            // frame ke channel tokio berkapasitas 1 (frame usang
                            // dibuang, latency menang).
                            let frames = xydesk_host::screen::spawn_frame_source();
                            let (vtx, vrx) =
                                tokio::sync::mpsc::channel::<xydesk_host::screen::EncodedFrame>(1);
                            std::thread::spawn(move || {
                                while let Ok(frame) = frames.recv() {
                                    if vtx.blocking_send(frame).is_err() {
                                        break;
                                    }
                                }
                            });

                            xydesk_host::video::pump_video(&session, &track, vrx, control).await;
                        });
                    }

                    // Audio forward (host → client): WASAPI loopback → paket Opus
                    // → track audio. Berjalan di task sendiri; thread capture
                    // blocking dijembatani ke channel tokio (kapasitas kecil —
                    // paket lama dibuang, latency menang).
                    if let Some(audio_track) = audio_track {
                        tokio::spawn(async move {
                            println!("[xydesk-host] audio loopback aktif (opus 48kHz stereo)");
                            let packets = xydesk_host::audio::spawn_audio_source();
                            let (atx, mut arx) = tokio::sync::mpsc::channel::<Vec<u8>>(1);
                            std::thread::spawn(move || {
                                while let Ok(pkt) = packets.recv() {
                                    if atx.blocking_send(pkt).is_err() {
                                        break;
                                    }
                                }
                            });
                            while let Some(pkt) = arx.recv().await {
                                let sample = webrtc::media::Sample {
                                    data: bytes::Bytes::from(pkt),
                                    timestamp: std::time::SystemTime::now(),
                                    duration: std::time::Duration::from_millis(20),
                                    packet_timestamp: 0,
                                    prev_dropped_packets: 0,
                                    prev_padding_packets: 0,
                                };
                                if let Err(e) = audio_track.write_sample(&sample).await {
                                    eprintln!("[xydesk-host] kirim paket audio gagal: {e}");
                                    break;
                                }
                            }
                        });
                    }

                    // Mic host (host → client): WASAPI eCapture → Opus mono → track
                    // audio kedua (stream `mic`). Otomatis — hanya menyala bila ada
                    // mikrofon yang terdeteksi. Jalur mirror dari forward di atas.
                    if let Some(mic_track) = mic_track {
                        tokio::spawn(async move {
                            println!("[xydesk-host] mic host aktif (opus 48kHz mono)");
                            let packets = xydesk_host::audio::spawn_mic_source();
                            let (mtx, mut mrx) = tokio::sync::mpsc::channel::<Vec<u8>>(1);
                            std::thread::spawn(move || {
                                while let Ok(pkt) = packets.recv() {
                                    if mtx.blocking_send(pkt).is_err() {
                                        break;
                                    }
                                }
                            });
                            while let Some(pkt) = mrx.recv().await {
                                let sample = webrtc::media::Sample {
                                    data: bytes::Bytes::from(pkt),
                                    timestamp: std::time::SystemTime::now(),
                                    duration: std::time::Duration::from_millis(20),
                                    packet_timestamp: 0,
                                    prev_dropped_packets: 0,
                                    prev_padding_packets: 0,
                                };
                                if let Err(e) = mic_track.write_sample(&sample).await {
                                    eprintln!("[xydesk-host] kirim paket mic gagal: {e}");
                                    break;
                                }
                            }
                        });
                    }

                    // Mic passthrough (client → host): paket Opus dari track audio
                    // client dirender ke perangkat output default. Task berakhir
                    // sendiri bila client tidak mengirim track (timeout 30 dtk).
                    {
                        let session = session.clone();
                        tokio::spawn(async move {
                            let sink = xydesk_host::audio::spawn_audio_sink();
                            let (mtx, mut mrx) = tokio::sync::mpsc::unbounded_channel::<Vec<u8>>();
                            tokio::spawn(async move {
                                if let Err(e) = session.receive_mic(mtx).await {
                                    if e.to_string() != "track mic client tidak kunjung tiba" {
                                        eprintln!("[xydesk-host] mic passthrough berakhir: {e:#}");
                                    }
                                }
                            });
                            // Teruskan ke sink render. `try_send` — paket lama
                            // dibuang bila render tertinggal (latency menang).
                            while let Some(pkt) = mrx.recv().await {
                                let _ = sink.try_send(pkt);
                            }
                        });
                    }

                    // Satu sesi media pada satu waktu. `offer` dari peer yang sama
                    // adalah renegosiasi: sesi LAMA wajib ditutup, bukan sekadar
                    // ditimpa — kalau tidak, capture + encoder-nya hidup terus
                    // tanpa penonton (di Windows, duplikasi DXGI yang menggantung
                    // juga bisa membuat sesi baru dapat layar hitam).
                    let prev = active.replace(session.clone());
                    // Status dicatat SEBELUM sesi lama ditutup, supaya teardown
                    // sesi lama melihat "sesi yang tercatat bukan aku" dan diam.
                    let label = recover_lock(&paired).label_of(&client).cloned();
                    recover_lock(&control).set_streaming(client.clone(), session.clone(), label);
                    if let Some(prev) = prev {
                        let _ = prev.close().await;
                    }
                }

                "ice" => {
                    let from = msg.from.clone().unwrap_or_default();
                    // Kandidat hanya diterima dari peer yang sesinya sedang aktif.
                    // Peer lain tidak punya alasan sah mengirim ICE ke sini, dan
                    // menyuntik kandidat ke sesi orang lain adalah cara termurah
                    // untuk merusak koneksi yang sedang berjalan.
                    if !recover_lock(&paired).is_active(&from) {
                        println!("[xydesk-host] ICE diabaikan dari {from} (bukan sesi aktif)");
                        continue;
                    }
                    if let (Some(session), Some(c)) = (&active, msg.candidate) {
                        session
                            .add_ice_candidate(IceCandidate {
                                candidate: c.candidate,
                                sdp_mid: c.sdp_mid,
                                sdp_mline_index: c.sdp_mline_index,
                            })
                            .await?;
                    }
                }

                "bye" => {
                    let from = msg.from.clone().unwrap_or_default();
                    // Hanya pemilik sesi yang boleh mengakhirinya. Tanpa ini, peer
                    // mana pun bisa memutus sesi orang lain dengan satu pesan.
                    if !recover_lock(&paired).is_active(&from) {
                        println!("[xydesk-host] bye diabaikan dari {from} (bukan sesi aktif)");
                        continue;
                    }
                    println!("[xydesk-host] sesi diakhiri client {from}");
                    if let Some(s) = active.take() {
                        let _ = s.close().await;
                    }
                    // Sesi selesai bukan alasan untuk terus mempercayai peer:
                    // menyambung ulang wajib pairing lagi.
                    recover_lock(&paired).revoke(&from);
                    recover_lock(&control).mark_stopped();
                }
                "error" => println!("[xydesk-host] error: {}", msg.error.unwrap_or_default()),
                other => println!("[xydesk-host] pesan: {other}"),
            }
        } // while let Some(m) = ws.next().await

        // Keluar dari while = koneksi putus. Sambung ulang dalam proses
        // (jeda pendek agar tidak berputar tanpa henti bila server down).
        println!("[xydesk-host] koneksi signaling putus — sambung ulang...");
        tokio::time::sleep(std::time::Duration::from_secs(2)).await;
    } // loop — host hanya keluar lewat error fatal (token ditolak / tak terjangkau)
}

/// Sufiks " — Redmi Note 12 · android" untuk log pairing; kosong bila peer
/// tidak lapor diri (client lama).
fn label_suffix(label: Option<&PeerLabel>) -> String {
    let Some(label) = label else {
        return String::new();
    };
    let bits: Vec<&str> = [label.name.as_deref(), label.platform.as_deref()]
        .into_iter()
        .flatten()
        .collect();
    if bits.is_empty() {
        String::new()
    } else {
        format!(" — {}", bits.join(" · "))
    }
}

#[cfg(test)]
mod tests {
    use super::reconnect_delay;

    #[test]
    fn jeda_sambung_ulang_naik_dan_mentok_30_detik() {
        assert_eq!(reconnect_delay(1).as_secs(), 1);
        assert_eq!(reconnect_delay(2).as_secs(), 2);
        assert_eq!(reconnect_delay(3).as_secs(), 4);
        assert_eq!(reconnect_delay(4).as_secs(), 8);
        assert_eq!(reconnect_delay(5).as_secs(), 16);
        assert_eq!(reconnect_delay(6).as_secs(), 30);
        assert_eq!(reconnect_delay(20).as_secs(), 30);
        // Defensif: attempt 0 tidak pernah dipakai (selalu di-increment dulu),
        // tapi harus tetap aman (tidak panic / tidak nol).
        assert_eq!(reconnect_delay(0).as_secs(), 1);
    }
}

#[cfg(test)]
mod pair_label_tests {
    use super::{label_suffix, Msg};
    use xydesk_host::pairedpeers::PeerLabel;

    #[test]
    fn pair_dari_client_baru_membawa_nama_dan_platform() {
        let m: Msg = serde_json::from_str(
            r#"{"type":"pair","from":"hp-1","pin":"abcd12","name":"Redmi Note 12","platform":"android"}"#,
        )
        .expect("harus bisa dibaca tanpa field yang tidak dikenal pun jadi");
        assert_eq!(m.name.as_deref(), Some("Redmi Note 12"));
        assert_eq!(m.platform.as_deref(), Some("android"));
    }

    #[test]
    fn pair_dari_client_lama_tetap_dibaca() {
        // Pesan tanpa name/platform adalah hal biasa: client lama. Host tidak
        // boleh menolaknya hanya karena tidak ada label.
        let m: Msg =
            serde_json::from_str(r#"{"type":"pair","from":"pc-1","pin":"abcd12"}"#).unwrap();
        assert!(m.name.is_none() && m.platform.is_none());
        assert_eq!(label_suffix(None), "");
    }

    #[test]
    fn label_log_hanya_tampil_kala_ada_isinya() {
        let penuh = PeerLabel::new(Some("Redmi Note 12".into()), Some("android".into()));
        assert_eq!(
            label_suffix(penuh.as_ref()),
            " — Redmi Note 12 · android".to_string()
        );
        let separuh = PeerLabel::new(Some("ThinkPad X1".into()), None);
        assert_eq!(label_suffix(separuh.as_ref()), " — ThinkPad X1".to_string());
        assert_eq!(label_suffix(PeerLabel::new(None, None).as_ref()), "");
    }
}
