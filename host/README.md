# XyDesk Host (Rust)

Aplikasi sisi PC yang ditanam di komputer yang dikendalikan. Menangkap layar,
meng-encode, dan mengirim via WebRTC ke client.

## Status (jujur)

| Bagian | Status |
|---|---|
| Signaling client (daftar, pair, negosiasi) | ✅ jadi, lintas platform |
| Sesi WebRTC (answerer) + data channel "input" | ✅ implementasi tersedia |
| **Media plane: track video H264 + encode → RTP → decode** | ✅ implementasi tersedia (openh264, pola frame) |
| Sumber video: capture layar (DXGI) + encode (NVENC) | ✅ implementasi tersedia (`screen.rs` + `nvenc.rs`); ⏳ belum diverifikasi di lab Windows |

Artinya: jalur media **sudah terbukti end-to-end** — host meng-encode frame
(openh264) → kirim lewat RTP → client menerima & men-decode. Di Windows,
`screen.rs` menangkap layar via DXGI Desktop Duplication (`windows-capture`)
lalu meng-encode dengan **NVENC** bila GPU NVIDIA tersedia, dan jatuh ke
openh264 (software) bila tidak. Yang belum dilakukan: verifikasi di lab
Windows nyata (runner CI tanpa GPU — lihat `test-lab.yml`) dan jalur
zero-copy NVENC (ID3D11Texture2D → NVENC tanpa bolak-balik CPU).

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

## Sumber video (Windows) — cara kerjanya

1. **Capture** — `screen.rs` memakai crate `windows-capture` (DXGI Desktop
   Duplication / Graphics Capture API) di thread terpisah,
   `ColorFormat::Rgba8`.
2. **Encode** — `nvenc.rs` memanggil `nvEncodeAPI64.dll` langsung (NVIDIA
   Video Codec SDK 12.2, dimuat dinamis): H264 baseline CBR low-latency.
   Bila GPU NVIDIA / driver R550+ tidak ada, otomatis jatuh ke openh264
   (software) — sesi tidak mati.
3. **Kirim** — frame ter-encode didorong ke track video lewat
   `track.write_sample` di `src/session.rs`; channel frame berukuran kecil
   agar frame usang dibuang (latency diutamakan dari kelengkapan).

> NVENC zero-copy (ID3D11Texture2D → NVENC tanpa salin CPU) masih TODO —
> hari ini jalurnya CPU RGBA→NV12 (`pixfmt.rs`) → texture D3D11.
> Cross-compile dari Linux **tidak** didukung untuk bagian capture (butuh
> Win32). Verifikasi di lab Windows lewat workflow `test-lab.yml`.

## Struktur

```
host/
├── Cargo.toml
├── src/
│   ├── lib.rs       # pub mod identity; pub mod pixfmt; pub mod screen; ...
│   ├── main.rs      # CLI + signaling client + wiring sesi
│   ├── identity.rs  # ID 9 digit + password pairing (persisten, customizable)
│   ├── session.rs   # WebRTC answerer + data channel input
│   ├── screen.rs    # sumber video: DXGI capture (Windows) + pola uji (fallback)
│   ├── nvenc.rs     # encoder H264 hardware NVIDIA (dinamis, Windows-only)
│   └── pixfmt.rs    # RGBA → NV12 (lintas platform, teruji)
```
