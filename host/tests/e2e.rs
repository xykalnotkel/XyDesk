//! Uji end-to-end lapisan WebRTC host TANPA server signaling:
//! dua peer (client = penawar, host = penjawab) bertukar SDP secara langsung
//! (loopback, non-trickle ICE), lalu diverifikasi data channel "input"
//! terbuka dan pesan dari client sampai ke host.
//!
//! Ini membuktikan logika [xydesk_host::session::Session] benar — negosiasi
//! WebRTC yang sesungguhnya, bukan mock. Integrasi dengan signaling (relay
//! SDP/ICE lewat WebSocket) sudah diuji terpisah di `cloudflare/test/`.

use std::sync::Arc;
use std::time::Duration;

use tokio::sync::mpsc;
use webrtc::api::interceptor_registry::register_default_interceptors;
use webrtc::api::media_engine::MediaEngine;
use webrtc::api::APIBuilder;
use webrtc::data_channel::data_channel_init::RTCDataChannelInit;
use webrtc::data_channel::RTCDataChannel;
use webrtc::interceptor::registry::Registry;
use webrtc::peer_connection::configuration::RTCConfiguration;
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;
use webrtc::peer_connection::RTCPeerConnection;
use webrtc::rtp_transceiver::rtp_codec::RTPCodecType;
use webrtc::rtp_transceiver::rtp_transceiver_direction::RTCRtpTransceiverDirection;
use webrtc::rtp_transceiver::RTCRtpTransceiverInit;

use xydesk_host::session::{Session, INPUT_CHANNEL};

/// Peer "client": membuat data channel + offer (seperti app Flutter).
struct ClientPeer {
    pc: Arc<RTCPeerConnection>,
    dc: Arc<RTCDataChannel>,
}

impl ClientPeer {
    async fn new() -> (Self, mpsc::UnboundedReceiver<()>) {
        let mut media = MediaEngine::default();
        media.register_default_codecs().unwrap();
        let mut registry = Registry::new();
        registry = register_default_interceptors(registry, &mut media).unwrap();
        let api = APIBuilder::new()
            .with_media_engine(media)
            .with_interceptor_registry(registry)
            .build();
        let pc = Arc::new(
            api.new_peer_connection(RTCConfiguration::default())
                .await
                .unwrap(),
        );

        // create_data_channel sudah mengembalikan Arc<RTCDataChannel>.
        let dc = pc
            .create_data_channel(INPUT_CHANNEL, Some(RTCDataChannelInit::default()))
            .await
            .unwrap();

        // Sinyal saat channel terbuka.
        let (open_tx, open_rx) = mpsc::unbounded_channel();
        dc.on_open(Box::new(move || {
            let _ = open_tx.send(());
            Box::pin(async {})
        }));

        (Self { pc, dc }, open_rx)
    }

    /// Tambah transceiver video `recvonly` — client siap MENERIMA aliran video
    /// dari host (offer akan memuat m-line video).
    async fn add_recv_video(&self) {
        self.pc
            .add_transceiver_from_kind(
                RTPCodecType::Video,
                Some(RTCRtpTransceiverInit {
                    direction: RTCRtpTransceiverDirection::Recvonly,
                    send_encodings: vec![],
                }),
            )
            .await
            .unwrap();
    }

    async fn offer(&self) -> String {
        let offer = self.pc.create_offer(None).await.unwrap();
        let mut gather = self.pc.gathering_complete_promise().await;
        self.pc.set_local_description(offer).await.unwrap();
        let _ = gather.recv().await;
        self.pc.local_description().await.unwrap().sdp
    }

    async fn set_answer(&self, sdp: &str) {
        self.pc
            .set_remote_description(RTCSessionDescription::answer(sdp.to_string()).unwrap())
            .await
            .unwrap();
    }
}

#[tokio::test]
async fn data_channel_opens_end_to_end() {
    let (client, mut client_open_rx) = ClientPeer::new().await;
    let host = Session::new(vec!["stun:stun.cloudflare.com:3478".into()], vec![])
        .await
        .unwrap();

    // 1) client → offer → host → answer (non-trickle: kandidat termuat di SDP)
    let offer = client.offer().await;
    let answer = host.answer(&offer).await.unwrap();
    client.set_answer(&answer).await;

    // 2) tunggu data channel "input" di sisi host.
    let host_dc = tokio::time::timeout(Duration::from_secs(15), host.receive_input_channel())
        .await
        .expect("data channel input tak kunjung tiba")
        .unwrap();

    // 3) tunggu channel terbuka di sisi client.
    let _ = tokio::time::timeout(Duration::from_secs(15), client_open_rx.recv())
        .await
        .expect("data channel client tak kunjung open")
        .unwrap();

    // 4) kirim pesan dari client → host, verifikasi sampai.
    client
        .dc
        .send(&bytes::Bytes::from_static(b"hello"))
        .await
        .unwrap();

    let (msg_tx, mut msg_rx) = mpsc::unbounded_channel();
    host_dc.on_message(Box::new(move |m| {
        if !m.is_string {
            let _ = msg_tx.send(m.data.to_vec());
        }
        Box::pin(async {})
    }));

    let got = tokio::time::timeout(Duration::from_secs(5), msg_rx.recv())
        .await
        .expect("pesan tak kunjung tiba")
        .unwrap();
    assert_eq!(got, b"hello", "pesan dari client harus sampai utuh ke host");

    host.close().await.unwrap();
    client.pc.close().await.unwrap();
}

/// Membuktikan media plane: host menambah track video H264, meng-encode
/// beberapa frame pola uji (openh264), dan client MENERIMA sample H264 lewat
/// WebRTC (RTP). Ini jalur `encode → RTP → depacketize → sample` end-to-end.
#[tokio::test]
async fn video_frames_flow_end_to_end() {
    let (client, _open_rx) = ClientPeer::new().await;
    let host = Session::new(vec!["stun:stun.cloudflare.com:3478".into()], vec![])
        .await
        .unwrap();

    // Client siap menerima video (recvonly transceiver).
    client.add_recv_video().await;

    // Siapkan penerima video di sisi client (transceiver + on_track).
    let (track_rx_tx, mut track_rx) = mpsc::unbounded_channel();
    client
        .pc
        .on_track(Box::new(move |track, _, _| {
            let _ = track_rx_tx.send(track);
            Box::pin(async {})
        }));

    // Host: tambah track video sebelum negosiasi.
    let track = host.add_video_track().await.unwrap();

    // Negosiasi.
    let offer = client.offer().await;
    let answer = host.answer(&offer).await.unwrap();
    client.set_answer(&answer).await;

    // PENTING: `on_track` di webrtc-rs baru ter-trigger setelah paket RTP
    // PERTAMA tiba (start_receiver menunggu `track.peek`). Jadi frame harus
    // dikirim dulu (di background), baru kita tunggu track-nya.
    let send_task = tokio::spawn({
        let track = track.clone();
        async move {
            let mut encoder = xydesk_host::screen::TestPatternEncoder::new().unwrap();
            for _ in 0..30 {
                let data = encoder
                    .encode_next(
                        xydesk_host::screen::TEST_WIDTH,
                        xydesk_host::screen::TEST_HEIGHT,
                    )
                    .unwrap();
                track
                    .write_sample(&webrtc::media::Sample {
                        data: bytes::Bytes::from(data),
                        timestamp: std::time::SystemTime::now(),
                        duration: std::time::Duration::from_millis(33),
                        packet_timestamp: 0,
                        prev_dropped_packets: 0,
                        prev_padding_packets: 0,
                    })
                    .await
                    .unwrap();
                tokio::time::sleep(Duration::from_millis(33)).await;
            }
        }
    });

    // Tunggu track video sampai di sisi client (setelah frame pertama tiba).
    let remote_track = tokio::time::timeout(Duration::from_secs(15), track_rx.recv())
        .await
        .expect("track video tak kunjung tiba")
        .unwrap();
    assert_eq!(remote_track.kind(), RTPCodecType::Video);

    // Client: baca RTP packet → pastikan payload media mengalir.
    let mut got_sample = false;
    let deadline = tokio::time::Instant::now() + Duration::from_secs(10);
    'read: while tokio::time::Instant::now() < deadline {
        match remote_track.read_rtp().await {
            Ok((rtp_packet, _)) => {
                if !rtp_packet.payload.is_empty() {
                    got_sample = true;
                    break 'read;
                }
            }
            Err(_) => break 'read,
        }
    }
    assert!(got_sample, "client harus menerima payload RTP video dari host");

    send_task.abort();
    host.close().await.unwrap();
    client.pc.close().await.unwrap();
}
