# XyDesk — Roadmap Teknis (Brain Developer)

> Dokumen ini adalah **sumber kebenaran tunggal** untuk arah teknis XyDesk.
> Aturan #1: **bukti dulu, baru poles.** Aturan #2: **semua gratis, tanpa
> kartu kredit** — self-host di tier gratis, tanpa API berbayar.

---

## Kenyataan yang harus diterima sekarang

XyDesk hari ini adalah **UI kerangka yang sangat rapi**, tapi belum punya
loop inti: `capture → encode → kirim → decode`. Semua nilai produk terletak
di loop itu. Sampai loop itu jalan dan **latency-nya terukur di bawah target**,
setiap jam yang dipakai untuk memoles UI adalah taruhan.

Target yang harus dibuktikan (dari README-mu sendiri):

| Metrik | Target | Cara ukur |
|---|---|---|
| Glass-to-glass latency | **< 40 ms** LAN | timestamp frame di host → dibanding di client |
| Encode | < 10 ms @1080p60 | NVENC/AMF/QuickSync, bukan x264 |
| Decode | < 8 ms | hardware decoder di client |
| Jitter | < 5 ms | stats WebRTC (`getStats`) |

Kalau PoC gagal tembus target di jaringan nyata (Wi-Fi rumah, bukan LAN kabel
lab), posisi "cocok untuk gaming" **harus dievaluasi ulang** — jangan diteruskan
demi gengsi.

---

## Fase

### Fase 0 — PoC streaming (PRIORITAS, kerjakan SEKARANG)
**Tujuan:** buktikan loop inti jalan end-to-end dan ukur latency-nya.

1. **Host (Rust + Tauri)**: capture layar via Desktop Duplication API (DXGI),
   encode NVENC, kirim via WebRTC. Lihat `host/`.
2. **Client (Flutter)**: terima via `flutter_webrtc`, render ke `RTCVideoView`,
   kirim input (mouse/keyboard) balik lewat data channel. Lihat `client/`.
3. **Signaling**: sudah DIBANGUN di `signaling/` (Go, self-host, gratis).
4. **Uji latency** dengan overlay timestamp di layar (cara paling jujur: foto
   layar host + layar client berjejer, baca selisih jam di frame).

**Kriteria lulus (go/no-go):** 1080p60, < 40 ms di LAN, < 80 ms via internet
dengan TURN, stabil 30 menit tanpa re-buffer.

### Fase 1 — Hardening & keamanan
- Auth asli (Firebase Spark / Supabase free / tetap self-host HMAC) menggantikan
  "Google tiruan".
- Pairing PIN diverifikasi host-side (sudah didesain di protokol `pair`).
- TURN self-host (coturn) untuk NAT traversal — hanya ~15-20% koneksi butuh ini.
- Clipboard/mic passthrough: **consent per-sesi eksplisit**, bukan toggle global.

### Fase 2 — Fitur yang membedakan
- Control mapping editor (profil JSON) — kerangka UI-nya sudah ada.
- Multi-monitor, per-monitor streaming.
- Audio forward (host → client) + mic passthrough.
- Gamepad passthrough.

### Fase 3 — Distribusi & scale
- Host app installer (Tauri bundler / WiX) dengan auto-update.
- Android release di Play Store / side-load; Windows signed EXE.
- Signaling multi-node (NATS/Redis pub-sub) kalau user base tumbuh — protokol
  sudah tidak berubah, ganti `Hub.clients` saja.

---

## Stack gratis — TANPA VM/VPS (verifikasi ulang tiap fase)

| Komponen | Pilihan | Biaya |
|---|---|---|
| Signaling | **Cloudflare Worker + Durable Object** (`cloudflare/`, sudah jadi) | Rp 0 |
| STUN | `stun.cloudflare.com` (publik) | Rp 0 tanpa batas |
| TURN | `turn.cloudflare.com` | 1.000 GB/bln gratis |
| TLS | otomatis (custom domain signal.xystudio.my.id) | Rp 0 |
| Auth | Firebase **Spark** / Supabase free / HMAC self-host | Rp 0 |
| Encode | NVENC/AMF/QuickSync (GPU onboard) | Rp 0 |
| Libraries | flutter_webrtc, webrtc-rs, str0m — MIT/Apache | Rp 0 |

**Tidak ada** VM/VPS, tidak ada API berbayar, tidak ada kartu kredit.
Versi Go (`signaling/`) tetap ada sebagai opsi self-host LAN, tetapi produksi
memakai Cloudflare (serverless).

---

## Definisi selesai per fase (untuk mencegah "sudah 90% selamanya")

Setiap fase punya artefak yang bisa diverifikasi orang lain, bukan perasaan:
- Fase 0 → angka latency terukur di tabel di atas + video demo 30 detik.
- Fase 1 → audit keamanan singkat (pen-test basic: bisakah MITM melihat layar?).
- Fase 2 → user bisa remap kontrol tanpa rebuild.
- Fase 3 → installer jalan di PC fresh tanpa dev environment.

---

## PR berikutnya (urut)

1. `feat(host): DXGI capture + NVENC encode skeleton` — lihat `host/`.
2. `feat(client): sambungkan flutter_webrtc ke SessionPage` — lihat `client/`.
3. `feat(signaling): deploy Worker ke Cloudflare + verifikasi STUN/TURN`.
4. **STOP memoles UI** sampai Fase 0 go.

---

## Catatan ke dirimu (yang nulis README)

README-mu sudah luar biasa jujur. Pertahankan itu. Satu-satunya hal yang
perlu diubah segera: tabel "Build Otomatis" yang bilang Windows/iOS "ditunda"
padahal CI sudah membangunnya, dan referensi folder `remote-desktop-docs/`
yang tidak ada. Perbaiki sebelum orang luar membaca dan kehilangan kepercayaan.
