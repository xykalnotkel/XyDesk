# XyDesk Host (Rust) — scaffolding

Aplikasi sisi PC yang ditanam di komputer yang dikendalikan. Menangkap layar,
meng-encode, dan mengirim via WebRTC ke client.

> **Status: scaffolding.** `src/main.rs` (signaling client) adalah kode nyata
> lintas-platform yang bisa jalan dan diuji. `src/screen.rs` adalah kerangka
> capture/encode Windows yang harus diisi — **belum diimplementasi**. Ini
> sengaja: jangan percaya klaim "siap pakai" sampai diuji di Windows sungguhan.

## Target (harus dibuktikan)

- 1080p60, encode < 10 ms (NVENC/AMF/QuickSync), glass-to-glass < 40 ms LAN.

## Rencana implementasi (urutan)

### 1. Signaling client (✅ kerangka ada di `main.rs`)
Hubungkan ke server Go, daftar sebagai `role=host`, terima `pair`, jawab, lalu
negosiasi SDP/ICE. Pakai `tokio-tungstenite` + `serde`.

### 2. Capture layar — Desktop Duplication API
Crate yang direkomendasikan: **`windows-capture`** (DXGI Desktop Duplication,
aktif-maintained, contoh lengkap). Alternatif: `d3d11` + `dxgi` langsung.
- `AcquireNextFrame` di thread terpisah, budget ≤ 8 ms per frame.
- Dapatkan texture `ID3D11Texture2D`, teruskan ke encoder **tanpa** copy ke CPU.

### 3. Encode — NVENC (lalu AMF, QuickSync)
Dua jalur:
- **Cepat untuk PoC:** FFmpeg via `ffmpeg-next` (flag `-c:v h264_nvenc`,
  `-preset p1 -tune ll`). Satu malam kerja, hasil terukur.
- **Produksi:** NVIDIA Video Codec SDK via binding, atau `nv-codec-rs`.
  Zero-copy CUDA → NVENC → webrtc.

Ukur dulu dengan FFmpeg; optimasi SDK belakangan.

### 4. WebRTC — webrtc-rs
`webrtc-rs` punya track video + data channel lengkap. Alur:
`encode → SampleBuilder → VideoTrack.WriteSample → RTP`.

### 5. Input balik — data channel (reliable)
`SendInput` / raw input untuk mouse & keyboard dari client. Latency < 5 ms.

## Bangun

```bash
# di Windows (perlu: Rust + Visual Studio Build Tools + driver GPU)
cargo build --release
```

Cross-compile dari Linux **tidak** didukung untuk bagian capture (butuh Win32).
Uji di Windows langsung.

## Struktur

```
host/
├── Cargo.toml
└── src/
    ├── main.rs      # CLI + signaling client (lintas platform, nyata)
    └── screen.rs    # capture + encode (Windows, kerangka TODO)
```
