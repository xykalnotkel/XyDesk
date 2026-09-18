//! One-shot local Chromium interop fixture. Synthetic image, no desktop capture.
use std::time::Duration;
use xydesk_host::{session::Session, software_video::SoftwareEncoder, video_policy};
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let mut line = String::new();
    std::io::stdin().read_line(&mut line)?;
    let input: serde_json::Value = serde_json::from_str(&line)?;
    let offer = input["sdp"].as_str().unwrap();
    let mode = input["mode"].as_u64().unwrap_or(1) as u8;
    let level = video_policy::offer_level(offer);
    let session = Session::new_with_video_level(vec![], vec![], level).await?;
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
    let (w, h) = if mode == 2 {
        (2336, 1080)
    } else {
        (1920, 1080)
    };
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
    let mut encoder = SoftwareEncoder::with_policy(mode, level)?;
    for _ in 0..20 {
        let bytes = encoder.encode(&rgba, w, h).map_err(anyhow::Error::msg)?;
        media
            .video
            .write_sample(&webrtc::media::Sample {
                data: bytes.into(),
                duration: Duration::from_millis(66),
                ..Default::default()
            })
            .await?;
        tokio::time::sleep(Duration::from_millis(66)).await;
    }
    tokio::time::sleep(Duration::from_secs(10)).await;
    session.peer().close().await?;
    Ok(())
}
