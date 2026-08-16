//! XyDesk host — titik masuk.
//!
//! Alur: daftar ke signaling → tunggu `pair` (auto-terima untuk PoC) →
//! terima `offer` dari client → jawab → terima kandidat ICE client →
//! terima data channel "input". Sumber video (DXGI) menyusul di `screen.rs`.

use std::sync::Arc;

use anyhow::{Context, Result};
use clap::Parser;
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio_tungstenite::connect_async;
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::tungstenite::http::HeaderValue;
use tokio_tungstenite::tungstenite::Message;

use xydesk_host::session::{IceCandidate, Session};

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

type Ws = tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>;

async fn send_msg(ws: &mut Ws, msg: &Msg) -> Result<()> {
    ws.send(Message::Text(serde_json::to_string(msg)?.into())).await?;
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
    /// Token Bearer dari server signaling (/issue)
    #[arg(long)]
    token: String,
    /// Server STUN (kosongkan untuk LAN murni)
    #[arg(long, default_value = "stun:stun.cloudflare.com:3478")]
    stun: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    // ── Identitas: ID perangkat (stabil) + PIN pairing (per sesi) ──
    let device_id = args
        .id
        .clone()
        .unwrap_or_else(xydesk_host::identity::load_or_create_device_id);
    let pin = xydesk_host::identity::generate_pin();

    println!(
        "[xydesk-host] sumber video: {}",
        xydesk_host::screen::capture_status()
    );
    println!();
    println!("  ╔══════════════════════════════════════════╗");
    println!("  ║   XyDesk Host — siap menerima koneksi    ║");
    println!("  ╠══════════════════════════════════════════╣");
    println!("  ║   ID perangkat : {:<24}║", device_id);
    println!("  ║   PIN pairing  : {:<24}║", pin);
    println!("  ╚══════════════════════════════════════════╝");
    println!();
    println!("  Masukkan ID + PIN ini di aplikasi XyDesk client.");

    let mut req = format!("{}?id={}&role=host", args.url, device_id)
        .into_client_request()
        .context("URL tidak valid")?;
    req.headers_mut().insert(
        "Authorization",
        HeaderValue::from_str(&format!("Bearer {}", args.token))?,
    );

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

    while let Some(m) = ws.next().await {
        let m = m.context("koneksi putus")?;
        let Message::Text(txt) = m else { continue };
        let msg: Msg = match serde_json::from_str(&txt) {
            Ok(v) => v,
            Err(_) => continue,
        };

        match msg.kind.as_str() {
            "welcome" => println!("[xydesk-host] terdaftar sebagai {}", device_id),

            "pair" => {
                let from = msg.from.unwrap_or_default();
                // Verifikasi PIN yang dikirim client terhadap PIN sesi ini.
                let ok = msg.pin.as_deref() == Some(pin.as_str());
                println!(
                    "[xydesk-host] permintaan pairing dari {from} (PIN {})",
                    if ok { "COCOK" } else { "SALAH" }
                );
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
                let sdp = msg.sdp.clone().context("offer tanpa SDP")?;
                println!("[xydesk-host] menerima offer dari {client}");

                let session = Arc::new(Session::new(vec![stun.clone()], vec![]).await?);
                let answer = session.answer(&sdp.sdp).await?;

                send_msg(
                    &mut ws,
                    &Msg {
                        kind: "answer".into(),
                        to: Some(client.clone()),
                        sdp: Some(SdpMsg { kind: "answer".into(), sdp: answer }),
                        ..Default::default()
                    },
                )
                .await?;

                // Terima input (data channel) di task terpisah.
                {
                    let session = session.clone();
                    tokio::spawn(async move {
                        match session.receive_input_channel().await {
                            Ok(dc) => {
                                println!("[xydesk-host] data channel input terbuka");
                                let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
                                dc.on_message(Box::new(move |m| {
                                    if !m.is_string {
                                        let _ = tx.send(m.data.to_vec());
                                    }
                                    Box::pin(async {})
                                }));
                                while let Some(data) = rx.recv().await {
                                    // TODO(Fase 0): teruskan ke injector (SendInput).
                                    println!("[xydesk-host] input {} byte", data.len());
                                }
                            }
                            Err(e) => eprintln!("[xydesk-host] input channel gagal: {e:#}"),
                        }
                    });
                }

                // Sumber video: test pattern (openh264) atau DXGI di Windows.
                // Encode + kirim frame ke track video WebRTC.
                {
                    let session = session.clone();
                    tokio::spawn(async move {
                        let track = match session.add_video_track().await {
                            Ok(t) => t,
                            Err(e) => {
                                eprintln!("[xydesk-host] gagal add track video: {e:#}");
                                return;
                            }
                        };
                        println!("[xydesk-host] track video siap — streaming pola uji");

                        let mut encoder = match xydesk_host::screen::TestPatternEncoder::new() {
                            Ok(e) => e,
                            Err(e) => {
                                eprintln!("[xydesk-host] gagal buat encoder: {e}");
                                return;
                            }
                        };

                        let frame_interval = tokio::time::Duration::from_millis(33); // ~30 fps
                        loop {
                            let data = match encoder.encode_next(
                                xydesk_host::screen::TEST_WIDTH,
                                xydesk_host::screen::TEST_HEIGHT,
                            ) {
                                Ok(d) => d,
                                Err(e) => {
                                    eprintln!("[xydesk-host] encode gagal: {e}");
                                    break;
                                }
                            };
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
                            tokio::time::sleep(frame_interval).await;
                        }
                    });
                }

                active = Some(session);
            }

            "ice" => {
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
                println!("[xydesk-host] sesi diakhiri client");
                if let Some(s) = active.take() {
                    let _ = s.close().await;
                }
            }
            "error" => println!("[xydesk-host] error: {}", msg.error.unwrap_or_default()),
            other => println!("[xydesk-host] pesan: {other}"),
        }
    }

    Ok(())
}
