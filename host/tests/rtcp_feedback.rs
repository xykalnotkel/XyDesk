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
async fn receiver_can_recover_a_lost_packet_and_request_a_keyframe() -> anyhow::Result<()> {
    screen::disarm_capture();
    // Fixture mengamati duplikat RTP yang diminta ulang secara sengaja.
    // Hanya receiver tes ini mematikan replay filter; konfigurasi produk utuh.
    let mut media = webrtc::api::media_engine::MediaEngine::default();
    media.register_default_codecs()?;
    let mut setting = webrtc::api::setting_engine::SettingEngine::default();
    setting.disable_srtp_replay_protection(true);
    let api = webrtc::api::APIBuilder::new()
        .with_media_engine(media)
        .with_setting_engine(setting)
        .build();
    let pc = Arc::new(api.new_peer_connection(Default::default()).await?);
    pc.add_transceiver_from_kind(
        RTPCodecType::Video,
        Some(RTCRtpTransceiverInit {
            direction: RTCRtpTransceiverDirection::Recvonly,
            send_encodings: vec![],
        }),
    )
    .await?;
    let _dc = pc.create_data_channel("input", None).await?;
    let (packets_tx, mut packets_rx) = tokio::sync::mpsc::channel(256);
    pc.on_track(Box::new(move |track, _, _| {
        let tx = packets_tx.clone();
        Box::pin(async move {
            while let Ok((packet, _)) = track.read_rtp().await {
                if tx
                    .send((packet.header.sequence_number, packet.header.ssrc))
                    .await
                    .is_err()
                {
                    break;
                }
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
        pc.close().await?;
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
        .send(screen::EncodedFrame::new(
            encoder.encode_next(320, 180)?,
            Instant::now(),
            0,
        ))
        .await?;
    let (sequence, ssrc) = tokio::time::timeout(Duration::from_secs(3), packets_rx.recv())
        .await?
        .unwrap();
    // Sumber tidak mengirim frame lain. Paket dengan sequence sama berikutnya
    // harus berasal dari retransmisi NACK, bukan frame capture baru.
    pc.write_rtcp(&[Box::new(
        webrtc::rtcp::transport_feedbacks::transport_layer_nack::TransportLayerNack {
            sender_ssrc: 123,
            media_ssrc: ssrc,
            nacks: vec![
                webrtc::rtcp::transport_feedbacks::transport_layer_nack::NackPair {
                    packet_id: sequence,
                    lost_packets: 0,
                },
            ],
        },
    )])
    .await?;
    tokio::time::timeout(Duration::from_secs(3), async {
        while let Some((seq, _)) = packets_rx.recv().await {
            if seq == sequence {
                return;
            }
        }
        panic!("track tutup sebelum retransmisi");
    })
    .await
    .expect("NACK tidak memicu pengiriman ulang paket");
    screen::take_keyframe_request();
    pc.write_rtcp(&[Box::new(
        webrtc::rtcp::payload_feedbacks::picture_loss_indication::PictureLossIndication {
            sender_ssrc: 123,
            media_ssrc: ssrc,
        },
    )])
    .await?;
    tokio::time::timeout(Duration::from_secs(3), async {
        while !screen::peek_keyframe_request() {
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .expect("PLI tidak sampai ke gerbang keyframe encoder");
    // Sumber diam, channel masih TERBUKA. Penutupan transport tetap harus
    // membangunkan pump; tidak boleh perlu frame kedua untuk teardown.
    host.close().await?;
    tokio::time::timeout(Duration::from_secs(2), task).await??;
    assert!(!screen::capture_armed());
    drop(frames_tx);
    pc.close().await?;
    Ok(())
}
