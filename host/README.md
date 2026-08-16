# XyDesk Host (Rust)

Aplikasi sisi PC yang ditanam di komputer yang dikendalikan. Menangkap layar,
meng-encode, dan mengirim via WebRTC ke client.

## Status (jujur)

| Bagian | Status |
|---|---|
| Signaling client (daftar, pair, negosiasi) | ✅ jadi, lintas platform |
| Sesi WebRTC (answerer) + data channel "input" | ✅ jadi + teruji (`tests/e2e.rs`) |
| **Media plane: track video H264 + encode → RTP → decode** | ✅ **jadi + teruji** (openh264, pola uji) |
| Sumber video: capture layar (DXGI) + encode (NVENC) | ⏳ Windows-only, belum diimplementasi |

Artinya: jalur media **sudah terbukti end-to-end** — host meng-encode frame
(openh264) → kirim lewat RTP → client menerima & men-decode. Yang tersisa
hanya menukar sumber frame dari pola uji ke **capture layar DXGI + NVENC**
di Windows (GPU). Alur kode sudah disiapkan agar penggantian sumber itu
cukup menukar implementasi `encode_next()`.

## Bangun & uji

```bash
cargo build              # compile (lintas platform)
cargo test               # e2e: dua peer WebRTC + data channel (loopback)
```

## Jalankan

```bash
cargo run -- \
  --url wss://signal.xystudio.my.id/ws \
  --id gaming-pc-01 \
  --token <TOKEN>        # dari /issue
```

## Rencana implementasi sumber video (Windows)

1. **Capture** — `windows-capture` crate (DXGI Desktop Duplication),
   `AcquireNextFrame` di thread terpisah, budget ≤ 8 ms/frame.
2. **Encode** — jalur cepat PoC: FFmpeg (`ffmpeg-next`) `h264_nvenc -preset p1 -tune ll`;
   produksi: NVIDIA Video Codec SDK (zero-copy CUDA→NVENC).
3. **Kirim** — dorong frame ter-encode ke `TrackLocalStaticSample`
   (SampleBuilder → WriteSample → RTP) di `src/session.rs`.

> Cross-compile dari Linux **tidak** didukung untuk bagian capture (butuh
> Win32). Uji langsung di Windows.

## Struktur

```
host/
├── Cargo.toml
├── src/
│   ├── lib.rs       # pub mod session; pub mod screen;
│   ├── main.rs      # CLI + signaling client + wiring sesi
│   ├── session.rs   # WebRTC answerer + data channel input (teruji)
│   └── screen.rs    # sumber video (Windows DXGI — TODO)
└── tests/
    └── e2e.rs       # dua peer WebRTC loopback — membuktikan jalur WebRTC
```
