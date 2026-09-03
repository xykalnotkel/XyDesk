//! Loop streaming video: frame H264 ter-encode → track RTP.
//!
//! Dipakai oleh `main.rs` (produksi) dan `tests/loopback.rs` (uji
//! integrasi), sehingga jalur "frame → RTP" yang diuji adalah KODE
//! PRODUKSI yang sama — bukan tiruan di dalam test.

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime};

use webrtc::media::Sample;
use webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState;
use webrtc::track::track_local::track_local_static_sample::TrackLocalStaticSample;

use crate::control::ControlState;
use crate::screen::{self, EncodedFrame};
use crate::session::Session;

/// Alirkan frame dari channel ke track RTP sampai channel tertutup atau
/// koneksi gagal/ditutup.
///
/// Kontrak "gambar pasti muncul di klien" (regresi bug nyata 3 Sep 2026):
/// 1. Frame TIDAK ditulis sebelum transport `Connected`. Frame yang
///    ditulis lebih awal dibuang ICE/DTLS yang belum jadi — termasuk
///    IDR pertama yang membawa SPS/PPS. Tanpa SPS/PPS decoder klien
///    tidak pernah bisa memulai: layar hitam, sesi tampak "terhubung",
///    paket mengalir, `framesDecoded` = 0.
/// 2. Saat transisi ke `Connected`, encoder diminta menghasilkan keyframe
///    segar (`screen::request_keyframe`) — sumber frame merespons dengan
///    membangun ulang encoder sehingga frame berikutnya adalah IDR yang
///    membawa SPS/PPS, dan pasti melewati transport yang sudah siap.
pub async fn pump_video(
    session: &Session,
    track: &Arc<TrackLocalStaticSample>,
    mut frames: tokio::sync::mpsc::Receiver<EncodedFrame>,
    control: Arc<Mutex<ControlState>>,
) {
    println!("[xydesk-host] track video siap — streaming");
    let mut prev_connected = false;

    // Statistik video untuk control API (shell desktop): frame terkirim +
    // FPS rata-rata jendela 1 detik + status encoder + latensi pipeline.
    let mut fps_window: u64 = 0;
    let mut fps_start = Instant::now();
    let mut fps_now = 0.0_f64;

    while let Some(frame) = frames.recv().await {
        let state = session.peer().connection_state();
        if matches!(
            state,
            RTCPeerConnectionState::Closed | RTCPeerConnectionState::Failed
        ) {
            // Sesi berakhir; tugas lain (slot, pairing) sudah dibersihkan
            // oleh handler state di main.rs. Berhenti di sini supaya task
            // streaming tidak menggantung selamanya.
            break;
        }
        let connected = state == RTCPeerConnectionState::Connected;
        if connected && !prev_connected {
            // Transisi baru ke Connected: minta IDR segar (SPS/PPS +
            // slice). Frame yang mengantre di channel akan menyusul dan
            // tetap valid — hanya perlu memastikan satu IDR dengan
            // parameter set merambat setelah transport siap.
            screen::request_keyframe();
            println!("[xydesk-host] koneksi Connected — keyframe segar diminta");
        }
        prev_connected = connected;
        if !connected {
            // Transport belum siap: frame apa pun yang ditulis sekarang
            // (termasuk IDR+SPS/PPS) akan hilang di jaringan. Buang.
            continue;
        }

        // Latensi pipeline host: sejak frame ditangkap di thread capture
        // sampai saat ini (sesaat sebelum ditulis ke track RTP).
        let latency_ms = frame.captured_at.elapsed().as_secs_f64() * 1000.0;
        let sample = Sample {
            data: bytes::Bytes::from(frame.data),
            timestamp: SystemTime::now(),
            duration: screen::frame_duration(),
            packet_timestamp: 0,
            prev_dropped_packets: 0,
            prev_padding_packets: 0,
        };
        if let Err(e) = track.write_sample(&sample).await {
            eprintln!("[xydesk-host] kirim frame gagal: {e}");
            break;
        }
        fps_window += 1;
        let elapsed = fps_start.elapsed();
        if elapsed >= Duration::from_secs(1) {
            fps_now = fps_window as f64 / elapsed.as_secs_f64();
            fps_window = 0;
            fps_start = Instant::now();
        }
        {
            let mut st = crate::recover_lock(&control);
            st.video.record_frame(latency_ms);
            st.video.fps = fps_now;
            st.video.nvenc = screen::nvenc_active();
            st.video.encoder = screen::encoder_label();
        }
    }
}
