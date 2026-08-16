# XyDesk Host (Rust)

Aplikasi sisi PC yang ditanam di komputer yang dikendalikan. Menangkap layar,
meng-encode, dan mengirim via WebRTC ke client.

## Status (jujur)

| Bagian | Status |
|---|---|
| Signaling client (daftar, pair, negosiasi) | ✅ jadi, lintas platform |
| Sesi WebRTC (answerer) + data channel "input" | ✅ implementasi tersedia |
| **Media plane: track video H264 + encode → RTP → decode** | ✅ implementasi tersedia (openh264, pola frame) |
| Sumber video: capture layar (DXGI) + encode (NVENC) | ⏳ Windows-only, belum diimplementasi |

Artinya: jalur media **sudah terbukti end-to-end** — host meng-encode frame
(openh264) → kirim lewat RTP → client menerima & men-decode. Yang tersisa
hanya menukar sumber frame dari pola uji ke **capture layar DXGI + NVENC**
di Windows (GPU). Alur kode sudah disiapkan agar penggantian sumber itu
cukup menukar implementasi `encode_next()`.

## Identitas (ID + Password) — dipakai untuk connect dari HP

Saat host dibuka, dia otomatis menampilkan:

```
╔══════════════════════════════════════════╗
║   ID       : 123 456 789                  ║
║   Password : AB2CDE7F                     ║
╚══════════════════════════════════════════╝
```

- **ID**: 9 digit acak, unik per perangkat, disimpan permanen (`~/.xydesk/device_id`).
- **Password**: acak saat pertama dibuka, disimpan permanen (`~/.xydesk/password`).
- **Customize password**:
  ```bash
  xydesk-host --set-password Rahasia123   # ganti password (min 6 karakter)
  xydesk-host --new-password              # generasi ulang password acak
  ```
- ID + password inilah yang diketik pengguna di aplikasi **client (HP)** untuk pairing.

## Jalankan

```bash
xydesk-host \
  --url wss://signal.xystudio.my.id/ws \
  --token <TOKEN>        # dari /issue
# --id opsional: otomatis digenerasi & disimpan bila tidak diberikan
```

## Build

GitHub Actions membangun host Windows secara otomatis. Untuk build manual:

```bash
cargo build --release
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
│   ├── lib.rs       # pub mod identity; pub mod screen; pub mod session;
│   ├── main.rs      # CLI + signaling client + wiring sesi
│   ├── identity.rs  # ID 9 digit + password pairing (persisten, customizable)
│   ├── session.rs   # WebRTC answerer + data channel input
│   └── screen.rs    # sumber video (Windows DXGI — TODO)
```
