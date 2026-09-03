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
use webrtc::rtp_transceiver::rtp_codec::RTPCodecType;
use webrtc::track::track_local::track_local_static_sample::TrackLocalStaticSample;
use webrtc::track::track_remote::TrackRemote;

/// Nama data channel untuk input kontrol (sama di sisi client Flutter).
pub const INPUT_CHANNEL: &str = "input";

/// Lama yang diberikan kepada sesi untuk pulih sendiri setelah koneksi
/// terlepas sebentar, sebelum host mencabut slotnya.
///
/// Agent ICE webrtc-rs memasukkan sesi ke `Disconnected` pada setiap blip
/// jaringan biasa — Wi-Fi berpindah kanal, sinyal hilang dua detik, laptop
/// dibuka setelah ditutup — dan pada umumnya pulih sendiri dalam hitungan
/// detik. Batas ini cukup panjang untuk blip semacam itu dan cukup pendek
/// untuk tidak membiarkan capture + encoder bekerja untuk penonton yang sudah
/// pergi.
pub const DISCONNECT_GRACE: std::time::Duration = std::time::Duration::from_secs(15);

/// Yang harus dilakukan host terhadap slot sesi (izin pairing + status shell)
/// saat peer connection berpindah keadaan.
///
/// Kebijakannya ditaruh ke satu fungsi murni ([`slot_action`]) supaya bisa
/// diuji tanpa jaringan. Sebelumnya keputusan ini tersebar di `matches!` di
/// dalam handler `main.rs`, dan `Disconnected` disamakan dengan `Failed` —
/// gejalanya lihat komentar [`slot_action`].
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SlotAction {
    /// Sesi masih hidup (atau sedang dibangun) — jangan sentuh apa pun.
    Keep,
    /// Cabut slot sekarang: koneksi mati dan tidak akan pulih sendiri.
    ReleaseNow,
    /// Cabut slot hanya bila sesi belum `Connected` lagi setelah
    /// [`DISCONNECT_GRACE`] berlalu.
    ReleaseAfterGrace,
}

/// Klasifikasi satu transisi keadaan menjadi tindakan pada slot sesi.
///
/// Kenapa `Disconnected` TIDAK boleh diperlakukan seperti `Failed`:
/// mencabutnya seketika berarti izin pairing peer itu dicabut, sementara
/// kandidat ICE berikutnya dari peer yang sama ditolak ("bukan sesi aktif") —
/// jadi sesi yang sebenarnya masih bisa hidup menjadi mustahil pulih. Pada
/// saat yang sama task video tetap jalan (ia hanya berhenti pada
/// `Closed`/`Failed`), sehingga capture + encoder tidak pernah dilepas. Di
/// Windows itu dua kali lipat mahal: duplikasi DXGI yang menggantung bisa
/// membuat sesi berikutnya mendapat layar hitam.
pub fn slot_action(state: RTCPeerConnectionState) -> SlotAction {
    match state {
        RTCPeerConnectionState::Failed | RTCPeerConnectionState::Closed => SlotAction::ReleaseNow,
        RTCPeerConnectionState::Disconnected => SlotAction::ReleaseAfterGrace,
        // `Unspecified` / `New` / `Connecting` / `Connected`: sesi hidup atau
        // sedang dibangun ulang — jangan sentuh slot-nya.
        _ => SlotAction::Keep,
    }
}

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
    /// Track audio jarak jauh dari client (mic passthrough), bila ada.
    remote_audio: Arc<tokio::sync::Mutex<Option<Arc<TrackRemote>>>>,
}

// RTCPeerConnection tidak implement Debug; cukup identitas struct saja.
impl std::fmt::Debug for Session {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Session").finish_non_exhaustive()
    }
}

/// Hasil negosiasi media satu sesi (video wajib; audio opsional).
pub struct MediaTracks {
    pub sdp: String,
    pub video: Arc<TrackLocalStaticSample>,
    /// Ada bila negosiasi meminta audio forward (host → client).
    pub audio: Option<Arc<TrackLocalStaticSample>>,
    /// Ada bila negosiasi meminta mic host (mikrofon PC → client).
    pub mic: Option<Arc<TrackLocalStaticSample>>,
}

impl Session {
    /// Membuat peer connection (answerer) dengan server STUN/TURN opsional.
    pub async fn new(stun: Vec<String>, turn: Vec<RTCIceServer>) -> Result<Self> {
        let mut media = MediaEngine::default();
        media
            .register_default_codecs()
            .context("gagal daftar codec")?;

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

        // Tangkap track audio masuk (mic client) untuk passthrough.
        let remote_audio: Arc<tokio::sync::Mutex<Option<Arc<TrackRemote>>>> =
            Arc::new(tokio::sync::Mutex::new(None));
        let audio_slot = Arc::clone(&remote_audio);
        pc.on_track(Box::new(move |track, _, _| {
            let audio_slot = Arc::clone(&audio_slot);
            Box::pin(async move {
                if track.kind() == RTPCodecType::Audio {
                    *audio_slot.lock().await = Some(track);
                }
            })
        }));

        Ok(Session {
            pc,
            incoming_rx: tokio::sync::Mutex::new(rx),
            remote_audio,
        })
    }

    pub fn peer(&self) -> Arc<RTCPeerConnection> {
        self.pc.clone()
    }

    /// Menyetujui offer client; mengembalikan SDP jawaban (kandidat sudah
    /// tergabung karena kita menunggu ICE gathering selesai — non-trickle)
    /// beserta track video yang dipakai untuk menulis frame.
    ///
    /// **Urutan penting:** `add_video_track` dipanggil SEBELUM `create_answer`.
    /// Kalau track didaftarkan setelah answer dibuat (dan dikirim), m-line
    /// video tidak ada di SDP jawaban — client tidak pernah menerima gambar,
    /// walau koneksi "berhasil". Bug ini pernah lolos karena tidak ada test
    /// loopback; lihat `tests/loopback.rs`.
    pub async fn answer(&self, offer_sdp: &str) -> Result<(String, Arc<TrackLocalStaticSample>)> {
        let media = self.answer_media(offer_sdp, false, false).await?;
        Ok((media.sdp, media.video))
    }

    /// Seperti [`Session::answer`], tetapi boleh menyertakan track audio
    /// (forward host → client) dan/atau track mic (mikrofon host → client).
    /// Track harus terdaftar SEBELUM `create_answer` — alasan yang sama
    /// dengan video di atas.
    pub async fn answer_media(
        &self,
        offer_sdp: &str,
        with_audio: bool,
        with_mic: bool,
    ) -> Result<MediaTracks> {
        let video = self.add_video_track().await?;
        let audio = if with_audio {
            Some(self.add_audio_track().await?)
        } else {
            None
        };
        let mic = if with_mic {
            Some(self.add_mic_track().await?)
        } else {
            None
        };

        let offer =
            RTCSessionDescription::offer(offer_sdp.to_string()).context("SDP offer tidak valid")?;
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

        let sdp = self
            .pc
            .local_description()
            .await
            .map(|d| d.sdp)
            .unwrap_or_default();

        Ok(MediaTracks {
            sdp,
            video,
            audio,
            mic,
        })
    }

    /// Menambah track audio Opus (48 kHz stereo) untuk forward host → client.
    pub async fn add_audio_track(&self) -> Result<Arc<TrackLocalStaticSample>> {
        let track = Arc::new(TrackLocalStaticSample::new(
            RTCRtpCodecCapability {
                mime_type: "audio/opus".to_owned(),
                clock_rate: 48000,
                channels: 2,
                sdp_fmtp_line: "minptime=10;useinbandfec=1".to_owned(),
                rtcp_feedback: vec![],
            },
            "audio".to_owned(),
            "xydesk".to_owned(),
        ));
        self.pc
            .add_track(
                Arc::clone(&track) as Arc<dyn webrtc::track::track_local::TrackLocal + Send + Sync>
            )
            .await
            .context("gagal add track audio")?;
        Ok(track)
    }

    /// Menambah track audio Opus (48 kHz mono) untuk mic host → client.
    /// Stream id `mic` membedakannya dari loopback (`audio`) di sisi client.
    pub async fn add_mic_track(&self) -> Result<Arc<TrackLocalStaticSample>> {
        let track = Arc::new(TrackLocalStaticSample::new(
            RTCRtpCodecCapability {
                mime_type: "audio/opus".to_owned(),
                clock_rate: 48000,
                channels: 1,
                sdp_fmtp_line: "minptime=10;useinbandfec=1".to_owned(),
                rtcp_feedback: vec![],
            },
            "mic".to_owned(),
            "xydesk".to_owned(),
        ));
        self.pc
            .add_track(
                Arc::clone(&track) as Arc<dyn webrtc::track::track_local::TrackLocal + Send + Sync>
            )
            .await
            .context("gagal add track mic")?;
        Ok(track)
    }

    /// Menerima track audio mic dari client dan mengirim paket Opus yang
    /// diterima ke `sink` (diputar oleh modul `audio`). Berakhir saat track
    /// selesai atau sink tertutup.
    pub async fn receive_mic(
        &self,
        sink: tokio::sync::mpsc::UnboundedSender<Vec<u8>>,
    ) -> Result<()> {
        let remote: Arc<TrackRemote> = {
            let mut waited = 0usize;
            loop {
                if waited > 60 {
                    anyhow::bail!("track mic client tidak kunjung tiba");
                }
                if let Some(t) = self.remote_audio.lock().await.as_ref() {
                    break t.clone();
                }
                tokio::time::sleep(std::time::Duration::from_millis(500)).await;
                waited += 1;
            }
        };

        while let Ok((rtp, _)) = remote.read_rtp().await {
            if sink.send(rtp.payload.to_vec()).is_err() {
                break; // sink render sudah berhenti
            }
        }
        Ok(())
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
                sdp_fmtp_line:
                    "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f"
                        .to_owned(),
                rtcp_feedback: vec![],
            },
            "video".to_owned(),
            "xydesk".to_owned(),
        ));
        // `add_track` membuat/memakai transceiver video (sendrecv) otomatis.
        self.pc
            .add_track(
                Arc::clone(&track) as Arc<dyn webrtc::track::track_local::TrackLocal + Send + Sync>
            )
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
        self.pc.on_peer_connection_state_change(Box::new(move |s| {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn koneksi_blip_jaringan_tidak_langsung_mencabut_slot() {
        // Inilah regresi yang dulunya ada: `Disconnected` diperlakukan sama
        // dengan `Failed`, padahal ia keadaan sementara yang biasa pulih
        // sendiri. Kalau dicabut seketika, kandidat ICE dari peer yang sama
        // ditolak dan sesi tidak bisa hidup lagi.
        assert_eq!(
            slot_action(RTCPeerConnectionState::Disconnected),
            SlotAction::ReleaseAfterGrace
        );
        assert!(DISCONNECT_GRACE >= std::time::Duration::from_secs(10));
        assert!(DISCONNECT_GRACE <= std::time::Duration::from_secs(30));
    }

    #[test]
    fn koneksi_mati_permanen_mencabut_slot_sekarang() {
        for s in [
            RTCPeerConnectionState::Failed,
            RTCPeerConnectionState::Closed,
        ] {
            assert_eq!(slot_action(s), SlotAction::ReleaseNow, "keadaan {s:?}");
        }
    }

    #[test]
    fn sesi_hidup_atau_menuju_connected_tidak_disentuh() {
        for s in [
            RTCPeerConnectionState::New,
            RTCPeerConnectionState::Connecting,
            RTCPeerConnectionState::Connected,
            RTCPeerConnectionState::Unspecified,
        ] {
            assert_eq!(slot_action(s), SlotAction::Keep, "keadaan {s:?}");
        }
    }
}
