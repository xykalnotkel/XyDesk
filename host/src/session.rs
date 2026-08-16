//! Sesi WebRTC host — host berperan ANSWERER: menjawab offer dari client,
//! menerima data channel "input" (mouse/keyboard), dan (Fase 0) mengirim
//! track video.
//!
//! Modul ini sengaja tidak menyentuh WebSocket — SDP/ICE masuk-keluar lewat
//! pemanggil (`main.rs`) agar logika WebRTC terpisah dari server signaling.

use std::sync::Arc;

use anyhow::{Context, Result};
use tokio::sync::mpsc;
use webrtc::api::interceptor_registry::register_default_interceptors;
use webrtc::api::media_engine::MediaEngine;
use webrtc::api::APIBuilder;
use webrtc::data_channel::RTCDataChannel;
use webrtc::ice_transport::ice_server::RTCIceServer;
use webrtc::interceptor::registry::Registry;
use webrtc::peer_connection::configuration::RTCConfiguration;
use webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState;
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;
use webrtc::peer_connection::RTCPeerConnection;
use webrtc::rtp_transceiver::rtp_codec::RTCRtpCodecCapability;
use webrtc::track::track_local::track_local_static_sample::TrackLocalStaticSample;

/// Nama data channel untuk input kontrol (sama di sisi client Flutter).
pub const INPUT_CHANNEL: &str = "input";

/// Kandidat ICE yang diterima dari signaling.
#[derive(Clone, Debug)]
pub struct IceCandidate {
    pub candidate: String,
    pub sdp_mid: Option<String>,
    pub sdp_mline_index: Option<u16>,
}

pub struct Session {
    pc: Arc<RTCPeerConnection>,
    incoming_rx: tokio::sync::Mutex<mpsc::UnboundedReceiver<Arc<RTCDataChannel>>>,
}

impl Session {
    /// Membuat peer connection (answerer) dengan server STUN/TURN opsional.
    pub async fn new(stun: Vec<String>, turn: Vec<RTCIceServer>) -> Result<Self> {
        let mut media = MediaEngine::default();
        media.register_default_codecs().context("gagal daftar codec")?;

        let mut registry = Registry::new();
        registry = register_default_interceptors(registry, &mut media)
            .context("gagal daftar interceptor")?;

        let api = APIBuilder::new()
            .with_media_engine(media)
            .with_interceptor_registry(registry)
            .build();

        let mut ice_servers = Vec::new();
        if !stun.is_empty() {
            ice_servers.push(RTCIceServer {
                urls: stun,
                ..Default::default()
            });
        }
        ice_servers.extend(turn);

        let pc = Arc::new(
            api.new_peer_connection(RTCConfiguration {
                ice_servers,
                ..Default::default()
            })
            .await?,
        );

        // Tangkap data channel masuk ke antrean.
        let (tx, rx) = mpsc::unbounded_channel();
        pc.on_data_channel(Box::new(move |dc: Arc<RTCDataChannel>| {
            let tx = tx.clone();
            Box::pin(async move {
                let _ = tx.send(dc);
            })
        }));

        Ok(Session {
            pc,
            incoming_rx: tokio::sync::Mutex::new(rx),
        })
    }

    pub fn peer(&self) -> Arc<RTCPeerConnection> {
        self.pc.clone()
    }

    /// Menyetujui offer client; mengembalikan SDP jawaban (kandidat sudah
    /// tergabung karena kita menunggu ICE gathering selesai — non-trickle).
    pub async fn answer(&self, offer_sdp: &str) -> Result<String> {
        let offer = RTCSessionDescription::offer(offer_sdp.to_string())
            .context("SDP offer tidak valid")?;
        self.pc
            .set_remote_description(offer)
            .await
            .context("gagal set remote description")?;

        let answer = self
            .pc
            .create_answer(None)
            .await
            .context("gagal create answer")?;

        let mut gather = self.pc.gathering_complete_promise().await;
        self.pc
            .set_local_description(answer)
            .await
            .context("gagal set local description")?;
        let _ = gather.recv().await;

        Ok(self
            .pc
            .local_description()
            .await
            .map(|d| d.sdp)
            .unwrap_or_default())
    }

    /// Menambah kandidat ICE dari client (via signaling).
    pub async fn add_ice_candidate(&self, c: IceCandidate) -> Result<()> {
        self.pc
            .add_ice_candidate(webrtc::ice_transport::ice_candidate::RTCIceCandidateInit {
                candidate: c.candidate,
                sdp_mid: c.sdp_mid,
                sdp_mline_index: c.sdp_mline_index,
                username_fragment: None,
            })
            .await
            .context("gagal tambah ICE candidate")
    }

    /// Menambahkan track video H264 ke peer connection. Mengembalikan handle
    /// track yang dipakai untuk menulis frame (via `write_sample`).
    pub async fn add_video_track(&self) -> Result<Arc<TrackLocalStaticSample>> {
        let track = Arc::new(TrackLocalStaticSample::new(
            RTCRtpCodecCapability {
                mime_type: "video/H264".to_owned(),
                clock_rate: 90000,
                channels: 0,
                sdp_fmtp_line: "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f"
                    .to_owned(),
                rtcp_feedback: vec![],
            },
            "video".to_owned(),
            "xydesk".to_owned(),
        ));
        // `add_track` membuat/memakai transceiver video (sendrecv) otomatis.
        self.pc
            .add_track(Arc::clone(&track) as Arc<dyn webrtc::track::track_local::TrackLocal + Send + Sync>)
            .await
            .context("gagal add track video")?;
        Ok(track)
    }

    /// Menunggu data channel "input" dari client (membuang channel lain).
    pub async fn receive_input_channel(&self) -> Result<Arc<RTCDataChannel>> {
        let mut rx = self.incoming_rx.lock().await;
        loop {
            let dc = rx
                .recv()
                .await
                .context("koneksi ditutup sebelum data channel tiba")?;
            if dc.label() == INPUT_CHANNEL {
                return Ok(dc);
            }
        }
    }

    /// Mendaftarkan handler status koneksi.
    pub fn on_state_change<F>(&self, mut f: F)
    where
        F: FnMut(RTCPeerConnectionState) + Send + Sync + 'static,
    {
        self.pc
            .on_peer_connection_state_change(Box::new(move |s| {
                f(s);
                Box::pin(async {})
            }));
    }

    /// Mengirim data biner lewat data channel (mis. balasan input).
    pub async fn send(&self, dc: &RTCDataChannel, data: Vec<u8>) -> Result<()> {
        dc.send(&bytes::Bytes::from(data))
            .await
            .context("gagal kirim data")?;
        Ok(())
    }

    pub async fn close(&self) -> Result<()> {
        self.pc.close().await?;
        Ok(())
    }
}
