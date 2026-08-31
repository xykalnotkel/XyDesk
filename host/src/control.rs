//! Control API lokal — HTTP di `127.0.0.1` untuk shell desktop
//! (Electron + Next.js, lihat `desktop/`).
//!
//! ## Kenapa ada modul ini
//!
//! Shell desktop menggantikan GUI native Win32 (`src/bin/gui.rs`) sebagai
//! launcher + panel. GUI native dulu membaca identitas lewat `--identity-json`
//! dan menjaga engine hidup lewat watchdog, tetapi tidak pernah tahu apa yang
//! terjadi DI DALAM engine (sesi aktif, statistik video). Tanpa kanal balik,
//! panel UI hanya bisa menebak dari log stdout.
//!
//! Control API adalah kanal balik itu: status mesin, sesi aktif, statistik
//! video, dan aksi (password baru, akhiri sesi) — semuanya lewat HTTP lokal.
//!
//! ## Model ancaman (dan kenapa bentuknya begini)
//!
//! - **Hanya bind `127.0.0.1`.** Tidak pernah `0.0.0.0` — API ini bukan untuk
//!   remote. Proses lain di mesin yang sama tetap bisa akses, karena itu:
//! - **Token per-lahir acak (128 bit, hex 32 karakter).** Dicetak sekali ke
//!   stdout; hanya pemilik proses engine (shell yang men-spawn-nya) yang
//!   membacanya. Perbandingan token memakai hash SHA-256 + akumulasi XOR —
//!   konstan-waktu, sama seperti `identity::verify_password`.
//! - **Bukan pengganti pairing.** `stop-session` memang bisa mengakhiri sesi
//!   streaming, tetapi aksi yang mengubah kepercayaan (pairing, izin offer)
//!   tetap berada di jalur signaling yang dijaga `pairguard`/`pairedpeers`.
//!   Control API TIDAK bisa memberi izin pairing.
//!
//! Aksi "new-password"/"set-password" memang menyentuh password pairing —
//! itu sengaja: shell desktop menampilkan dan mengubah password yang sama
//! dengan GUI native dulu (pemilik mesin = pemilik control API).
//!
//! ## Batas yang disengaja
//!
//! Status dibaca **polling** (shell memanggil `/status` tiap 1–2 detik).
//! Tanpa push-event/WebSocket, implementasi jauh lebih kecil dan risiko
//! kebocoran event lebih sedikit. Latensi 1–2 detik tidak berarti untuk
//! panel status.

use std::net::SocketAddr;
use std::sync::{Arc, Mutex};

use anyhow::Context;
use axum::extract::State;
use axum::http::{HeaderMap, StatusCode};
use axum::routing::{get, post};
use axum::{Json, Router};
use rand::Rng;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::identity;
use crate::pairedpeers::PairedPeers;
use crate::session::Session;

/// Nama header pembawa token control. Sengaja pakai nama netral (bukan
/// `Authorization`) agar tidak tertukar dengan token signaling host.
pub const TOKEN_HEADER: &str = "x-xydesk-token";

/// Keadaan mesin engine — dikonsumsi shell untuk pill status.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum EngineState {
    /// Proses baru lahir; belum selesai memuat identitas.
    Starting,
    /// Menghubungkan WebSocket signaling.
    Connecting,
    /// Terdaftar di signaling; menunggu pairing.
    Ready,
    /// Sesuatu yang fatal terjadi (dipakai bila engine tidak langsung keluar).
    Error,
    /// Streaming aktif — ada sesi media yang berjalan.
    Streaming,
}

/// Statistik video yang diisi task streaming (lihat `main.rs`).
#[derive(Clone, Copy, Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VideoStats {
    /// Jumlah frame H264 yang berhasil ditulis ke track RTP.
    pub frames_sent: u64,
    /// FPS kirim rata-rata (jendela 1 detik, diukur di sisi tokio).
    pub fps: f64,
    /// Benar bila encoder NVENC hardware aktif (Windows). Dibaca dari
    /// `screen::nvenc_active()`.
    pub nvenc: bool,
}

/// Info sesi streaming untuk ditampilkan (bukan handle media).
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionStatus {
    pub client_id: String,
    pub started_at_ms: u64,
    pub duration_ms: u64,
}

/// Status audio (forward + mic) — dilaporkan control API.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioStatus {
    /// Benar bila platform mendukung capture WASAPI (Windows).
    pub capture_available: bool,
    /// Deskripsi pipeline audio (mis. "wasapi-loopback → opus 48kHz stereo").
    pub pipeline: String,
    /// Jumlah perangkat output yang terdeteksi.
    pub outputs: usize,
    /// Volume master perangkat output default (0.0–1.0), bila terbaca.
    pub volume: Option<f32>,
}

/// Daftar display + yang terpilih untuk sesi berikutnya.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DisplayStatus {
    pub list: Vec<crate::screen::DisplayInfo>,
    /// Indeks monitor yang dipakai sesi berikutnya.
    pub wanted: usize,
}

/// Snapshot status — dibangun dari [`ControlState`] saat `/status` dipanggil.
/// Serialisasi `camelCase` agar nyaman di sisi TypeScript.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    pub state: EngineState,
    pub device_id: String,
    pub password: String,
    pub signaling_url: String,
    pub started_at_ms: u64,
    pub uptime_ms: u64,
    pub session: Option<SessionStatus>,
    pub video: VideoStats,
    pub audio: AudioStatus,
    pub displays: DisplayStatus,
    pub last_error: Option<String>,
}

/// Keadaan bersama engine yang dilaporkan control API.
///
/// Semua bidang dilindungi SATU mutex. Update per-frame dari task streaming
/// hanya memegang lock selama beberapa nanodetik — bukan titik panas.
#[derive(Debug)]
pub struct ControlState {
    pub state: EngineState,
    pub device_id: String,
    pub password: String,
    pub signaling_url: String,
    pub started_at_ms: u64,
    pub session: Option<SessionStatus>,
    /// Handle media sesi aktif — dipakai aksi `stop-session`.
    pub active_session: Option<Arc<Session>>,
    /// Registri izin (sama dengan yang dipakai loop signaling) — aksi
    /// `stop-session` harus mencabut izin agar peer wajib pairing ulang.
    pub paired: Option<Arc<Mutex<PairedPeers>>>,
    pub video: VideoStats,
    pub last_error: Option<String>,
}

impl ControlState {
    pub fn new(device_id: String, password: String, signaling_url: String) -> Self {
        Self {
            state: EngineState::Starting,
            device_id,
            password,
            signaling_url,
            started_at_ms: now_ms(),
            session: None,
            active_session: None,
            paired: None,
            video: VideoStats::default(),
            last_error: None,
        }
    }

    /// Snapshot serializable untuk `/status`.
    pub fn snapshot(&self) -> Status {
        let now = now_ms();
        let displays = crate::screen::list_displays();
        Status {
            state: self.state,
            device_id: self.device_id.clone(),
            password: self.password.clone(),
            signaling_url: self.signaling_url.clone(),
            started_at_ms: self.started_at_ms,
            uptime_ms: now.saturating_sub(self.started_at_ms),
            session: self.session.as_ref().map(|s| SessionStatus {
                client_id: s.client_id.clone(),
                started_at_ms: s.started_at_ms,
                duration_ms: now.saturating_sub(s.started_at_ms),
            }),
            video: self.video,
            audio: AudioStatus {
                capture_available: crate::audio::capture_available(),
                pipeline: crate::audio::capture_status().to_string(),
                outputs: crate::audio::list_outputs().len(),
                volume: crate::audio::master_volume(),
            },
            displays: DisplayStatus {
                list: displays,
                wanted: crate::screen::wanted_display(),
            },
            last_error: self.last_error.clone(),
        }
    }

    /// Tandai streaming dimulai: simpan info sesi + handle media.
    pub fn set_streaming(&mut self, client_id: String, session: Arc<Session>) {
        self.session = Some(SessionStatus {
            client_id,
            started_at_ms: now_ms(),
            duration_ms: 0,
        });
        self.active_session = Some(session);
        self.state = EngineState::Streaming;
        self.video = VideoStats::default();
    }

    /// Tandai streaming berakhir (bye, client hilang, atau stop-session):
    /// kembali ke `Ready` dan kosongkan sesi.
    pub fn mark_stopped(&mut self) {
        self.session = None;
        self.active_session = None;
        self.state = EngineState::Ready;
        self.video = VideoStats::default();
    }
}

fn now_ms() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

/// Permintaan aksi dari shell: `{"action": "...", "password": "..."}`.
#[derive(Debug, Deserialize)]
pub struct ActionRequest {
    pub action: String,
    #[serde(default)]
    pub password: Option<String>,
    /// Nilai volume 0.0–1.0 untuk aksi `audio-volume`.
    #[serde(default)]
    pub volume: Option<f32>,
    /// Indeks monitor untuk aksi `display-select`.
    #[serde(default)]
    pub index: Option<usize>,
}

/// Jawaban aksi. `password` berisi nilai baru untuk `new-password` dan
/// `set-password`; `stopped` dipakai `stop-session`.
#[derive(Debug, Serialize)]
pub struct ActionResponse {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub password: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stopped: Option<bool>,
}

impl ActionResponse {
    fn err(msg: impl Into<String>) -> Self {
        Self {
            ok: false,
            error: Some(msg.into()),
            password: None,
            stopped: None,
        }
    }
}

/// Server control yang sudah berjalan.
pub struct ControlServer {
    pub addr: SocketAddr,
    pub token: String,
}

#[derive(Clone)]
struct ServerState {
    control: Arc<Mutex<ControlState>>,
    token_hash: Arc<[u8; 32]>,
}

/// Mulai server control di `127.0.0.1:port`. `port == 0` meminta port
/// efemeral (dipakai shell desktop agar tidak pernah bentrok).
pub async fn start(state: Arc<Mutex<ControlState>>, port: u16) -> anyhow::Result<ControlServer> {
    let token = random_token();
    let token_hash: [u8; 32] = Sha256::digest(token.as_bytes()).into();

    let app = Router::new()
        .route("/health", get(health))
        .route("/status", get(status))
        .route("/action", post(action))
        .with_state(ServerState {
            control: state,
            token_hash: Arc::new(token_hash),
        });

    let listener = tokio::net::TcpListener::bind(("127.0.0.1", port))
        .await
        .with_context(|| format!("gagal bind control API di 127.0.0.1:{port}"))?;
    let addr = listener.local_addr()?;

    tokio::spawn(async move {
        if let Err(e) = axum::serve(listener, app).await {
            eprintln!("[control] server berhenti: {e}");
        }
    });

    Ok(ControlServer { addr, token })
}

fn random_token() -> String {
    let mut rng = rand::thread_rng();
    let mut s = String::with_capacity(32);
    for _ in 0..32 {
        s.push(char::from(b"0123456789abcdef"[rng.gen_range(0..16)]));
    }
    s
}

/// Perbandingan token konstan-waktu (hash SHA-256 + XOR akumulasi — pola
/// yang sama dengan `identity::verify_password`).
fn token_ok(headers: &HeaderMap, token_hash: &[u8; 32]) -> bool {
    let Some(raw) = headers.get(TOKEN_HEADER).and_then(|v| v.to_str().ok()) else {
        return false;
    };
    let candidate: [u8; 32] = Sha256::digest(raw.as_bytes()).into();
    let mut diff = 0u8;
    for (x, y) in candidate.iter().zip(token_hash.iter()) {
        diff |= x ^ y;
    }
    diff == 0
}

fn unauthorized() -> (StatusCode, Json<ActionResponse>) {
    (
        StatusCode::UNAUTHORIZED,
        Json(ActionResponse::err("token control tidak valid")),
    )
}

/// `/health` — hidup atau tidak. Sengaja tanpa token: tidak membocorkan apa
/// pun, dan berguna sebagai probe cepat watchdog shell.
async fn health() -> Json<serde_json::Value> {
    Json(serde_json::json!({ "ok": true }))
}

async fn status(
    State(s): State<ServerState>,
    headers: HeaderMap,
) -> Result<Json<Status>, (StatusCode, Json<ActionResponse>)> {
    if !token_ok(&headers, &s.token_hash) {
        return Err(unauthorized());
    }
    Ok(Json(s.control.lock().unwrap().snapshot()))
}

async fn action(
    State(s): State<ServerState>,
    headers: HeaderMap,
    Json(req): Json<ActionRequest>,
) -> Result<Json<ActionResponse>, (StatusCode, Json<ActionResponse>)> {
    if !token_ok(&headers, &s.token_hash) {
        return Err(unauthorized());
    }

    match req.action.as_str() {
        // Generate ulang password acak (persisten) — kembalikan nilai baru.
        "new-password" => {
            let mut control = s.control.lock().unwrap();
            let pw = identity::generate_password();
            if let Err(e) = identity::set_password(&pw) {
                return Ok(Json(ActionResponse::err(format!(
                    "gagal menyimpan password: {e}"
                ))));
            }
            control.password = pw.clone();
            Ok(Json(ActionResponse {
                ok: true,
                error: None,
                password: Some(pw),
                stopped: None,
            }))
        }
        // Set password kustom (persisten, min 6 karakter).
        "set-password" => {
            let mut control = s.control.lock().unwrap();
            let Some(pw) = req.password.as_deref() else {
                return Ok(Json(ActionResponse::err("password tidak disertakan")));
            };
            if pw.len() < identity::PW_MIN_LEN {
                return Ok(Json(ActionResponse::err(format!(
                    "password minimal {} karakter",
                    identity::PW_MIN_LEN
                ))));
            }
            if let Err(e) = identity::set_password(pw) {
                return Ok(Json(ActionResponse::err(format!(
                    "gagal menyimpan password: {e}"
                ))));
            }
            control.password = pw.to_string();
            Ok(Json(ActionResponse {
                ok: true,
                error: None,
                password: Some(pw.to_string()),
                stopped: None,
            }))
        }
        // Akhiri sesi streaming aktif. Semantiknya sama dengan `bye` dari
        // client: tutup peer connection + cabut izin (wajib pairing ulang).
        "stop-session" => {
            // Guard mutex dibatasi block INI agar tidak hidup melintasi
            // await di bawah (MutexGuard tidak Send — handler wajib Send).
            let (client_id, session) = {
                let mut control = s.control.lock().unwrap();
                let client_id = control.session.as_ref().map(|s| s.client_id.clone());
                let session = control.active_session.take();
                control.mark_stopped();
                (client_id, session)
            };
            let stopped = match session {
                Some(sess) => {
                    let _ = sess.close().await;
                    true
                }
                None => false,
            };
            if let Some(client) = client_id {
                if let Some(paired) = s.control.lock().unwrap().paired.clone() {
                    paired.lock().unwrap().revoke(&client);
                }
            }
            Ok(Json(ActionResponse {
                ok: true,
                error: None,
                password: None,
                stopped: Some(stopped),
            }))
        }
        // Setel volume master perangkat output default (0.0–1.0).
        "audio-volume" => {
            let Some(vol) = req.volume else {
                return Ok(Json(ActionResponse::err("volume tidak disertakan")));
            };
            if crate::audio::set_master_volume(vol) {
                Ok(Json(ActionResponse {
                    ok: true,
                    error: None,
                    password: None,
                    stopped: None,
                }))
            } else {
                Ok(Json(ActionResponse::err(
                    "gagal setel volume (WASAPI tidak tersedia di platform ini)",
                )))
            }
        }
        // Pilih monitor untuk sesi berikutnya (0 = primer). Ditolak bila
        // indeks di luar daftar display yang terdeteksi.
        "display-select" => {
            let Some(index) = req.index else {
                return Ok(Json(ActionResponse::err("index tidak disertakan")));
            };
            if crate::screen::select_display(index) {
                Ok(Json(ActionResponse {
                    ok: true,
                    error: None,
                    password: None,
                    stopped: None,
                }))
            } else {
                Ok(Json(ActionResponse::err(format!(
                    "indeks display {index} tidak valid (terdeteksi {} layar)",
                    crate::screen::list_displays().len()
                ))))
            }
        }
        other => Ok(Json(ActionResponse::err(format!(
            "aksi tidak dikenal: {other}"
        )))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpStream;

    /// Klien HTTP mentah minimal untuk test — tidak menambah dependency.
    /// Meminta `Connection: close` agar server menutup koneksi setelah
    /// respons (read_to_string berhenti), dan menghitung content-length
    /// dari body yang sebenarnya.
    fn http_request(
        addr: SocketAddr,
        method: &str,
        path: &str,
        headers: &[(&str, &str)],
        body: Option<&str>,
    ) -> (u16, String) {
        let body = body.unwrap_or("");
        let mut req = format!("{method} {path} HTTP/1.1\r\nHost: t\r\nConnection: close\r\n");
        for (k, v) in headers {
            req.push_str(&format!("{k}: {v}\r\n"));
        }
        if !body.is_empty() {
            req.push_str(&format!(
                "content-type: application/json\r\ncontent-length: {}\r\n",
                body.len()
            ));
        }
        req.push_str("\r\n");
        req.push_str(body);
        let mut stream = TcpStream::connect(addr).expect("konek ke server");
        stream.write_all(req.as_bytes()).expect("kirim request");
        let mut buf = String::new();
        stream.read_to_string(&mut buf).expect("baca respons");
        let status = buf
            .lines()
            .next()
            .and_then(|l| l.split_whitespace().nth(1))
            .and_then(|c| c.parse().ok())
            .unwrap_or(0);
        let out = buf.split("\r\n\r\n").nth(1).unwrap_or("").to_string();
        (status, out)
    }

    fn test_state() -> Arc<Mutex<ControlState>> {
        Arc::new(Mutex::new(ControlState::new(
            "123456789".into(),
            "RAHASIA-1".into(),
            "ws://localhost:8787/ws".into(),
        )))
    }

    async fn spawn() -> (SocketAddr, String) {
        let srv = start(test_state(), 0).await.expect("start server");
        (srv.addr, srv.token)
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn health_terbuka_tanpa_token() {
        let (addr, _) = spawn().await;
        let (code, body) = http_request(addr, "GET", "/health", &[], None);
        assert_eq!(code, 200);
        assert!(body.contains("\"ok\":true"), "body: {body}");
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn status_menolak_tanpa_atau_dengan_token_salah() {
        let (addr, token) = spawn().await;
        let (code, _) = http_request(addr, "GET", "/status", &[], None);
        assert_eq!(code, 401, "tanpa token harus 401");
        let (code, _) = http_request(
            addr,
            "GET",
            "/status",
            &[(TOKEN_HEADER, &format!("salah{token}"))],
            None,
        );
        assert_eq!(code, 401, "token salah harus 401");
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn status_dengan_token_benar() {
        let (addr, token) = spawn().await;
        let (code, body) = http_request(addr, "GET", "/status", &[(TOKEN_HEADER, &token)], None);
        assert_eq!(code, 200);
        let v: serde_json::Value = serde_json::from_str(&body).expect("JSON valid");
        assert_eq!(v["deviceId"], "123456789");
        assert_eq!(v["state"], "starting");
        assert_eq!(v["signalingUrl"], "ws://localhost:8787/ws");
        // Bidang yang dipakai UI harus selalu ada.
        for key in ["startedAtMs", "uptimeMs", "video", "session", "lastError"] {
            assert!(v.get(key).is_some(), "bidang {key} hilang: {body}");
        }
        assert_eq!(v["video"]["framesSent"], 0);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn aksi_set_password_terlalu_pendek_ditolak() {
        let (addr, token) = spawn().await;
        let (code, body) = http_request(
            addr,
            "POST",
            "/action",
            &[(TOKEN_HEADER, &token)],
            Some(r#"{"action":"set-password","password":"abc"}"#),
        );
        assert_eq!(
            code, 200,
            "validasi panjang = respons 200 berisi error, bukan HTTP error"
        );
        let v: serde_json::Value = serde_json::from_str(&body).expect("JSON valid");
        assert_eq!(v["ok"], false);
        assert!(v["error"].as_str().unwrap_or("").contains("minimal"));
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn aksi_new_password_mengganti_nilai_di_status() {
        // Arahkan penyimpanan identitas ke direktori sementara agar test tidak
        // menyentuh ~/.xydesk pengembang/CI.
        let home = std::env::temp_dir().join(format!("xydesk-test-{}", std::process::id()));
        let _ = std::fs::create_dir_all(&home);
        std::env::set_var("XYDESK_HOME", &home);

        let state = test_state();
        let srv = start(state.clone(), 0).await.expect("start server");

        let (code, body) = http_request(
            srv.addr,
            "POST",
            "/action",
            &[(TOKEN_HEADER, &srv.token)],
            Some(r#"{"action":"new-password"}"#),
        );
        assert_eq!(code, 200);
        let v: serde_json::Value = serde_json::from_str(&body).expect("JSON valid");
        assert_eq!(v["ok"], true);
        let baru = v["password"].as_str().expect("password dikembalikan");
        assert!(baru.len() >= identity::PW_GEN_LEN);

        // Status berikutnya memuat password yang sama (UI menampilkannya).
        let (code, body) = http_request(
            srv.addr,
            "GET",
            "/status",
            &[(TOKEN_HEADER, &srv.token)],
            None,
        );
        assert_eq!(code, 200);
        let v: serde_json::Value = serde_json::from_str(&body).expect("JSON valid");
        assert_eq!(v["password"], baru);

        // Password benar-benar tersimpan persisten.
        let tersimpan = std::fs::read_to_string(home.join("password")).expect("file password");
        assert_eq!(tersimpan.trim(), baru);
        assert!(state.lock().unwrap().password == baru);
        std::env::remove_var("XYDESK_HOME");
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn aksi_stop_session_tanpa_sesi_berjalan() {
        let (addr, token) = spawn().await;
        let (code, body) = http_request(
            addr,
            "POST",
            "/action",
            &[(TOKEN_HEADER, &token)],
            Some(r#"{"action":"stop-session"}"#),
        );
        assert_eq!(code, 200);
        let v: serde_json::Value = serde_json::from_str(&body).expect("JSON valid");
        assert_eq!(v["ok"], true);
        assert_eq!(v["stopped"], false);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn aksi_tidak_dikenal_ditolak_dengan_error() {
        let (addr, token) = spawn().await;
        let (code, body) = http_request(
            addr,
            "POST",
            "/action",
            &[(TOKEN_HEADER, &token)],
            Some(r#"{"action":"hapus-semua"}"#),
        );
        assert_eq!(code, 200);
        let v: serde_json::Value = serde_json::from_str(&body).expect("JSON valid");
        assert_eq!(v["ok"], false);
        assert!(v["error"].as_str().unwrap_or("").contains("tidak dikenal"));
    }

    #[tokio::test]
    async fn snapshot_sesi_melaporkan_durasi() {
        let state = test_state();
        state.lock().unwrap().session = Some(SessionStatus {
            client_id: "klien-1".into(),
            started_at_ms: now_ms() - 5_000,
            duration_ms: 0,
        });
        let snap = state.lock().unwrap().snapshot();
        let s = snap.session.expect("ada sesi");
        assert_eq!(s.client_id, "klien-1");
        assert!(s.duration_ms >= 5_000, "durasi {}.", s.duration_ms);
    }
}
