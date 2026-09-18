//! Real SDP negotiation and RTP delivery; synthetic pixels, not a Windows desktop.
use std::time::Duration;
use webrtc::{
    media::Sample,
    peer_connection::{
        peer_connection_state::RTCPeerConnectionState,
        sdp::session_description::RTCSessionDescription,
    },
    rtp_transceiver::{
        rtp_codec::RTPCodecType, rtp_transceiver_direction::RTCRtpTransceiverDirection,
        RTCRtpTransceiverInit,
    },
};
use xydesk_host::{session::Session, software_video::SoftwareEncoder};
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn hd_profile_negotiates_and_sps_arrives_on_real_rtp() {
    for level in [40, 51] {
        let client = Session::new_with_video_level(vec![], vec![], level)
            .await
            .unwrap();
        let pc = client.peer();
        pc.add_transceiver_from_kind(
            RTPCodecType::Video,
            Some(RTCRtpTransceiverInit {
                direction: RTCRtpTransceiverDirection::Recvonly,
                send_encodings: vec![],
            }),
        )
        .await
        .unwrap();
        let (tx, mut rx) = tokio::sync::mpsc::channel(1);
        pc.on_track(Box::new(move |track, _, _| {
            let tx = tx.clone();
            Box::pin(async move {
                use webrtc::rtp::packetizer::Depacketizer;
                let mut depay = webrtc::rtp::codecs::h264::H264Packet::default();
                while let Ok((packet, _)) = track.read_rtp().await {
                    if let Ok(bytes) = depay.depacketize(&packet.payload) {
                        if let Some([_, _, level]) =
                            xydesk_host::software_video::sps_profile_level(&bytes)
                        {
                            let _ = tx.send(level).await;
                            break;
                        }
                    }
                }
            })
        }));
        let offer = pc.create_offer(None).await.unwrap();
        let mut gather = pc.gathering_complete_promise().await;
        pc.set_local_description(offer).await.unwrap();
        gather.recv().await;
        let offer = pc.local_description().await.unwrap().sdp;
        assert_eq!(xydesk_host::video_policy::offer_level(&offer), level);
        let host = Session::new_with_video_level(vec![], vec![], level)
            .await
            .unwrap();
        let answer = host.answer_media(&offer, false, false).await.unwrap();
        assert!(answer
            .sdp
            .contains(&format!("profile-level-id=42e0{level:02x}")));
        pc.set_remote_description(RTCSessionDescription::answer(answer.sdp).unwrap())
            .await
            .unwrap();
        tokio::time::timeout(Duration::from_secs(10), async {
            while pc.connection_state() != RTCPeerConnectionState::Connected
                || host.peer().connection_state() != RTCPeerConnectionState::Connected
            {
                tokio::time::sleep(Duration::from_millis(20)).await;
            }
        })
        .await
        .unwrap();
        let mut encoder = SoftwareEncoder::with_policy(1, level).unwrap();
        let pixels = vec![170; 1920 * 1080 * 4];
        let frame = encoder.encode(&pixels, 1920, 1080).unwrap();
        answer
            .video
            .write_sample(&Sample {
                data: frame.into(),
                duration: Duration::from_millis(33),
                ..Default::default()
            })
            .await
            .unwrap();
        assert_eq!(
            tokio::time::timeout(Duration::from_secs(5), rx.recv())
                .await
                .unwrap(),
            Some(level)
        );
        pc.close().await.unwrap();
        host.peer().close().await.unwrap();
    }
}
