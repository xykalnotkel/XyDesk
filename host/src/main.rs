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

use xydesk_host::pairedpeers::PairedPeers;
use xydesk_host::pairguard::{self, PairGuard};
use xydesk_host::session::{IceCandidate, Session};
use xydesk_host::{
    control::{ControlState, EngineState},
    screen,
};

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
}

type Ws =
    tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>;

async fn send_msg(ws: &mut Ws, msg: &Msg) -> Result<()> {
    ws.send(Message::Text(serde_json::to_string(msg)?)).await?;
    Ok(())
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
        }
    })
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // ── Kelola password: --set-password / --new-password (keluar setelahnya) ──
    if let Some(pw) = &args.set_password {
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

    let mut req = format!("{}?id={}&role=host", args.url, device_id)
        .into_client_request()
        .context("URL tidak valid")?;
    req.headers_mut().insert(
        "Authorization",
        HeaderValue::from_str(&format!("Bearer {token}"))?,
    );

    control.lock().unwrap().state = EngineState::Connecting;
    let (mut ws, _) = connect_async(req).await.context("gagal hubung signaling")?;
    println!("[xydesk-host] terhubung ke {}", args.url);

    send_msg(
        &mut ws,
        &Msg {
            kind: "hello".into(),
            to: Some(device_id.clone()),
            from: Some(args.name.clone()),
            reason: Some("host".into()),
            ..Default::default()
        },
    )
    .await?;

    let stun = args.stun.clone();
    // Sesi aktif (satu pada satu waktu untuk PoC).
    let mut active: Option<Arc<Session>> = None;
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
    control.lock().unwrap().paired = Some(paired.clone());

    while let Some(m) = ws.next().await {
        let m = m.context("koneksi putus")?;
        let Message::Text(txt) = m else { continue };
        let msg: Msg = match serde_json::from_str(&txt) {
            Ok(v) => v,
            Err(_) => continue,
        };

        match msg.kind.as_str() {
            "welcome" => {
                println!("[xydesk-host] terdaftar sebagai {}", device_id);
                control.lock().unwrap().state = EngineState::Ready;
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
                    paired.lock().unwrap().grant(&from, now);
                    println!("[xydesk-host] pairing DITERIMA dari {from}");
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
                let gate = paired.lock().unwrap().authorize_offer(&client, now);
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
                let media = session.answer_media(&sdp.sdp, audio_on).await?;
                let video_track = media.video;
                let audio_track = media.audio;
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
                {
                    let paired = paired.clone();
                    let client = client.clone();
                    let control = control.clone();
                    session.on_state_change(move |state| {
                        use webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState;
                        if matches!(
                            state,
                            RTCPeerConnectionState::Failed
                                | RTCPeerConnectionState::Disconnected
                                | RTCPeerConnectionState::Closed
                        ) {
                            println!("[xydesk-host] koneksi {client} {state} — slot dilepas");
                            paired.lock().unwrap().revoke(&client);
                            // Cerminkan juga ke control API agar shell desktop
                            // langsung kembali menampilkan "siap".
                            control.lock().unwrap().mark_stopped();
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
                                let _ = dc
                                    .send_text(meta_json().to_string())
                                    .await;
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
                                let (inj_tx, inj_rx) =
                                    std::sync::mpsc::channel::<xydesk_host::input::InputEvent>();
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
                                        // Pindah monitor = bukan injeksi: setel
                                        // pilihan + kirim meta terbaru.
                                        if let xydesk_host::input::InputEvent::DisplaySelect(i) = ev {
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
                {
                    let control = control.clone();
                    tokio::spawn(async move {
                        let track = video_track;
                        println!("[xydesk-host] track video siap — streaming");

                        // Channel std (blocking) dari capture TIDAK boleh
                        // di-recv langsung di task async — itu membekukan
                        // worker tokio. Jembatan: thread blocking meneruskan
                        // frame ke channel tokio berkapasitas 1 (frame usang
                        // dibuang, latency menang).
                        let frames = xydesk_host::screen::spawn_frame_source();
                        let (vtx, mut vrx) = tokio::sync::mpsc::channel::<Vec<u8>>(1);
                        std::thread::spawn(move || {
                            while let Ok(data) = frames.recv() {
                                if vtx.blocking_send(data).is_err() {
                                    break;
                                }
                            }
                        });

                        // Statistik video untuk control API (shell desktop):
                        // frame terkirim + FPS rata-rata jendela 1 detik +
                        // status encoder NVENC.
                        let mut fps_window: u64 = 0;
                        let mut fps_start = std::time::Instant::now();
                        let mut fps_now = 0.0_f64;

                        while let Some(data) = vrx.recv().await {
                            let sample = webrtc::media::Sample {
                                data: bytes::Bytes::from(data),
                                timestamp: std::time::SystemTime::now(),
                                duration: std::time::Duration::from_millis(33),
                                packet_timestamp: 0,
                                prev_dropped_packets: 0,
                                prev_padding_packets: 0,
                            };
                            if let Err(e) = track.write_sample(&sample).await {
                                eprintln!("[xydesk-host] kirim frame gagal: {e}");
                                break;
                            }
                            fps_window += 1;
                            let elapsed = fps_start.elapsed();
                            if elapsed >= std::time::Duration::from_secs(1) {
                                fps_now = fps_window as f64 / elapsed.as_secs_f64();
                                fps_window = 0;
                                fps_start = std::time::Instant::now();
                            }
                            {
                                let mut st = control.lock().unwrap();
                                st.video.frames_sent += 1;
                                st.video.fps = fps_now;
                                st.video.nvenc = screen::nvenc_active();
                            }
                        }
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

                control
                    .lock()
                    .unwrap()
                    .set_streaming(client.clone(), session.clone());
                active = Some(session);
            }

            "ice" => {
                let from = msg.from.clone().unwrap_or_default();
                // Kandidat hanya diterima dari peer yang sesinya sedang aktif.
                // Peer lain tidak punya alasan sah mengirim ICE ke sini, dan
                // menyuntik kandidat ke sesi orang lain adalah cara termurah
                // untuk merusak koneksi yang sedang berjalan.
                if !paired.lock().unwrap().is_active(&from) {
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
                if !paired.lock().unwrap().is_active(&from) {
                    println!("[xydesk-host] bye diabaikan dari {from} (bukan sesi aktif)");
                    continue;
                }
                println!("[xydesk-host] sesi diakhiri client {from}");
                if let Some(s) = active.take() {
                    let _ = s.close().await;
                }
                // Sesi selesai bukan alasan untuk terus mempercayai peer:
                // menyambung ulang wajib pairing lagi.
                paired.lock().unwrap().revoke(&from);
                control.lock().unwrap().mark_stopped();
            }
            "error" => println!("[xydesk-host] error: {}", msg.error.unwrap_or_default()),
            other => println!("[xydesk-host] pesan: {other}"),
        }
    }

    Ok(())
}
