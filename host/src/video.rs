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

/// Jeda antar pengiriman ulang IDR simpanan sambil menunggu IDR hidup.
///
/// Cukup rapat agar gambar muncul sepersekian detik setelah `Connected`, cukup
/// renggang agar tidak membanjiri jalur naik untuk gambar yang sama persis.
pub const KEYFRAME_RESCUE_INTERVAL: Duration = Duration::from_millis(200);

/// Batas penyelamatan keyframe sejak transisi ke `Connected`.
///
/// Lewat batas ini host berhenti mengirim ulang: bila IDR hidup tidak juga
/// datang, mengirim gambar yang sama selamanya hanya membuang bitrate. Sisa
/// pemulihannya ada di tangan sumber frame — permintaan keyframe tetap
/// terpasang, sehingga frame pertama sesudah layar berubah memicu encoder baru
/// (lihat `screen::peek_keyframe_request`).
pub const KEYFRAME_RESCUE_WINDOW: Duration = Duration::from_secs(5);

/// Penyelamatan keyframe: IDR simpanan, kapan boleh dikirim lagi, kapan
/// menyerah, dan berapa kali sudah dikirim (bahan log jujur).
struct Rescue {
    data: Vec<u8>,
    next: Instant,
    until: Instant,
    sent: u32,
}

/// Statistik video untuk control API (shell desktop): frame terkirim + FPS
/// rata-rata jendela 1 detik + status encoder + latensi pipeline.
struct Stats {
    fps_window: u64,
    fps_start: Instant,
    fps_now: f64,
}

impl Stats {
    /// Catat satu frame terkirim. `latency_ms` = `None` untuk frame
    /// penyelamatan (IDR simpanan): ia tidak melewati pipeline capture, jadi
    /// memasukkan latensinya akan memalsukan ukuran pipeline host.
    fn catat(&mut self, control: &Mutex<ControlState>, latency_ms: Option<f64>) {
        self.fps_window += 1;
        let elapsed = self.fps_start.elapsed();
        if elapsed >= Duration::from_secs(1) {
            self.fps_now = self.fps_window as f64 / elapsed.as_secs_f64();
            self.fps_window = 0;
            self.fps_start = Instant::now();
        }
        let mut st = crate::recover_lock(control);
        match latency_ms {
            Some(ms) => st.video.record_frame(ms),
            None => st.video.frames_sent += 1,
        }
        st.video.fps = self.fps_now;
        st.video.nvenc = screen::nvenc_active();
        st.video.encoder = screen::encoder_label();
    }
}

/// Tulis satu frame H264 (Annex-B) ke track RTP.
///
/// Mengembalikan `false` bila track menolak tulisan — artinya sesi sudah tidak
/// bisa dipakai dan pemanggil harus berhenti.
async fn tulis_frame(track: &Arc<TrackLocalStaticSample>, data: Vec<u8>) -> bool {
    let sample = Sample {
        data: bytes::Bytes::from(data),
        timestamp: SystemTime::now(),
        duration: screen::frame_duration(),
        packet_timestamp: 0,
        prev_dropped_packets: 0,
        prev_padding_packets: 0,
    };
    if let Err(e) = track.write_sample(&sample).await {
        eprintln!("[xydesk-host] kirim frame gagal: {e}");
        return false;
    }
    true
}

/// Alirkan frame dari channel ke track RTP sampai channel tertutup atau
/// koneksi gagal/ditutup.
///
/// Kontrak "gambar pasti muncul di klien":
/// 1. Frame TIDAK ditulis sebelum transport `Connected`. Frame yang
///    ditulis lebih awal dibuang ICE/DTLS yang belum jadi — termasuk
///    IDR pertama yang membawa SPS/PPS. Tanpa SPS/PPS decoder klien
///    tidak pernah bisa memulai: layar hitam, sesi tampak "terhubung",
///    paket mengalir, `framesDecoded` = 0.
/// 2. Saat transisi ke `Connected`, encoder diminta menghasilkan keyframe
///    segar (`screen::request_keyframe`) — sumber frame merespons dengan
///    membangun ulang encoder sehingga frame berikutnya adalah IDR yang
///    membawa SPS/PPS, dan pasti melewati transport yang sudah siap.
/// 3. Permintaan pada (2) TIDAK CUKUP bila layar tidak berubah. Di Windows,
///    Graphics Capture hanya menyerahkan frame saat ada perubahan, dan
///    encoder hanya membangun ulang diri di antara dua frame — jadi pada
///    layar yang diam tidak ada frame yang bisa membawa IDR baru. Karena itu
///    host mengirim ulang IDR terakhir yang tersimpan (`screen::last_keyframe`)
///    sampai IDR hidup tiba atau [`KEYFRAME_RESCUE_WINDOW`] habis.
///
/// Regresi (3) nyata di lapangan 6 Sep 2026: log host menunjukkan
/// `Connected — keyframe segar diminta`, tidak ada satu pun frame sesudahnya,
/// klien menyerah, host melihat `disconnected`, slot dilepas setelah masa
/// tenggang — dan yang dilihat pengguna adalah layar hitam di web maupun
/// Flutter, pada PC yang layarnya sedang diam.
pub async fn pump_video(
    session: &Session,
    track: &Arc<TrackLocalStaticSample>,
    mut frames: tokio::sync::mpsc::Receiver<EncodedFrame>,
    control: Arc<Mutex<ControlState>>,
) {
    println!("[xydesk-host] track video siap — streaming");
    let mut prev_connected = false;
    let mut rescue: Option<Rescue> = None;
    let mut stats = Stats {
        fps_window: 0,
        fps_start: Instant::now(),
        fps_now: 0.0,
    };

    loop {
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
            // Transisi baru ke Connected: minta IDR segar (SPS/PPS + slice).
            screen::request_keyframe();
            println!("[xydesk-host] koneksi Connected — keyframe segar diminta");
            match screen::last_keyframe() {
                Some(data) => {
                    println!(
                        "[xydesk-host] IDR simpanan {} byte siap — dikirim ulang sampai IDR hidup tiba",
                        data.len()
                    );
                    let now = Instant::now();
                    rescue = Some(Rescue {
                        data,
                        next: now,
                        until: now + KEYFRAME_RESCUE_WINDOW,
                        sent: 0,
                    });
                }
                None => println!(
                    "[xydesk-host] belum ada IDR tersimpan (atau sudah basi) — menunggu frame hidup"
                ),
            }
        }
        prev_connected = connected;

        if !connected {
            // Transport belum siap: frame apa pun yang ditulis sekarang
            // (termasuk IDR+SPS/PPS) akan hilang di jaringan. Buang.
            rescue = None;
            if frames.recv().await.is_none() {
                break; // channel tutup — sesi selesai
            }
            continue;
        }

        // Connected. Bila penyelamatan aktif, jangan tidur tanpa batas: layar
        // yang diam tidak menghasilkan frame, dan decoder klien menunggu IDR.
        let diterima = match rescue
            .as_ref()
            .map(|r| r.next.saturating_duration_since(Instant::now()))
        {
            // `None` dari sini punya dua arti — jeda penyelamatan tiba, atau
            // channel tutup — dan dibedakan di bawah lewat `frames.is_closed()`.
            Some(wait) => tokio::time::timeout(wait, frames.recv())
                .await
                .unwrap_or_default(),
            None => frames.recv().await,
        };

        match diterima {
            Some(frame) => {
                // Latensi pipeline host: sejak frame ditangkap di thread
                // capture sampai sesaat sebelum ditulis ke track RTP.
                let latency_ms = frame.captured_at.elapsed().as_secs_f64() * 1000.0;
                let idr_hidup = screen::annexb_has_idr(&frame.data);
                if !tulis_frame(track, frame.data).await {
                    break;
                }
                stats.catat(&control, Some(latency_ms));
                if idr_hidup {
                    if rescue.is_some() {
                        println!("[xydesk-host] IDR hidup tiba — penyelamatan keyframe selesai");
                    }
                    rescue = None;
                }
            }
            None => {
                if frames.is_closed() {
                    break; // channel tutup — sesi selesai
                }
                let Some(r) = rescue.as_mut() else {
                    break; // tidak ada penyelamatan: tidak akan ada frame lagi
                };
                let now = Instant::now();
                if now >= r.until {
                    println!(
                        "[xydesk-host] IDR hidup tidak datang dalam {} detik — penyelamatan keyframe berhenti ({} pengiriman ulang)",
                        KEYFRAME_RESCUE_WINDOW.as_secs(),
                        r.sent
                    );
                    rescue = None;
                    continue;
                }
                r.next = now + KEYFRAME_RESCUE_INTERVAL;
                r.sent += 1;
                if !tulis_frame(track, r.data.clone()).await {
                    break;
                }
                stats.catat(&control, None);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn jeda_dan_jendela_penyelamatan_masuk_akal() {
        // Jendela harus jauh lebih panjang dari jeda, kalau tidak
        // penyelamatan hanya sempat mengirim satu-dua frame.
        assert!(KEYFRAME_RESCUE_WINDOW > KEYFRAME_RESCUE_INTERVAL * 4);
        // Jeda tidak boleh lebih ketat dari durasi satu frame nominal (60fps):
        // mengirim IDR lebih rapat dari itu hanya membakar jalur naik.
        assert!(KEYFRAME_RESCUE_INTERVAL >= screen::frame_duration());
    }

    #[test]
    fn frame_penyelamatan_tidak_memalsukan_latensi_pipeline() {
        // Kontrak Stats::catat: tanpa latensi, hitungan frame tetap naik
        // tetapi EMA latensi tidak disentuh (IDR simpanan tidak melewati
        // capture → encode).
        let control = Mutex::new(ControlState::new(
            "test-device".into(),
            "test".into(),
            "ws://127.0.0.1/test".into(),
        ));
        let mut stats = Stats {
            fps_window: 0,
            fps_start: Instant::now(),
            fps_now: 0.0,
        };
        stats.catat(&control, Some(12.0));
        {
            let st = crate::recover_lock(&control);
            assert_eq!(st.video.frames_sent, 1);
            assert!((st.video.latency_ms - 12.0).abs() < f64::EPSILON);
        }
        stats.catat(&control, None);
        {
            let st = crate::recover_lock(&control);
            assert_eq!(st.video.frames_sent, 2, "frame penyelamatan tetap terkirim");
            assert!(
                (st.video.latency_ms - 12.0).abs() < f64::EPSILON,
                "latensi pipeline tidak boleh diubah frame penyelamatan"
            );
        }
    }
}
