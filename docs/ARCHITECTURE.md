# Arsitektur XyDesk

```
┌─────────────────────────────┐          ┌─────────────────────────────┐
│  HOST  (PC yang dikontrol)   │          │  CLIENT (Flutter app)       │
│  Rust + Tauri (Windows)      │          │  Android / iOS / Desktop    │
│                              │          │                              │
│  DXGI Desktop Duplication    │          │  RTCVideoView (render)       │
│        │ (capture)           │          │        ▲                     │
│        ▼                     │          │        │ decode (hardware)    │
│  NVENC/AMF/QuickSync (encode)│          │        │                     │
│        │                     │          │  flutter_webrtc              │
│        ▼                     │          │        ▲                     │
│  webrtc-rs (str0m)           │          │  input (mouse/kb) → datachan │
│        │                     │          │                              │
└────────┼─────────────────────┘          └────────┼─────────────────────┘
         │                                         │
         │          WebRTC (DTLS-SRTP)             │
         │        media + data channel             │
         │          END-TO-END                     │
         │                                         │
         ▼                                         ▼
   ┌───────────────────────────────────────────────────┐
   │  SIGNALING — hanya SDP/ICE, bukan media           │
   │  Cloudflare Worker + Durable Object (serverless)  │
   │  gratis, tanpa VM/VPS, tanpa kartu kredit          │
   └───────────────────────────────────────────────────┘
              │                    │
              ▼                    ▼
         STUN (Cloudflare)   TURN (Cloudflare, 1TB/bln gratis)
         NAT discovery       relay bila direct gagal
```

## Kenapa pemisahan ini

1. **Server tak bisa menyadap layar** — media end-to-end. Ini bukan sekadar
   performa, ini kepercayaan pengguna.
2. **Server ringan** — muat di Cloudflare Workers free tier; biaya nol selamanya.
3. **Protokol stabil** — penggantian backend (NATS/Redis) tak mengubah client.

## Kenapa host pakai Rust

- **Desktop Duplication API (DXGI)** butuh akses Win32 yang cepat & aman;
  Rust memberi kontrol penuh tanpa GC pause yang bikin frame jitter.
- **webrtc-rs / str0m** matang dan MIT/Apache (gratis, tanpa batas).
- Tauri memungkinkan UI host + tray + auto-update dengan footprint kecil.
  (Tapi untuk PoC, **jangan bangun UI dulu** — cukup CLI yang capture+kirim.)

## Alur data host (path panas)

```
DXGI AcquireNextFrame (8ms budget)      // d3d11 texture
   → copy ke NVENC input (cudaMemcpy)   // zero-copy bila mungkin
   → NVENC encode (H264/HEVC/AV1)       // <10ms @1080p60
   → frame ke webrtc-rs (RTP)           // pacing + NACK + FEC
   → kirim
```

Rule of thumb: **total waktu di path panas harus < 25 ms** untuk menyisakan
jaringan + decode di bawah 40 ms glass-to-glass.

## Alur input (path balik, latency juga penting)

```
client pointer/keys → data channel (reliable, ordered)
   → host inject (SendInput / raw input)   // < 5 ms
```

Input pakai data channel yang **reliable** (bukan RTP), karena kehilangan satu
event klik/tekan keyboard tidak boleh terjadi.

## Keputusan yang masih terbuka (tulis di sini, jangan di kepala)

- Codec default: H264 (kompatibilitas luas) vs AV1 (bandwidth hemat, decoder
  lebih berat di HP murah). → **uji dua-duanya di PoC, ambil yang tembus target.**
- Transport input: data channel vs UDP khusus (seperti Parsec). → data channel
  dulu untuk PoC; optimasi belakangan bila jitter input terukur tinggi.

## Struktur repo yang diusulkan (tambahan ke repo XyDesk)

```
XyDesk/
├── signaling/      # Go (REPO INI SUDAH BERISI — copy ke repo GitHub-mu)
├── host/           # Rust + Tauri (scaffolding ada di sini)
├── lib/            # Flutter client (yang sudah ada) + client/webrtc drop-in
└── docs/           # PROTOCOL.md, ARCHITECTURE.md, FREE-STACK.md
```
