//! One-shot local Chromium interop fixture. Synthetic image, no desktop capture.
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use xydesk_host::{session::Session, software_video::SoftwareEncoder, video_policy};
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let mut line = String::new();
    std::io::stdin().read_line(&mut line)?;
    let input: serde_json::Value = serde_json::from_str(&line)?;
    let offer = input["sdp"].as_str().unwrap();
    let mode = input["mode"].as_u64().unwrap_or(1) as u8;
    let level = video_policy::offer_level(offer);
    let session = Arc::new(Session::new_with_video_level(vec![], vec![], level).await?);
    let media = session.answer_media(offer, false, false).await?;
    println!(
        "XYDESK_ANSWER:{}",
        serde_json::json!({"sdp":media.sdp,"level":level})
    );
    tokio::time::timeout(Duration::from_secs(20), async {
        while session.peer().connection_state()
            != webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState::Connected
        {
            tokio::time::sleep(Duration::from_millis(20)).await;
        }
    })
    .await?;
    let (w, h) = (2336, 1080);
    let mut rgba = vec![0; w * h * 4];
    for y in 0..h {
        for x in 0..w {
            let i = (y * w + x) * 4;
            rgba[i] = ((x * 255) / w) as u8;
            rgba[i + 1] = ((y * 255) / h) as u8;
            rgba[i + 2] = if (x / 32 + y / 32) % 2 == 0 { 210 } else { 40 };
            rgba[i + 3] = 255;
        }
    }
    video_policy::configure(level);
    video_policy::request(mode);
    let (tx, rx) = tokio::sync::mpsc::channel(1);
    let host = session.clone();
    let track = media.video.clone();
    let pump = tokio::spawn(async move {
        xydesk_host::video::pump_video(
            &host,
            &track,
            rx,
            Arc::new(Mutex::new(xydesk_host::control::ControlState::new(
                "fixture".into(),
                "fixture".into(),
                "ws://local".into(),
            ))),
        )
        .await;
    });
    let mut encoder = SoftwareEncoder::with_policy(mode, level)?;
    for _ in 0..20 {
        if xydesk_host::screen::take_keyframe_request() {
            encoder = SoftwareEncoder::with_policy(mode, level)?;
        }
        let captured = Instant::now();
        let bytes = encoder.encode(&rgba, w, h).map_err(anyhow::Error::msg)?;
        if tx
            .send(xydesk_host::screen::EncodedFrame::new(
                bytes,
                captured,
                captured.elapsed().as_micros() as u64,
            ))
            .await
            .is_err()
        {
            break;
        }
        tokio::time::sleep(Duration::from_millis(66)).await;
    }
    drop(tx);
    pump.await?;
    tokio::time::sleep(Duration::from_secs(10)).await;
    session.peer().close().await?;
    Ok(())
}
