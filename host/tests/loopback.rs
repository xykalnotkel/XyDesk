//! Loopback end-to-end: client (offerer) ↔ host (answerer) yang DIPAKAI
//! PRODUKSI (`xydesk_host::session::Session`).
//!
//! Test ini adalah regresi untuk DUA bug nyata:
//!   A. `add_video_track` dulu dipanggil SETELAH `create_answer`, sehingga
//!      SDP jawaban tidak memuat m-line video — koneksi tampak sukses tapi
//!      client tidak pernah menerima satu frame pun.
//!   B. (3 Sep 2026) Frame IDR pertama yang membawa SPS/PPS ditulis sebelum
//!      transport WebRTC `Connected`, sehingga dibuang jaringan; klien
//!      menerima banyak paket P-frame tapi decoder tidak pernah bisa
//!      memulai (`framesDecoded` = 0, layar hitam).
//!
//! Yang diuji di sini persis alur produksi:
//!   1. client: transceiver video recvonly + data channel "input" + offer
//!   2. host: `Session::answer` → SDP jawaban HARUS berisi `m=video`
//!   3. host: `screen::spawn_frame_source` (pola uji → H264) + `video::pump_video`
//!      (kode produksi yang sama dengan `main.rs`) → track RTP
//!   4. client menerima paket RTP video — DAN minimal satu NAL SPS/PPS
//!      (tanpa itu, decoder klien tidak pernah bisa mendecode: layar hitam)
//!   5. data channel "input" dua arah: PING host ← client, PONG balik

use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::Context;
use tokio::sync::mpsc;
use webrtc::api::interceptor_registry::register_default_interceptors;
use webrtc::api::media_engine::MediaEngine;
use webrtc::api::APIBuilder;
use webrtc::interceptor::registry::Registry;
use webrtc::peer_connection::configuration::RTCConfiguration;
use webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState;
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;
use webrtc::rtp_transceiver::rtp_codec::RTPCodecType;
use webrtc::rtp_transceiver::rtp_transceiver_direction::RTCRtpTransceiverDirection;
use webrtc::rtp_transceiver::RTCRtpTransceiverInit;

use xydesk_host::control::ControlState;
use xydesk_host::screen::{self, EncodedFrame};
use xydesk_host::session::Session;

const MIN_PACKETS: usize = 10;

/// Bangun API WebRTC klien (persis pola `Session::new` di sisi host).
fn client_api() -> anyhow::Result<webrtc::api::API> {
    let mut media = MediaEngine::default();
    media
        .register_default_codecs()
        .context("gagal daftar codec default")?;
    let mut registry = Registry::new();
    registry = register_default_interceptors(registry, &mut media).context("interceptor gagal")?;
    Ok(APIBuilder::new()
        .with_media_engine(media)
        .with_interceptor_registry(registry)
        .build())
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn loopback_video_flows_and_input_roundtrips() -> anyhow::Result<()> {
    // ── Client (offerer) ────────────────────────────────────────────────
    let api = client_api()?;
    let pc = Arc::new(
        api.new_peer_connection(RTCConfiguration::default())
            .await
            .context("client pc gagal")?,
    );

    // Video recvonly + data channel "input" — persis alur produksi.
    pc.add_transceiver_from_kind(
        RTPCodecType::Video,
        Some(RTCRtpTransceiverInit {
            direction: RTCRtpTransceiverDirection::Recvonly,
            send_encodings: vec![],
        }),
    )
    .await
    .context("transceiver video gagal")?;
    let dc = pc
        .create_data_channel("input", None)
        .await
        .context("data channel gagal")?;

    // Hitung paket RTP video yang diterima + cek SPS benar-benar tiba.
    // Regresi bug B: test lama hanya menghitung paket dan tetap hijau
    // padahal klien tidak pernah bisa mendecode satu frame pun.
    let (packets_tx, mut packets_rx) = mpsc::unbounded_channel::<usize>();
    let sps_seen = Arc::new(std::sync::atomic::AtomicBool::new(false));
    let sps_seen_in_track = sps_seen.clone();
    pc.on_track(Box::new(move |track, _receiver, _transceiver| {
        let packets_tx = packets_tx.clone();
        let sps_seen = sps_seen_in_track.clone();
        Box::pin(async move {
            let mut n = 0usize;
            while let Ok((pkt, _attrs)) = track.read_rtp().await {
                // Payload RTP H264 (packetization-mode=1):
                //  - NAL tunggal: byte pertama = header NAL.
                //  - STAP-A (24): agregasi [2-byte ukuran][NAL]...
                //    — payloader webrtc-rs menggabung SPS+PPS ke satu paket
                //      STAP-A, jadi mengecek NAL 7/8 di byte pertama SAJA
                //      tidak akan pernah melihat parameter set.
                //  - FU-A (28): fragmentasi, lihat byte kedua (tipe asli).
                let pl = &pkt.payload;
                let mut param = false;
                if let Some(&first) = pl.first() {
                    let nal = first & 0x1F;
                    if nal == 7 || nal == 8 {
                        param = true;
                    } else if nal == 24 {
                        // STAP-A: lewati header, urai unit-unit di dalamnya.
                        let mut pos = 1usize;
                        while pos + 3 <= pl.len() {
                            let sz = ((pl[pos] as usize) << 8) | pl[pos + 1] as usize;
                            if pos + 2 + sz > pl.len() || sz == 0 {
                                break;
                            }
                            let inner = pl[pos + 2] & 0x1F;
                            if inner == 7 || inner == 8 {
                                param = true;
                            }
                            pos += 2 + sz;
                        }
                    } else if nal == 28 && pl.len() >= 2 {
                        let inner = (pl[1] & 0x1E) >> 1;
                        if inner == 7 || inner == 8 {
                            param = true;
                        }
                    }
                    if n < 6 {
                        eprintln!(
                            "[loopback] RTP#{} nal={} len={} marker={} param={param}",
                            n,
                            nal,
                            pl.len(),
                            pkt.header.marker
                        );
                    }
                    n += 1;
                    if param {
                        sps_seen.store(true, std::sync::atomic::Ordering::Relaxed);
                    }
                }
                if packets_tx.send(1).is_err() {
                    break;
                }
            }
        })
    }));

    // Balasan host (PONG) diterima lewat data channel yang sama.
    let (dc_rx_tx, mut dc_rx) = mpsc::unbounded_channel::<Vec<u8>>();
    dc.on_message(Box::new(move |m| {
        if !m.is_string {
            let _ = dc_rx_tx.send(m.data.to_vec());
        }
        Box::pin(async {})
    }));

    // Tanda koneksi terhubung — setelah ini client boleh minta PING.
    // Notify dipakai (bukan oneshot) karena handler dipanggil berulang kali.
    let connected = Arc::new(tokio::sync::Notify::new());
    let connected_for_handler = connected.clone();
    pc.on_peer_connection_state_change(Box::new(move |state| {
        if state == RTCPeerConnectionState::Connected {
            connected_for_handler.notify_waiters();
        }
        Box::pin(async {})
    }));

    // Tanda data channel client sudah OPEN — kirim PING hanya setelah ini
    // (kalau PING diirim sebelum channel siap, host bisa kehilangannya).
    let dc_open = Arc::new(tokio::sync::Notify::new());
    {
        let dc_open = dc_open.clone();
        dc.on_open(Box::new(move || {
            dc_open.notify_waiters();
            Box::pin(async {})
        }));
    }

    // Client: tunggu Connected + dc OPEN → kirim PING. Task ini DISPAWN
    // SEBELUM negosiasi dimulai supaya waiter pasti terdaftar lebih dulu.
    let ping_task = tokio::spawn(async move {
        let wait = async {
            let _ = tokio::time::timeout(Duration::from_secs(25), connected.notified()).await;
            let _ = tokio::time::timeout(Duration::from_secs(25), dc_open.notified()).await;
        };
        match tokio::time::timeout(Duration::from_secs(30), wait).await {
            Ok(()) => {
                // Jeda kecil: beri host waktu memasang handler on_message
                // (dalam produksi, input manusia selalu datang belakangan,
                // jadi ini artifact test, bukan alur produksi).
                tokio::time::sleep(Duration::from_millis(500)).await;
                for _ in 0..3 {
                    println!("[loopback] client: kirim PING");
                    dc.send(&bytes::Bytes::from_static(b"PING"))
                        .await
                        .context("kirim PING gagal")?;
                    tokio::time::sleep(Duration::from_millis(300)).await;
                }
            }
            Err(_) => anyhow::bail!("koneksi/data channel tidak pernah siap dalam 30 detik"),
        }
        Ok::<(), anyhow::Error>(())
    });

    // Offer (non-trickle: tunggu gathering selesai, kandidat ikut di SDP).
    let offer = pc.create_offer(None).await.context("create_offer gagal")?;
    pc.set_local_description(offer)
        .await
        .context("set_local_description gagal")?;
    let mut gather = pc.gathering_complete_promise().await;
    let _ = gather.recv().await;
    let offer_sdp = pc
        .local_description()
        .await
        .ok_or_else(|| anyhow::anyhow!("offer tanpa local description"))?
        .sdp;

    // ── Host (answerer): KODE PRODUKSI NYATA ───────────────────────────
    let host = Arc::new(Session::new(vec![], vec![]).await?);
    let (answer_sdp, track) = host.answer(&offer_sdp).await?;

    // Bug guard A: jawaban WAJIB memuat m-line video.
    assert!(
        answer_sdp.contains("m=video"),
        "SDP jawaban TIDAK memuat m-line video — track didaftarkan setelah \
         answer. Client tidak akan pernah menerima gambar.\n--- jawaban ---\n{answer_sdp}"
    );

    pc.set_remote_description(RTCSessionDescription::answer(answer_sdp)?)
        .await
        .context("client set answer gagal")?;

    // ── Streamer host: jalur produksi PENUH ────────────────────────────
    // spawn_frame_source (pola uji → encoder H264) + video::pump_video
    // (gate Connected + keyframe segar) → track RTP. Dulu test ini
    // menulis frame sendiri dengan TestPatternEncoder — kebal terhadap
    // bug B karena tidak pernah meniru gate + keyframe produksi.
    let streamer = {
        let host = host.clone();
        let track = track.clone();
        tokio::spawn(async move {
            let frames = screen::spawn_frame_source();
            let (vtx, vrx) = tokio::sync::mpsc::channel::<EncodedFrame>(1);
            std::thread::spawn(move || {
                while let Ok(frame) = frames.recv() {
                    if vtx.blocking_send(frame).is_err() {
                        break;
                    }
                }
            });
            let control = Arc::new(Mutex::new(ControlState::new(
                "test-device".into(),
                "test".into(),
                "ws://127.0.0.1/test".into(),
            )));
            xydesk_host::video::pump_video(&host, &track, vrx, control).await;
            Ok::<(), anyhow::Error>(())
        })
    };

    // ── Input: host menerima PING lalu membalas PONG ───────────────────
    let host_input = {
        let host = host.clone();
        tokio::spawn(async move {
            let dc = host
                .receive_input_channel()
                .await
                .context("data channel input tidak datang")?;
            println!("[loopback] host: data channel '{}' terbuka", dc.label());
            let (tx, mut rx) = mpsc::unbounded_channel::<Vec<u8>>();
            dc.on_message(Box::new(move |m| {
                if !m.is_string {
                    let _ = tx.send(m.data.to_vec());
                }
                Box::pin(async {})
            }));
            match rx.recv().await {
                Some(data) => {
                    println!("[loopback] host terima data channel: {data:?}");
                    host.send(&dc, b"PONG".to_vec()).await?;
                    println!("[loopback] host balas PONG");
                }
                None => anyhow::bail!("data channel ditutup sebelum kirim PING"),
            }
            Ok::<(), anyhow::Error>(())
        })
    };

    // ── Assertions ─────────────────────────────────────────────────────
    let packets = tokio::time::timeout(Duration::from_secs(20), async {
        let mut total = 0usize;
        while let Some(n) = packets_rx.recv().await {
            total += n;
            if total >= MIN_PACKETS {
                break;
            }
        }
        total
    })
    .await
    .unwrap_or(0);

    let pong = tokio::time::timeout(Duration::from_secs(15), dc_rx.recv())
        .await
        .ok()
        .flatten();

    assert!(
        packets >= MIN_PACKETS,
        "client hanya menerima {packets} paket video — loop video tidak jalan"
    );
    let sps = sps_seen.load(std::sync::atomic::Ordering::Relaxed);
    assert!(
        sps,
        "client TIDAK menerima SPS/PPS sama sekali — decoder tidak pernah bisa \
         memulai (layar hitam). Frame IDR pertama kemungkinan ditulis sebelum \
         transport Connected lalu dibuang jaringan. Video::pump_video harus \
         gate ke Connected + minta keyframe segar."
    );
    assert_eq!(
        pong.as_deref(),
        Some(b"PONG".as_slice()),
        "host tidak membalas PING lewat data channel"
    );
    println!(
        "[loopback] OK: {packets} paket video (dengan SPS/PPS) + PING/PONG dua arah — \
         jalur produksi capture→encode→RTP→client terbukti"
    );

    // Bersih-bersih. Pump produksi berjalan tanpa batas (seperti di
    // main.rs) — buang task-nya; runtime tokio menyapu sisanya.
    ping_task.await??;
    host_input.await??;
    streamer.abort();
    Ok(())
}
