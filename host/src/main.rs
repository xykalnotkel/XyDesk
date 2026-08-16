//! XyDesk host — titik masuk.
//!
//! Saat ini yang nyata & bisa diuji: koneksi signaling (hello → tunggu pair).
//! Capture/encode WebRTC menyusul di `screen.rs` (Windows-only). Lihat README.

mod screen;

use anyhow::{Context, Result};
use clap::Parser;
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::tungstenite::http::HeaderValue;
use tokio_tungstenite::tungstenite::Message;

/// Struktur pesan signaling — harus identik dengan `signaling/protocol.go`.
#[derive(Serialize, Deserialize, Debug)]
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
    error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<String>,
}

#[derive(Parser, Debug)]
#[command(name = "xydesk-host", about = "XyDesk host — stream layar ke client")]
struct Args {
    /// URL signaling server, mis. ws://localhost:8080/ws
    #[arg(long, default_value = "ws://localhost:8080/ws")]
    url: String,
    /// DeviceId host ini
    #[arg(long)]
    id: String,
    /// Nama tampilan host
    #[arg(long, default_value = "XyDesk Host")]
    name: String,
    /// Token Bearer dari server signaling
    #[arg(long)]
    token: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // Bangun URL dengan query id & role.
    let mut req = format!("{}?id={}&role=host", args.url, args.id)
        .into_client_request()
        .context("URL tidak valid")?;
    req.headers_mut().insert(
        "Authorization",
        HeaderValue::from_str(&format!("Bearer {}", args.token))?,
    );

    let (mut ws, _) = connect_async(req).await.context("gagal hubung signaling")?;
    println!("[xydesk-host] terhubung ke {}", args.url);

    // Daftarkan perangkat.
    ws.send(Message::Text(
        serde_json::to_string(&Msg {
            kind: "hello".into(),
            to: Some(args.id.clone()),
            from: Some(args.name.clone()),
            pin: None,
            accepted: None,
            error: None,
            reason: Some("host".into()),
        })?
        .into(),
    ))
    .await?;

    // Loop pesan: tunggu `pair`, jawab, dan (nanti) negosiasi SDP/ICE.
    while let Some(m) = ws.next().await {
        let m = m.context("koneksi putus")?;
        let Message::Text(txt) = m else { continue };
        let msg: Msg = match serde_json::from_str(&txt) {
            Ok(v) => v,
            Err(_) => continue,
        };

        match msg.kind.as_str() {
            "welcome" => println!("[xydesk-host] terdaftar sebagai {}", args.id),
            "pair" => {
                let from = msg.from.unwrap_or_default();
                println!("[xydesk-host] permintaan pairing dari {from}");
                // TODO(Fase 1): verifikasi PIN host-side, tampilkan ke user.
                // Untuk PoC: auto-terima.
                let resp = Msg {
                    kind: "pair-response".into(),
                    to: Some(from),
                    from: None,
                    pin: None,
                    accepted: Some(true),
                    error: None,
                    reason: None,
                };
                ws.send(Message::Text(serde_json::to_string(&resp)?.into()))
                    .await?;
            }
            "offer" => {
                // TODO(Fase 0): mulai sesi WebRTC — screen::stream_loop().
                println!("[xydesk-host] menerima offer — streaming belum diimplementasi");
            }
            "bye" => println!("[xydesk-host] sesi diakhiri client"),
            "error" => println!("[xydesk-host] error: {}", msg.error.unwrap_or_default()),
            other => println!("[xydesk-host] pesan: {other}"),
        }
    }

    Ok(())
}
