//! Reproduksi gerbang Windows tanpa DXGI: tidak ada frame sebelum capture armed.
//! Binary integration terpisah menjaga flag capture global tidak berebut dengan tes lain.
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;
use webrtc::rtp_transceiver::rtp_codec::RTPCodecType;
use webrtc::rtp_transceiver::rtp_transceiver_direction::RTCRtpTransceiverDirection;
use webrtc::rtp_transceiver::RTCRtpTransceiverInit;
use xydesk_host::{control::ControlState, screen, session::Session, video};

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn idle_capture_starts_after_connected_and_stops_without_another_frame() -> anyhow::Result<()>
{
    screen::disarm_capture();
    let client = Session::new(vec![], vec![]).await?;
    let pc = client.peer();
    pc.add_transceiver_from_kind(
        RTPCodecType::Video,
        Some(RTCRtpTransceiverInit {
            direction: RTCRtpTransceiverDirection::Recvonly,
            send_encodings: vec![],
        }),
    )
    .await?;
    let _dc = pc.create_data_channel("input", None).await?;
    let (packets_tx, mut packets_rx) = tokio::sync::mpsc::channel(1);
    pc.on_track(Box::new(move |track, _, _| {
        let tx = packets_tx.clone();
        Box::pin(async move {
            if track.read_rtp().await.is_ok() {
                let _ = tx.send(()).await;
            }
        })
    }));
    let offer = pc.create_offer(None).await?;
    let mut gathered = pc.gathering_complete_promise().await;
    pc.set_local_description(offer).await?;
    gathered.recv().await;
    let host = Arc::new(Session::new(vec![], vec![]).await?);
    let (answer, track) = host
        .answer(&pc.local_description().await.unwrap().sdp)
        .await?;
    let (frames_tx, frames_rx) = tokio::sync::mpsc::channel(1);
    let control = Arc::new(Mutex::new(ControlState::new(
        "test".into(),
        "test".into(),
        "ws://local".into(),
    )));
    let task = {
        let host = host.clone();
        tokio::spawn(async move {
            video::pump_video(&host, &track, frames_rx, control).await;
        })
    };
    // Pump masuk keadaan belum Connected dan belum ada frame. Windows tidak
    // menghasilkan frame sampai pump menyalakan arm_capture.
    tokio::time::sleep(Duration::from_millis(150)).await;
    assert!(!screen::capture_armed());
    pc.set_remote_description(RTCSessionDescription::answer(answer)?)
        .await?;
    let armed = tokio::time::timeout(Duration::from_secs(3), async {
        while !screen::capture_armed() {
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await;
    if armed.is_err() {
        task.abort();
        host.close().await?;
        client.close().await?;
        anyhow::bail!("capture tidak pernah armed: pump menunggu frame, capture menunggu pump");
    }
    // Connected tanpa cache/IDR belum boleh dianggap akhir sumber.
    tokio::time::sleep(Duration::from_millis(150)).await;
    assert!(
        !task.is_finished(),
        "pump berhenti saat menunggu frame pertama"
    );
    let mut encoder = screen::TestPatternEncoder::new()?;
    frames_tx
        .send(screen::EncodedFrame {
            data: encoder.encode_next(320, 180)?,
            captured_at: Instant::now(),
            encode_us: 0,
        })
        .await?;
    assert!(
        tokio::time::timeout(Duration::from_secs(3), packets_rx.recv())
            .await?
            .is_some()
    );
    // Sumber diam, channel masih TERBUKA. Penutupan transport tetap harus
    // membangunkan pump; tidak boleh perlu frame kedua untuk teardown.
    host.close().await?;
    tokio::time::timeout(Duration::from_secs(2), task).await??;
    assert!(!screen::capture_armed());
    drop(frames_tx);
    client.close().await?;
    Ok(())
}
