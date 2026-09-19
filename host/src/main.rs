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

/// Akhir koneksi signaling juga akhir otorisasi sesi media. Arc yang masih
/// dipegang task encoder/input tidak ikut mati saat variabel `active` dibuang.
async fn close_signaling_session(
    active: &mut Option<Arc<Session>>,
    paired: &Arc<Mutex<PairedPeers>>,
    control: &Arc<Mutex<ControlState>>,
) -> Result<()> {
    *recover_lock(paired) = PairedPeers::new();
    {
        let mut state = recover_lock(control);
        state.mark_stopped();
        state.state = EngineState::Connecting;
    }
    if let Some(session) = active.take() {
        session.close().await?;
    }
    Ok(())
}

#[derive(Parser, Debug)]
#[command(name = "xydesk-host", about = "XyDesk host — stream layar ke client")]
struct Args {
    /// Mode strict: hanya virtual display terverifikasi1280x720, tanpa fallback RDP.
    #[arg(long, conflicts_with = "keep_desktop_resolution")]
    virtual_display_720p: bool,
    #[arg(long, requires = "virtual_display_720p")]
    virtual_display_device: Option<String>,
    /// Diagnosis display tanpa identitas/token, perubahan mode, atau install.
    #[arg(long)]
    display_probe: bool,

    /// Jangan meminta mode desktop 16:9 saat sesi terotorisasi dimulai.
    #[arg(long)]
    keep_desktop_resolution: bool,

    /// URL signaling server (mis. wss://signal.xydesk.my.id/ws)
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
    /// Ukur backend capture di mesin ini (±2,5 detik per backend) lalu keluar
    /// tanpa memulai signaling maupun control API. Alat diagnosis layar hitam
    /// di lapangan: backend mana yang benar-benar menghasilkan frame di sini.
    #[arg(long)]
    capture_test: bool,

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
        "desktopMode": xydesk_host::desktop_mode::telemetry(),
        "cursorEmbedded": xydesk_host::screen::cursor_embedded(),
        "video": xydesk_host::video_policy::telemetry(),
        "inputGeometry": xydesk_host::desktop_geometry::active(),
        "audio": {
            "available": xydesk_host::audio::capture_available(),
            "pipeline": xydesk_host::audio::capture_status(),
        },
        "micInput": { "available": xydesk_host::audio::mic_input_available(), "route": "virtual-cable" },
        "mic": {
            "available": xydesk_host::audio::mic_capture_available(),
            "pipeline": xydesk_host::audio::mic_capture_status(),
        },
        // Spesifikasi mesin ini. Client sudah menunggu blok ini sejak lama
        // (`HostMeta.fromJson` → `hardware.*`); sebelumnya selalu null karena
        // host tidak pernah membacanya. Nilai yang gagal dibaca dikirim null
        // supaya UI menulis "Tidak terdeteksi" — bukan angka karangan.
        "hardware": xydesk_host::hwinfo::hardware_json()
    })
}

#[tokio::main]
async fn main() -> Result<()> {
    xydesk_host::desktop_geometry::init_process_dpi();
    let args = Args::parse();
    if args.display_probe {
        println!("{}", xydesk_host::virtual_target::probe());
        return Ok(());
    }
    if args.capture_test {
        jalankan_capture_test();
        return Ok(());
    }

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
    if args.virtual_display_720p {
        xydesk_host::virtual_target::prepare(args.virtual_display_device.as_deref())
            .map_err(anyhow::Error::msg)?;
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

                    let video_level = xydesk_host::video_policy::offer_level(&sdp.sdp);
                    let session = Arc::new(
                        Session::new_with_video_level(vec![stun.clone()], vec![], video_level)
                            .await?,
                    );
                    // Track WAJIB didaftarkan sebelum answer (dilakukan di dalam
                    // `answer_media`): kalau tidak, SDP jawaban tidak berisi m-line
                    // dan client tidak pernah mendapat gambar. Lihat session.rs.
                    // Audio forward aktif bila platform mendukung (WASAPI Windows).
                    let audio_on = xydesk_host::audio::capture_available();
                    // Mic host aktif otomatis bila ada mikrofon yang terdeteksi —
                    // tidak ada toggle (standar remote desktop).
                    let mic_on = xydesk_host::audio::mic_capture_available();
                    let media = session.answer_media(&sdp.sdp, audio_on, mic_on).await?;
                    xydesk_host::video_policy::configure(video_level);
                    if !args.keep_desktop_resolution && !args.virtual_display_720p {
                        let wanted = xydesk_host::screen::wanted_display();
                        if let Some(display) = xydesk_host::screen::list_displays()
                            .into_iter()
                            .find(|d| d.index == wanted)
                        {
                            match tokio::task::spawn_blocking(move || {
                                xydesk_host::desktop_mode::request(display.name, video_level)
                            })
                            .await
                            {
                                Ok(report) => eprintln!("[xydesk-host] desktop 16:9: {report:?}"),
                                Err(e) => eprintln!("[xydesk-host] permintaan desktop gagal: {e}"),
                            }
                        }
                    }

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
                                    let feedback_dc = dc.clone();
                                    let base_meta = meta_json();
                                    tokio::spawn(async move {
                                        let mut tick = tokio::time::interval(
                                            std::time::Duration::from_millis(50),
                                        );
                                        tick.set_missed_tick_behavior(
                                            tokio::time::MissedTickBehavior::Skip,
                                        );
                                        let mut ticks = 0u32;
                                        loop {
                                            tick.tick().await;
                                            if feedback_dc.ready_state()!=webrtc::data_channel::data_channel_state::RTCDataChannelState::Open {break;}
                                            let cursor=xydesk_host::desktop_geometry::cursor_feedback().unwrap_or_else(||serde_json::json!({"type":"cursor","x":0.5,"y":0.5,"visible":false}));
                                            if feedback_dc.buffered_amount().await < 32768
                                                && feedback_dc
                                                    .send_text(cursor.to_string())
                                                    .await
                                                    .is_err()
                                            {
                                                break;
                                            }
                                            ticks += 1;
                                            if ticks % 20 == 0 {
                                                let mut meta = base_meta.clone();
                                                meta["video"] =
                                                    xydesk_host::video_policy::telemetry();
                                                meta["inputGeometry"] = serde_json::json!(
                                                    xydesk_host::desktop_geometry::active()
                                                );
                                                meta["cursorEmbedded"] = serde_json::json!(
                                                    xydesk_host::screen::cursor_embedded()
                                                );
                                                meta["wanted"] = serde_json::json!(
                                                    xydesk_host::screen::wanted_display()
                                                );
                                                meta["displays"] = serde_json::json!(
                                                    xydesk_host::screen::list_displays()
                                                );
                                                if feedback_dc
                                                    .send_text(meta.to_string())
                                                    .await
                                                    .is_err()
                                                {
                                                    break;
                                                }
                                            }
                                        }
                                    });
                                    let wallpaper_busy =
                                        Arc::new(std::sync::atomic::AtomicBool::new(false));
                                    let (tx, mut rx) = tokio::sync::mpsc::channel(128);
                                    let (closed_tx, mut closed_rx) =
                                        tokio::sync::watch::channel(false);
                                    dc.on_close(Box::new(move || {
                                        let _ = closed_tx.send(true);
                                        Box::pin(async {})
                                    }));
                                    dc.on_message(Box::new(move |m| {
                                        let tx = tx.clone();
                                        Box::pin(async move {
                                            if !m.is_string && m.data.len() <= 65536 {
                                                let _ = tx.send(m.data.to_vec()).await;
                                            }
                                        })
                                    }));
                                    // Injeksi di thread blocking terpisah: SendInput
                                    // adalah syscall sinkron — jangan blokir runtime
                                    // async yang juga melayani video/ICE.
                                    let (inj_tx, mut inj_rx) = xydesk_host::input_queue::channel();
                                    let inject_closed = closed_rx.clone();
                                    std::thread::spawn(move || {
                                        let injector = xydesk_host::input::Injector::new();
                                        let mut lease = xydesk_host::input::InputLease::default();
                                        'inject: while let Some(first) = inj_rx.blocking_recv() {
                                            for ev in xydesk_host::input_queue::ready_batch(
                                                &mut inj_rx,
                                                first,
                                            ) {
                                                // Discard stale queued actions after disconnect;
                                                // release only keys/buttons actually injected.
                                                if *inject_closed.borrow() {
                                                    break 'inject;
                                                }
                                                if injector.inject(&ev) {
                                                    lease.applied(&ev);
                                                } else {
                                                    eprintln!(
                                                        "[xydesk-host] injeksi input ditolak"
                                                    );
                                                }
                                            }
                                        }
                                        for event in lease.releases() {
                                            if !injector.inject(&event) {
                                                eprintln!(
                                                    "[xydesk-host] pelepasan input ditolak Windows"
                                                );
                                            }
                                        }
                                    });
                                    let mut last_wallpaper = std::time::Instant::now()
                                        .checked_sub(std::time::Duration::from_secs(15))
                                        .unwrap();
                                    while let Some(data) = tokio::select! {biased; _=closed_rx.changed()=>None, data=rx.recv()=>data}
                                    {
                                        if data.len() == 2 && data[0] == 0x0c {
                                            if xydesk_host::video_policy::request(data[1]) {
                                                xydesk_host::screen::set_target_bitrate_bps(
                                                    xydesk_host::screen::target_bitrate_bps(),
                                                );
                                                let _ = dc.send_text(meta_json().to_string()).await;
                                            }
                                            continue;
                                        }
                                        if data.len() == 5 && data[0] == 0x0d {
                                            let id =
                                                u32::from_le_bytes(data[1..5].try_into().unwrap());
                                            if last_wallpaper.elapsed()
                                                < std::time::Duration::from_secs(10)
                                                || wallpaper_busy
                                                    .swap(true, std::sync::atomic::Ordering::AcqRel)
                                            {
                                                let _ = dc.send_text(serde_json::json!({"type":"wallpaper-error","id":id}).to_string()).await;
                                                continue;
                                            }
                                            last_wallpaper = std::time::Instant::now();
                                            let reply = dc.clone();
                                            let busy = wallpaper_busy.clone();
                                            tokio::spawn(async move {
                                                use base64::Engine;
                                                match tokio::task::spawn_blocking(
                                                    xydesk_host::wallpaper::configured_preview,
                                                )
                                                .await
                                                {
                                                    Ok(Ok(bytes)) => {
                                                        let encoded = base64::engine::general_purpose::STANDARD.encode(bytes);
                                                        let chunks: Vec<_> = encoded
                                                            .as_bytes()
                                                            .chunks(16384)
                                                            .collect();
                                                        // Wallpaper is background traffic, not an
                                                        // unbounded burst ahead of cursor/control replies.
                                                        let transfer = async {
                                                            for (index, chunk) in
                                                                chunks.iter().enumerate()
                                                            {
                                                                while reply.buffered_amount().await
                                                                    >= 32768
                                                                {
                                                                    if reply.ready_state()!=webrtc::data_channel::data_channel_state::RTCDataChannelState::Open{return;}
                                                                    tokio::time::sleep(std::time::Duration::from_millis(20)).await;
                                                                }
                                                                let message=serde_json::json!({"type":"wallpaper","id":id,"index":index,"total":chunks.len(),"data":std::str::from_utf8(chunk).unwrap()}).to_string();
                                                                if reply
                                                                    .send_text(message)
                                                                    .await
                                                                    .is_err()
                                                                {
                                                                    return;
                                                                }
                                                                tokio::time::sleep(std::time::Duration::from_millis(80)).await;
                                                            }
                                                        };
                                                        let _ = tokio::time::timeout(
                                                            std::time::Duration::from_secs(12),
                                                            transfer,
                                                        )
                                                        .await;
                                                    }
                                                    _ => {
                                                        let _ = reply.send_text(serde_json::json!({"type":"wallpaper-error","id":id}).to_string()).await;
                                                    }
                                                }
                                                busy.store(
                                                    false,
                                                    std::sync::atomic::Ordering::Release,
                                                );
                                            });
                                            continue;
                                        }
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

                                            // Pindah monitor / quality / bitrate = bukan injeksi.
                                            match ev {
                                                xydesk_host::input::InputEvent::DisplaySelect(
                                                    i,
                                                ) => {
                                                    xydesk_host::screen::select_display(i);
                                                    let _ =
                                                        dc.send_text(meta_json().to_string()).await;
                                                    continue;
                                                }
                                                xydesk_host::input::InputEvent::VideoQuality(q) => {
                                                    // 0=auto 1=medium 2=high 3=ultra → map ke bitrate preset host
                                                    let bps = match q {
                                                        1 => 8_000_000,
                                                        2 => 15_000_000,
                                                        3 => 25_000_000,
                                                        _ => {
                                                            xydesk_host::screen::DEFAULT_TARGET_BPS
                                                        }
                                                    };
                                                    if q == 0 {
                                                        xydesk_host::screen::set_target_bitrate_bps(
                                                            xydesk_host::screen::DEFAULT_TARGET_BPS,
                                                        );
                                                    } else {
                                                        xydesk_host::screen::set_target_bitrate_bps(
                                                            bps,
                                                        );
                                                    }
                                                    println!("[xydesk-host] quality dari client: {} → {} bps", q, bps);
                                                    continue;
                                                }
                                                xydesk_host::input::InputEvent::VideoBitrate(
                                                    mbps,
                                                ) => {
                                                    if mbps == 0 {
                                                        xydesk_host::screen::set_target_bitrate_bps(
                                                            xydesk_host::screen::DEFAULT_TARGET_BPS,
                                                        );
                                                        println!("[xydesk-host] bitrate auto dari client");
                                                    } else {
                                                        let bps =
                                                            (mbps as u32).clamp(1, 50) * 1_000_000;
                                                        if xydesk_host::screen::set_target_bitrate_bps(bps) {
                                                            println!("[xydesk-host] bitrate dari client: {} Mbps", mbps);
                                                        }
                                                    }
                                                    continue;
                                                }
                                                _ => {}
                                            }
                                            if !xydesk_host::input_queue::send(
                                                &inj_tx,
                                                &mut closed_rx,
                                                ev,
                                            )
                                            .await
                                            {
                                                break;
                                            }
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
                                    match vtx.try_send(frame) {
                                        Ok(()) => {}
                                        Err(tokio::sync::mpsc::error::TrySendError::Closed(_)) => {
                                            break
                                        }
                                        Err(tokio::sync::mpsc::error::TrySendError::Full(_)) => {
                                            xydesk_host::screen::request_keyframe()
                                        }
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

                    // Phone mic → virtual cable recording endpoint. One bounded
                    // queue; wait until session close, including late activation.
                    {
                        let session = session.clone();
                        tokio::spawn(async move {
                            let sink = xydesk_host::audio::spawn_audio_sink();
                            if let Err(e) = session.receive_mic(sink).await {
                                eprintln!("[xydesk-host] mic passthrough berakhir: {e:#}");
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

        // Cabut izin dan tutup media SEBELUM backoff/reconnect. PairGuard
        // tetap hidup: putus-sambung tidak mereset rem brute force.
        if let Err(error) = close_signaling_session(&mut active, &paired, &control).await {
            eprintln!("[xydesk-host] penutupan media gagal: {error:#}");
        }

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

/// Ukur tiap backend capture yang punya primitif mentah (DXGI, GDI) selama
/// ±2,5 detik dan cetak jumlah frame nyatanya. WGC sengaja tidak diukur di
/// sini: sesinya melekat pada pipeline encode penuh, dan bukti hidupnya sudah
/// dilaporkan `/status` lewat `framesCaptured` saat sesi berjalan.
#[cfg(target_os = "windows")]
fn jalankan_capture_test() {
    use xydesk_host::screen;
    const DUR: std::time::Duration = std::time::Duration::from_millis(2500);

    println!("== capture test: 2,5 detik per backend, monitor pertama ==");
    let displays = screen::list_displays();
    let Some(info) = displays.first() else {
        println!("tidak ada monitor terdeteksi");
        return;
    };
    println!("monitor 0: {} ({}x{})", info.name, info.width, info.height);

    match xydesk_host::dxgi::DxgiCapture::baru(&info.name) {
        Ok(mut cap) => {
            let (w, h) = (cap.width(), cap.height());
            let t = std::time::Instant::now();
            let mut n = 0u64;
            while t.elapsed() < DUR {
                match cap.grab(100) {
                    Ok(true) => n += 1,
                    Ok(false) => {}
                    Err(e) => {
                        println!(
                            "dxgi-duplication : putus di tengah uji — {e} ({n} frame sejauh ini)"
                        );
                        break;
                    }
                }
            }
            println!("dxgi-duplication : {n} frame / 2,5 dtk ({w}x{h})");
            if n > 0 {
                println!(
                    "dxgi RGB-nonzero (frame terakhir): {}/{} piksel",
                    xydesk_host::pixfmt::rgb_nonzero_pixels(cap.pixels()),
                    cap.pixels().len() / 4
                );
            }
        }
        Err(e) => println!("dxgi-duplication : GAGAL dibuka — {e}"),
    }

    match xydesk_host::gdi::GdiCapture::baru(&info.name, info.width as usize, info.height as usize)
    {
        Ok(mut cap) => {
            let t = std::time::Instant::now();
            let mut n = 0u64;
            let mut rgb_last = None;
            while t.elapsed() < DUR {
                match cap.grab() {
                    Ok((pixels, _, _)) => {
                        n += 1;
                        rgb_last = Some((
                            xydesk_host::pixfmt::rgb_nonzero_pixels(pixels),
                            pixels.len() / 4,
                        ));
                    }
                    Err(e) => {
                        println!("gdi-bitblt: gagal mengambil frame — {e}");
                        break;
                    }
                }
                std::thread::sleep(std::time::Duration::from_millis(16));
            }
            println!("gdi-bitblt       : {n} frame / 2,5 dtk");
            if let Some((nonzero, total)) = rgb_last {
                println!("gdi RGB-nonzero (frame terakhir): {nonzero}/{total} piksel");
            }
        }
        Err(e) => println!("gdi-bitblt       : GAGAL dibuka — {e}"),
    }
    println!("RGB-nonzero bukan bukti gambar desktop benar; nol RGB juga sah untuk layar hitam. Uji dengan Notepad putih terlihat dan digerakkan. Tidak menyimpan gambar atau memakai signaling.");
    println!("catatan: windows-graphics-capture diukur saat sesi berjalan (lihat framesCaptured di /status)");
}

#[cfg(not(target_os = "windows"))]
fn jalankan_capture_test() {
    println!("--capture-test hanya bermakna di Windows (backend capture ada di sana).");
}

#[cfg(test)]
mod signaling_cleanup_tests {
    use super::*;

    #[tokio::test]
    async fn signaling_putus_menutup_peer_dan_mencabut_semua_izin() {
        // URL kosong adalah kontrak --stun "" (LAN-only), bukan URI invalid.
        let session = Arc::new(Session::new(vec![String::new()], vec![]).await.unwrap());
        let paired = Arc::new(Mutex::new(PairedPeers::new()));
        let now = std::time::Instant::now();
        recover_lock(&paired).grant("aktif", now);
        recover_lock(&paired).authorize_offer("aktif", now).unwrap();
        recover_lock(&paired).grant("menunggu", now);
        let control = Arc::new(Mutex::new(ControlState::new(
            "100200300".into(),
            "test-only".into(),
            "ws://local".into(),
        )));
        recover_lock(&control).set_streaming("aktif".into(), session.clone(), None);
        let mut active = Some(session.clone());
        close_signaling_session(&mut active, &paired, &control)
            .await
            .unwrap();
        assert!(active.is_none());
        assert_eq!(
            session.peer().connection_state(),
            RTCPeerConnectionState::Closed
        );
        assert_eq!(recover_lock(&paired).tracked(), 0);
        assert!(recover_lock(&control).session.is_none());
        assert_eq!(recover_lock(&control).state, EngineState::Connecting);
        // Pemanggilan ulang aman, termasuk koneksi tanpa sesi.
        close_signaling_session(&mut active, &paired, &control)
            .await
            .unwrap();
    }
}
