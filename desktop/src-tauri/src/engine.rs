use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::{Mutex, RwLock};

const SIGNALING_HTTP: &str = "https://signal.xydesk.my.id";
const SIGNALING_WS: &str = "wss://signal.xydesk.my.id/ws";
const LOG_LIMIT: usize = 400;
const RESTART_BACKOFF_BASE_MS: u64 = 2000;
const RESTART_BACKOFF_MAX_MS: u64 = 30000;

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct LogEntry {
    pub t: u64,
    pub line: String,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct InfoPayload {
    pub version: String,
    pub platform: String,
    pub arch: String,
    pub packaged: bool,
    pub signaling_http: String,
    pub signaling_ws: String,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct IdentityJson {
    #[serde(rename = "deviceId")]
    pub device_id: String,
    pub password: String,
}

#[derive(Default)]
struct EngineState {
    control_port: Option<u16>,
    control_token: Option<String>,
    device_id: Option<String>,
    password: Option<String>,
    last_error: Option<String>,
    logs: VecDeque<LogEntry>,
    is_running: bool,
    restart_attempt: u32,
}

pub struct EngineSupervisor {
    state: Arc<RwLock<EngineState>>,
    http_client: reqwest::Client,
    stop_tx: Arc<Mutex<Option<tokio::sync::oneshot::Sender<()>>>>,
}

impl EngineSupervisor {
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(EngineState::default())),
            http_client: reqwest::Client::builder()
                .timeout(Duration::from_secs(5))
                .build()
                .unwrap_or_default(),
            stop_tx: Arc::new(Mutex::new(None)),
        }
    }

    pub fn add_log(state: &Arc<RwLock<EngineState>>, line: String) {
        let clean = line.trim_end().to_string();
        if clean.is_empty() {
            return;
        }
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0);

        let mut lock = match state.try_write() {
            Ok(guard) => guard,
            Err(_) => return,
        };
        lock.logs.push_back(LogEntry { t: now, line: clean });
        if lock.logs.len() > LOG_LIMIT {
            lock.logs.pop_front();
        }
    }

    pub fn find_engine_exe() -> Option<PathBuf> {
        if let Ok(env_path) = std::env::var("XYDESK_ENGINE") {
            let p = PathBuf::from(env_path);
            if p.exists() {
                return Some(p);
            }
        }

        if let Ok(exe) = std::env::current_exe() {
            if let Some(dir) = exe.parent() {
                let candidates = [
                    dir.join("xydesk-host.exe"),
                    dir.join("engine").join("xydesk-host.exe"),
                    dir.join("resources").join("engine").join("xydesk-host.exe"),
                    dir.join("..").join("resources").join("engine").join("xydesk-host.exe"),
                ];
                for c in &candidates {
                    if c.exists() {
                        return Some(c.clone());
                    }
                }
            }
        }

        let dev_candidates = [
            Path::new("host/target/release/xydesk-host.exe").to_path_buf(),
            Path::new("host/target/debug/xydesk-host.exe").to_path_buf(),
            Path::new("../host/target/release/xydesk-host.exe").to_path_buf(),
            Path::new("../../host/target/release/xydesk-host.exe").to_path_buf(),
            Path::new("../../../host/target/release/xydesk-host.exe").to_path_buf(),
        ];
        for c in &dev_candidates {
            if c.exists() {
                return Some(c.clone());
            }
        }
        None
    }

    pub async fn fetch_identity(exe_path: &Path) -> Result<IdentityJson, String> {
        let output = Command::new(exe_path)
            .arg("--identity-json")
            .output()
            .await
            .map_err(|e| format!("Gagal memanggil xydesk-host --identity-json: {e}"))?;

        if !output.status.success() {
            return Err(format!(
                "xydesk-host --identity-json gagal: {}",
                String::from_utf8_lossy(&output.stderr)
            ));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let id: IdentityJson = serde_json::from_str(stdout.trim())
            .map_err(|e| format!("Gagal parsing identity JSON '{stdout}': {e}"))?;
        Ok(id)
    }

    pub async fn exchange_host_token(
        client: &reqwest::Client,
        device_id: &str,
        password: &str,
    ) -> Result<String, String> {
        let url = format!("{SIGNALING_HTTP}/host-token");
        let body = serde_json::json!({
            "id": device_id,
            "password": password
        });

        let res = client
            .post(&url)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Gagal menghubungi signaling server ({url}): {e}"))?;

        if !res.status().is_success() {
            let status = res.status();
            let text = res.text().await.unwrap_or_default();
            return Err(format!("Signaling server menolak host token (HTTP {status}): {text}"));
        }

        let json: serde_json::Value = res
            .json()
            .await
            .map_err(|e| format!("Format respons token tidak valid: {e}"))?;

        let token = json
            .get("token")
            .and_then(|v| v.as_str())
            .ok_or_else(|| "Respons signaling tidak memuat field 'token'".to_string())?;

        Ok(token.to_string())
    }

    pub fn start(&self) {
        let state = self.state.clone();
        let client = self.http_client.clone();
        let stop_tx = self.stop_tx.clone();

        tokio::spawn(async move {
            let (tx, mut rx) = tokio::sync::oneshot::channel::<()>();
            {
                let mut guard = stop_tx.lock().await;
                *guard = Some(tx);
            }

            loop {
                let exe = match Self::find_engine_exe() {
                    Some(e) => e,
                    None => {
                        let msg = "Biner xydesk-host.exe tidak ditemukan di direktori aplikasi.".to_string();
                        Self::add_log(&state, format!("[supervisor] {msg}"));
                        {
                            let mut lock = state.write().await;
                            lock.last_error = Some(msg);
                            lock.is_running = false;
                        }
                        tokio::time::sleep(Duration::from_secs(5)).await;
                        continue;
                    }
                };

                let ident = match Self::fetch_identity(&exe).await {
                    Ok(id) => {
                        let mut lock = state.write().await;
                        lock.device_id = Some(id.device_id.clone());
                        lock.password = Some(id.password.clone());
                        id
                    }
                    Err(e) => {
                        Self::add_log(&state, format!("[supervisor] {e}"));
                        {
                            let mut lock = state.write().await;
                            lock.last_error = Some(e);
                            lock.is_running = false;
                        }
                        tokio::time::sleep(Duration::from_secs(5)).await;
                        continue;
                    }
                };

                Self::add_log(
                    &state,
                    format!("[supervisor] Identitas host: ID={}, Password=****", ident.device_id),
                );

                let token = match Self::exchange_host_token(&client, &ident.device_id, &ident.password).await {
                    Ok(t) => t,
                    Err(e) => {
                        Self::add_log(&state, format!("[supervisor] {e}"));
                        {
                            let mut lock = state.write().await;
                            lock.last_error = Some(e);
                            lock.is_running = false;
                        }
                        let attempt = {
                            let mut lock = state.write().await;
                            lock.restart_attempt += 1;
                            lock.restart_attempt
                        };
                        let delay = (RESTART_BACKOFF_BASE_MS * (1 << attempt.min(5)))
                            .min(RESTART_BACKOFF_MAX_MS);
                        tokio::time::sleep(Duration::from_millis(delay)).await;
                        continue;
                    }
                };

                // Pilih port kontrol acak / bebas
                let mut child = match Command::new(&exe)
                    .args([
                        "--url",
                        SIGNALING_WS,
                        "--token",
                        &token,
                        "--control-port",
                        "0",
                    ])
                    .stdout(Stdio::piped())
                    .stderr(Stdio::piped())
                    .spawn()
                {
                    Ok(c) => c,
                    Err(e) => {
                        let msg = format!("Gagal menjalankan xydesk-host: {e}");
                        Self::add_log(&state, format!("[supervisor] {msg}"));
                        {
                            let mut lock = state.write().await;
                            lock.last_error = Some(msg);
                            lock.is_running = false;
                        }
                        tokio::time::sleep(Duration::from_secs(3)).await;
                        continue;
                    }
                };

                {
                    let mut lock = state.write().await;
                    lock.is_running = true;
                    lock.last_error = None;
                    lock.restart_attempt = 0;
                }

                let stdout = child.stdout.take();
                let stderr = child.stderr.take();

                let state_clone = state.clone();
                if let Some(out) = stdout {
                    tokio::spawn(async move {
                        let mut reader = BufReader::new(out).lines();
                        while let Ok(Some(line)) = reader.next_line().await {
                            if line.starts_with("[control]") {
                                // Format: [control] http://127.0.0.1:PORT token=HEX
                                if let Some(idx) = line.find("http://127.0.0.1:") {
                                    let sub = &line[idx + "http://127.0.0.1:".len()..];
                                    let parts: Vec<&str> = sub.split_whitespace().collect();
                                    if let Some(port_str) = parts.first() {
                                        if let Ok(port) = port_str.parse::<u16>() {
                                            let token = parts.get(1).and_then(|t| t.strip_prefix("token="));
                                            let mut lock = state_clone.write().await;
                                            lock.control_port = Some(port);
                                            lock.control_token = token.map(|s| s.to_string());
                                        }
                                    }
                                }
                            }
                            Self::add_log(&state_clone, line);
                        }
                    });
                }

                let state_err = state.clone();
                if let Some(err) = stderr {
                    tokio::spawn(async move {
                        let mut reader = BufReader::new(err).lines();
                        while let Ok(Some(line)) = reader.next_line().await {
                            Self::add_log(&state_err, line);
                        }
                    });
                }

                tokio::select! {
                    _ = &mut rx => {
                        let _ = child.kill().await;
                        Self::add_log(&state, "[supervisor] Engine dihentikan manual.".to_string());
                        break;
                    }
                    status = child.wait() => {
                        let code_str = match status {
                            Ok(s) => s.to_string(),
                            Err(e) => format!("galat: {e}"),
                        };
                        Self::add_log(&state, format!("[supervisor] Engine berhenti ({code_str}). Restarting..."));
                        {
                            let mut lock = state.write().await;
                            lock.is_running = false;
                            lock.control_port = None;
                            lock.control_token = None;
                        }
                        tokio::time::sleep(Duration::from_millis(RESTART_BACKOFF_BASE_MS)).await;
                    }
                }
            }
        });
    }

    pub async fn get_status(&self) -> Result<serde_json::Value, String> {
        let (port, token, device_id, last_error, is_running) = {
            let lock = self.state.read().await;
            (
                lock.control_port,
                lock.control_token.clone(),
                lock.device_id.clone(),
                lock.last_error.clone(),
                lock.is_running,
            )
        };

        if let (Some(p), Some(tok)) = (port, token) {
            let url = format!("http://127.0.0.1:{p}/status");
            match self
                .http_client
                .get(&url)
                .header("Authorization", format!("Bearer {tok}"))
                .send()
                .await
            {
                Ok(res) => {
                    if res.status().is_success() {
                        if let Ok(val) = res.json::<serde_json::Value>().await {
                            return Ok(val);
                        }
                    }
                }
                Err(_) => {}
            }
        }

        // Fallback default status bila engine belum siap
        Ok(serde_json::json!({
            "state": if is_running { "starting" } else { "error" },
            "deviceId": device_id.unwrap_or_else(|| "Memuat...".to_string()),
            "signalingUrl": SIGNALING_WS,
            "startedAtMs": 0,
            "uptimeMs": 0,
            "lastError": last_error,
            "session": serde_json::Value::Null,
            "video": {
                "framesSent": 0,
                "fps": 0,
                "nvenc": false,
                "encoder": "memuat",
            },
            "audio": {
                "captureAvailable": false,
                "pipeline": "memuat",
                "micAvailable": false,
                "micPipeline": "memuat",
                "outputs": 0,
                "volume": serde_json::Value::Null,
            },
            "displays": {
                "list": [],
                "wanted": 0,
            },
            "targetBitrateBps": 0,
        }))
    }

    pub async fn run_action(&self, req: serde_json::Value) -> Result<serde_json::Value, String> {
        let (port, token) = {
            let lock = self.state.read().await;
            (lock.control_port, lock.control_token.clone())
        };

        let (p, tok) = match (port, token) {
            (Some(p), Some(tok)) => (p, tok),
            _ => return Err("Engine belum siap menerima perintah (control API offline).".to_string()),
        };

        let url = format!("http://127.0.0.1:{p}/action");
        let res = self
            .http_client
            .post(&url)
            .header("Authorization", format!("Bearer {tok}"))
            .json(&req)
            .send()
            .await
            .map_err(|e| format!("Gagal memanggil control action: {e}"))?;

        let status = res.status();
        let json: serde_json::Value = res
            .json()
            .await
            .unwrap_or_else(|_| serde_json::json!({ "ok": status.is_success() }));

        Ok(json)
    }

    pub async fn get_logs(&self) -> Vec<LogEntry> {
        let lock = self.state.read().await;
        lock.logs.iter().cloned().collect()
    }

    pub fn get_info(&self) -> InfoPayload {
        InfoPayload {
            version: "6.7.11".to_string(),
            platform: std::env::consts::OS.to_string(),
            arch: std::env::consts::ARCH.to_string(),
            packaged: true,
            signaling_http: SIGNALING_HTTP.to_string(),
            signaling_ws: SIGNALING_WS.to_string(),
        }
    }
}
