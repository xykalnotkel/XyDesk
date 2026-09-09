use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::RwLock;

const SIGNALING_HTTP: &str = "https://signal.xydesk.my.id";
const GOOGLE_CLIENT_ID: &str =
    "335906355717-r2em6iirn8uv39qo6ol9iti8ijcv0et8.apps.googleusercontent.com";
const GOOGLE_SCOPES: &str = "openid email profile";
const AUTHORIZE_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct UserInfo {
    pub id: String,
    pub email: String,
    pub name: String,
    pub picture: Option<String>,
}

#[derive(Clone, Serialize, Deserialize, Debug, Default)]
pub struct SavedSession {
    pub token: Option<String>,
    pub user: Option<UserInfo>,
    pub metode: Option<String>,
    pub exp: Option<u64>,
}

#[derive(Clone, Serialize, Deserialize, Debug)]
pub struct AuthSessionResponse {
    pub masuk: bool,
    pub user: Option<UserInfo>,
    pub metode: Option<String>,
    pub exp: Option<u64>,
    pub tersimpan: bool,
}

pub struct AuthManager {
    session: Arc<RwLock<SavedSession>>,
    http_client: reqwest::Client,
}

impl AuthManager {
    pub fn new() -> Self {
        let saved = Self::load_session().unwrap_or_default();
        Self {
            session: Arc::new(RwLock::new(saved)),
            http_client: reqwest::Client::builder()
                .timeout(Duration::from_secs(10))
                .build()
                .unwrap_or_default(),
        }
    }

    fn session_file_path() -> PathBuf {
        if let Ok(appdata) = std::env::var("APPDATA") {
            let dir = PathBuf::from(appdata).join("XyDesk");
            let _ = std::fs::create_dir_all(&dir);
            return dir.join("auth_session.json");
        }
        if let Ok(home) = std::env::var("HOME").or_else(|_| std::env::var("USERPROFILE")) {
            let dir = PathBuf::from(home).join(".xydesk");
            let _ = std::fs::create_dir_all(&dir);
            return dir.join("auth_session.json");
        }
        PathBuf::from("auth_session.json")
    }

    fn load_session() -> Option<SavedSession> {
        let path = Self::session_file_path();
        if path.exists() {
            if let Ok(data) = std::fs::read_to_string(&path) {
                if let Ok(sess) = serde_json::from_str::<SavedSession>(&data) {
                    let now = SystemTime::now()
                        .duration_since(UNIX_EPOCH)
                        .map(|d| d.as_secs())
                        .unwrap_or(0);
                    if let Some(exp) = sess.exp {
                        if exp > now {
                            return Some(sess);
                        }
                    } else if sess.token.is_some() {
                        return Some(sess);
                    }
                }
            }
        }
        None
    }

    fn persist_session(sess: &SavedSession) {
        let path = Self::session_file_path();
        if let Ok(json) = serde_json::to_string_pretty(sess) {
            let _ = std::fs::write(&path, json);
        }
    }

    fn clear_saved_session() {
        let path = Self::session_file_path();
        let _ = std::fs::remove_file(path);
    }

    pub async fn get_session(&self) -> AuthSessionResponse {
        let sess = self.session.read().await;
        let masuk = sess.token.is_some() && sess.user.is_some();
        AuthSessionResponse {
            masuk,
            user: sess.user.clone(),
            metode: sess.metode.clone(),
            exp: sess.exp,
            tersimpan: masuk,
        }
    }

    pub async fn logout(&self) -> bool {
        {
            let mut sess = self.session.write().await;
            *sess = SavedSession::default();
        }
        Self::clear_saved_session();
        true
    }

    pub async fn login_google(&self) -> Result<AuthSessionResponse, String> {
        let mut verifier_bytes = [0u8; 32];
        rand::thread_rng().fill_bytes(&mut verifier_bytes);
        let code_verifier = URL_SAFE_NO_PAD.encode(verifier_bytes);

        let mut hasher = Sha256::new();
        hasher.update(code_verifier.as_bytes());
        let code_challenge = URL_SAFE_NO_PAD.encode(hasher.finalize());

        let mut state_bytes = [0u8; 16];
        rand::thread_rng().fill_bytes(&mut state_bytes);
        let oauth_state = URL_SAFE_NO_PAD.encode(state_bytes);

        let listener = TcpListener::bind("127.0.0.1:0")
            .await
            .map_err(|e| format!("Gagal membuka port lokal untuk loopback: {e}"))?;

        let port = listener
            .local_addr()
            .map_err(|e| format!("Gagal mendapatkan local port: {e}"))?
            .port();

        let redirect_uri = format!("http://127.0.0.1:{port}/callback");

        let auth_url = format!(
            "{AUTHORIZE_URL}?response_type=code&client_id={GOOGLE_CLIENT_ID}&redirect_uri={redirect_uri}&scope={GOOGLE_SCOPES}&code_challenge={code_challenge}&code_challenge_method=S256&state={oauth_state}"
        );

        if let Err(e) = open::that(&auth_url) {
            eprintln!("Gagal membuka browser otomatis: {e}");
        }

        // Tunggu request dari callback di loopback port
        let (mut socket, _) = tokio::time::timeout(Duration::from_secs(180), listener.accept())
            .await
            .map_err(|_| "Waktu tunggu login Google habis (3 menit).".to_string())?
            .map_err(|e| format!("Gagal menerima respons callback loopback: {e}"))?;

        let mut buf = [0u8; 2048];
        let n = socket
            .read(&mut buf)
            .await
            .map_err(|e| format!("Gagal membaca buffer HTTP callback: {e}"))?;

        let req_str = String::from_utf8_lossy(&buf[..n]);
        let first_line = req_str.lines().next().unwrap_or("");
        let query_path = first_line.split_whitespace().nth(1).unwrap_or("");

        let url = url::Url::parse(&format!("http://127.0.0.1:{port}{query_path}"))
            .map_err(|e| format!("Format URL callback tidak valid: {e}"))?;

        let mut code: Option<String> = None;
        let mut state: Option<String> = None;
        let mut error: Option<String> = None;

        for (k, v) in url.query_pairs() {
            if k == "code" {
                code = Some(v.to_string());
            } else if k == "state" {
                state = Some(v.to_string());
            } else if k == "error" {
                error = Some(v.to_string());
            }
        }

        let html_response = if code.is_some() {
            "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<!DOCTYPE html><html><body style=\"font-family:sans-serif;text-align:center;padding:40px;background:#fafaf9;\"><h2 style=\"color:#7c3aed;\">&#10004; Login Berhasil</h2><p>Silakan tutup tab ini dan kembali ke aplikasi XyDesk.</p><script>window.close();</script></body></html>"
        } else {
            "HTTP/1.1 400 Bad Request\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<!DOCTYPE html><html><body style=\"font-family:sans-serif;text-align:center;padding:40px;background:#fafaf9;\"><h2 style=\"color:#dc2626;\">&#10006; Login Gagal</h2><p>Izin masuk ditolak atau dibatalkan.</p></body></html>"
        };

        let _ = socket.write_all(html_response.as_bytes()).await;
        let _ = socket.flush().await;

        if let Some(err) = error {
            return Err(format!("Login Google dibatalkan atau ditolak: {err}"));
        }

        let code = code.ok_or_else(|| "Google tidak mengembalikan authorization code.".to_string())?;
        if state.as_deref() != Some(&oauth_state) {
            return Err("State OAuth tidak cocok. Kemungkinan adanya serangan CSRF.".to_string());
        }

        // Tukar kode ke Cloudflare Worker
        let exchange_url = format!("{SIGNALING_HTTP}/auth/google/desktop");
        let body = serde_json::json!({
            "code": code,
            "code_verifier": code_verifier,
            "redirect_uri": redirect_uri
        });

        let res = self
            .http_client
            .post(&exchange_url)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Gagal menghubungi server auth XyDesk: {e}"))?;

        if !res.status().is_success() {
            let st = res.status();
            let text = res.text().await.unwrap_or_default();
            return Err(format!("Server menolak otorisasi Google (HTTP {st}): {text}"));
        }

        let json: serde_json::Value = res
            .json()
            .await
            .map_err(|e| format!("Format respons token auth salah: {e}"))?;

        let token = json
            .get("token")
            .and_then(|v| v.as_str())
            .ok_or_else(|| "Server auth tidak memberikan token.".to_string())?;

        let user_val = json.get("user").ok_or_else(|| "Data user kosong.".to_string())?;
        let user: UserInfo = serde_json::from_value(user_val.clone())
            .map_err(|e| format!("Format user salah: {e}"))?;

        let exp = json.get("exp").and_then(|v| v.as_u64());

        let new_sess = SavedSession {
            token: Some(token.to_string()),
            user: Some(user.clone()),
            metode: Some("google".to_string()),
            exp,
        };

        {
            let mut lock = self.session.write().await;
            *lock = new_sess.clone();
        }

        Self::persist_session(&new_sess);

        Ok(AuthSessionResponse {
            masuk: true,
            user: Some(user),
            metode: Some("google".to_string()),
            exp,
            tersimpan: true,
        })
    }

    pub async fn request_email_otp(
        &self,
        email: &str,
        name: Option<&str>,
    ) -> Result<serde_json::Value, String> {
        let url = format!("{SIGNALING_HTTP}/auth/otp/request");
        let body = serde_json::json!({
            "email": email,
            "name": name.unwrap_or("Pengguna XyDesk")
        });

        let res = self
            .http_client
            .post(&url)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Gagal meminta OTP email: {e}"))?;

        let status = res.status();
        let json: serde_json::Value = res
            .json()
            .await
            .unwrap_or_else(|_| serde_json::json!({ "ok": status.is_success() }));

        if !status.is_success() {
            return Err(json.get("error").and_then(|e| e.as_str()).unwrap_or("Gagal meminta OTP").to_string());
        }

        Ok(json)
    }

    pub async fn verify_email_otp(
        &self,
        email: &str,
        otp: &str,
        name: Option<&str>,
    ) -> Result<serde_json::Value, String> {
        let url = format!("{SIGNALING_HTTP}/auth/otp/verify");
        let body = serde_json::json!({
            "email": email,
            "code": otp,
            "name": name.unwrap_or("Pengguna XyDesk")
        });

        let res = self
            .http_client
            .post(&url)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Gagal verifikasi OTP: {e}"))?;

        let status = res.status();
        let json: serde_json::Value = res
            .json()
            .await
            .map_err(|e| format!("Respons server tidak valid: {e}"))?;

        if !status.is_success() {
            return Err(json.get("error").and_then(|e| e.as_str()).unwrap_or("Verifikasi gagal").to_string());
        }

        let token = json
            .get("token")
            .and_then(|v| v.as_str())
            .ok_or_else(|| "Server tidak mengembalikan token.".to_string())?;

        let user = UserInfo {
            id: json.get("user_id").and_then(|v| v.as_str()).unwrap_or(email).to_string(),
            email: email.to_string(),
            name: name.unwrap_or("Pengguna XyDesk").to_string(),
            picture: None,
        };

        let exp = json.get("exp").and_then(|v| v.as_u64());

        let new_sess = SavedSession {
            token: Some(token.to_string()),
            user: Some(user.clone()),
            metode: Some("email".to_string()),
            exp,
        };

        {
            let mut lock = self.session.write().await;
            *lock = new_sess.clone();
        }

        Self::persist_session(&new_sess);

        Ok(serde_json::json!({
            "ok": true,
            "user": user,
            "exp": exp
        }))
    }
}
