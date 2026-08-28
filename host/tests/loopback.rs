//! Loopback end-to-end: client (offerer) ↔ host (answerer) yang DIPAKAI
//! PRODUKSI (`xydesk_host::session::Session`).
//!
//! Test ini adalah regresi untuk bug nyata: `add_video_track` dulu dipanggil
//! SETELAH `create_answer`, sehingga SDP jawaban tidak memuat m-line video —
//! koneksi tampak sukses tapi client tidak pernah menerima satu frame pun.
//! Yang diuji di sini persis alur produksi:
//!   1. client: transceiver video recvonly + data channel "input" + offer
//!   2. host: `Session::answer` → SDP jawaban HARUS berisi `m=video`
//!   3. host menulis frame (TestPatternEncoder) ke track yang dikembalikan
//!   4. client menerima paket RTP video via `on_track`
//!   5. data channel "input" dua arah: PING host ← client, PONG balik

use std::sync::Arc;
use std::time::{Duration, Instant};

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

use xydesk_host::screen::TestPatternEncoder;
use xydesk_host::session::Session;

const TEST_W: usize = 320;
const TEST_H: usize = 180;
const FRAMES_TO_WRITE: u64 = 60;
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

    // Hitung paket RTP video yang diterima.
    let (packets_tx, mut packets_rx) = mpsc::unbounded_channel::<usize>();
    pc.on_track(Box::new(move |track, _receiver, _transceiver| {
        let packets_tx = packets_tx.clone();
        Box::pin(async move {
            while let Ok((_pkt, _attrs)) = track.read_rtp().await {
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

    // ── Host: KODE PRODUKSI NYATA ──────────────────────────────────────
    let host = Arc::new(Session::new(vec![], vec![]).await?);
    let (answer_sdp, track) = host.answer(&offer_sdp).await?;

    // Bug guard: jawaban WAJIB memuat m-line video.
    assert!(
        answer_sdp.contains("m=video"),
        "SDP jawaban TIDAK memuat m-line video — track didaftarkan setelah \
         answer. Client tidak akan pernah menerima gambar.\n--- jawaban ---\n{answer_sdp}"
    );

    pc.set_remote_description(RTCSessionDescription::answer(answer_sdp)?)
        .await
        .context("client set answer gagal")?;

    // ── Streamer host: pola uji → track video ─────────────────────────
    let streamer = tokio::spawn(async move {
        let mut enc = TestPatternEncoder::new()?;
        let mut encode_total_us = 0u128;
        let mut encode_samples = 0u128;
        let start = Instant::now();
        for i in 0..FRAMES_TO_WRITE {
            let t0 = Instant::now();
            let data = enc.encode_next(TEST_W, TEST_H)?;
            encode_total_us += t0.elapsed().as_micros();
            encode_samples += 1;
            let sample = webrtc::media::Sample {
                data: bytes::Bytes::from(data),
                timestamp: std::time::SystemTime::now(),
                duration: Duration::from_millis(33),
                packet_timestamp: 0,
                prev_dropped_packets: 0,
                prev_padding_packets: 0,
            };
            if let Err(e) = track.write_sample(&sample).await {
                eprintln!("[loopback] write_sample gagal: {e}");
                break;
            }
            tokio::time::sleep(Duration::from_millis(20)).await;
            let _ = i;
        }
        let elapsed = start.elapsed().as_secs_f64();
        let avg = encode_total_us as f64 / encode_samples as f64 / 1000.0;
        println!(
            "[loopback] encode: rata-rata {avg:.2} ms/frame ({} frame, {:.1} fps)",
            FRAMES_TO_WRITE,
            FRAMES_TO_WRITE as f64 / elapsed
        );
        Ok::<(), anyhow::Error>(())
    });

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
    assert_eq!(
        pong.as_deref(),
        Some(b"PONG".as_slice()),
        "host tidak membalas PING lewat data channel"
    );
    println!(
        "[loopback] OK: {packets} paket video + PING/PONG dua arah — loop capture→RTP→client terbukti"
    );

    // Bersih-bersih.
    ping_task.await??;
    host_input.await??;
    streamer.await.context("task streamer panik")??;
    pc.close().await.context("close client gagal")?;
    host.close().await.context("close host gagal")?;
    Ok(())
}
