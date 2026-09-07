# Audit Operator Pasca-6.7.0 — 2026-09-07

> Sesi: `SESI-20260907-OPERATOR-ALL` — Operator - XyDesk Team (semua area)
> Status: LAGI KERJA
> Konteks: Rilis 6.7.0+35 baru live (Build #244, Release #188, Deploy Web #174, Signaling #31, News #18). Founder minta mode Operator.

Dokumen ini adalah kelanjutan dari `AUDIT-2026-09-06.md`. Bedanya: yang kemarin fokus diagnosis "stuck" + paritas token, yang ini fokus **apa yang sudah sembuh di 6.7.0 dan apa hutang yang tersisa untuk 6.8.0.**

---

## 1. Apa yang SEMBUH di 6.7.0 (verifikasi)

### 1.1 Layar hitam hybrid-GPU — TUNTAS (kode)
Rantai `DXGI → WGC → GDI` di `host/src/screen.rs` + `dxgi.rs` + `gdi.rs`:
- DXGI baca output display langsung, bukan texture app. Jadi di laptop iGPU (Intel) + dGPU (Nvidia) yang dulu frame WGC terikat GPU salah, sekarang DXGI tetap dapat.
- `--capture-test` flag baru: tangkap 1 frame tanpa peer, lapor backend aktif + `framesSent`. Ini alat diagnosis lapangan paling jujur — bisa jalanin di warnet tanpa pairing.

**Bukti CI:** `build-desktop.yml` #35 hijau, `host/tests/loopback.rs` masih hijau. Yang belum: angka di lab Windows nyata (lihat §3).

### 1.2 Audio WASAPI 0x88890008 — TUNTAS (kode)
`host/src/audio.rs` dulu paksa PCM16/48k di `Initialize`. Shared mode WASAPI cuma terima mix format device. Sekarang `GetMixFormat` → decode I16/I24/I32/F32 → clamp → resample linear → downmix → Opus. `pcmconv.rs` baru 8.6KB khusus konversi.
Cast `CoTaskMemFree` Windows 0.61 (`Option<*const c_void>`) yang bikin build-desktop #34 merah juga sudah beres di #35.

**Sisa:** uji dengar di device yang mix format-nya bukan 48k stereo (mis. 44.1k / mono / 5.1).

### 1.3 `pair-terkunci` tidak sampai ke user — TUNTAS
`cloudflare/src/pairguard.rs` + `hub.js` kirim `pair-terkunci` + `reason` + `retry_in`. Web `rtc.ts` dan Flutter `rtc_service.dart` dulu cek `host-sibuk` yang tidak pernah dikirim hub → gantung. Sekarang dua klien terima `pair-terkunci` (alias legacy `host-sibuk`) dan tampilkan sisa detik.

**Bukti live:** bundle web `index-*.js` 6.7.0 memuat string `pair-terkunci` (verifikasi di Deploy Web #174).

### 1.4 Kursor "berenang" setelah backlog — TUNTAS
`host/src/input.rs` sekarang bedakan STATE vs EVENT:
- `MouseMoveAbs` (0x02) = STATE → cuma terakhir yang dipakai (`buang_abs_basi`)
- Rel, button, key, scroll = EVENT → tidak pernah dibuang
Tiga test baru jaga kontrak.

### 1.5 Izin runtime Android — TUNTAS (kode)
`permission_handler` 11.3.1 + `lib/core/permissions.dart`: izin diminta pada momen fitur dipakai (toggle mic, QR scanner, permissions page). Deny permanen → dialog buka Settings. Manifest tanpa `request` runtime tidak pernah munculkan dialog — itu akar keluhan "izin mic tidak muncul".

### 1.6 Domain xystudio → xydesk — TUNTAS (kode)
Grep `xystudio.my.id` di `lib/`, `web/src/`, `host/`, `desktop/`, `cloudflare/`, `news/` → 0 hasil (kecuali riwayat `AGENT_BOARD.md` + `CHANGELOG.md` yang memang sengaja dibiarkan). `_headers` CSP sudah `signal.xydesk.my.id` + `news.xydesk.my.id`. `robots.txt` sitemap domain baru.

---

## 2. Hutang yang MASIH TERBUKA (jujur)

### 2.1 TURN belum punya secret — PALING KRITIS
`cloudflare/src/turn.js` sudah multi-provider paralel + timeout 2.5s + `providers` di balasan. Tapi `wrangler secret list` live masih kosong untuk TURN. `/turn-ice` jawab `iceServers: []`.

**Dampak:** user di belakang CGNAT (mayoritas ISP Indo: Indihome, MyRepublic, Biznet CGNAT) yang dua-duanya NAT simetris → STUN gagal → sesi tidak pernah connect, tanpa pesan yang jelas. Ini pembunuh retention.

**Rekomendasi Operator (tanpa kartu kredit):**
1. Daftar **ExpressTurn** free tier — dapat `TURN_STATIC_URLS` + `TURN_STATIC_SECRET`
2. `npx wrangler secret put TURN_STATIC_URLS` + `TURN_STATIC_SECRET` (atau via GitHub Secrets `TURN_STATIC_URLS` / `TURN_STATIC_SECRET` → dispatch `Deploy Signaling`)
3. Verifikasi: `tool/check_turn_live.js` (baru di sesi ini) → harus ada `providers[0].ok=true`

Jangan pakai Cloudflare Realtime dulu — butuh kartu kredit, nabrak `ROADMAP.md`.

### 2.2 Latency glass-to-glass belum terukur
`ROADMAP.md` Fase 0 minta `<40ms LAN`, `<80ms via TURN`. `host/src/main.rs --bench` cuma ukur encode. Belum ada foto 2 layar (host + client berjejer) dengan timestamp overlay.

**Protokol ada di `docs/LATENCY.md`:** overlay timestamp di host, foto bareng, baca selisih. Butuh 10 sampel. Ini yang menentukan apakah positioning "untuk gaming" sah atau harus pivot ke "kerja remote".

**Saran:** `tool/` tambah `latency_overlay.py` yang gambar jam di layar host tiap frame, lalu ukur di HP.

### 2.3 Branch mati — SUDAH BERSIH (verifikasi)
HANDOFF 2026-09-06 bilang 4 branch mati tertinggal 100k baris: `feat/nvenc`, `feat/installer-vdd-modern`, `fix/video-loopback-fase0`, `audit/perbaikan-2026-09-01`. Cek `git branch -a` + `git ls-remote` sekarang cuma `main`. Berarti sudah dihapus operator. Tutup item ini.

### 2.4 `update.json` tidak disajikan dari domain
`release.yml` upload `update.json` sebagai aset GitHub Release (`releases/download/v6.7.0/update.json`), bukan di `app.xydesk.my.id/update.json` atau `signal.xydesk.my.id/update.json`. Client baca dari URL GitHub — itu sah, tapi tidak ada yang cek. Kalau client ada yang hardcode domain sendiri, update tidak pernah ditawarkan.

**Tindakan:** audit `lib/features/notifications/update_repository.dart` + `web/src/version.ts` — pastikan URL-nya `https://github.com/xykalnotkel/XyDesk/releases/download/.../update.json` atau lewat `app.xydesk.my.id` proxy.

### 2.5 6 slug changelog 404 — BUTUH KEPUTUSAN FOUNDER
`changelog-v6-5-4`, `-5-3`, `-5-2`, `-4-0`, `-1-0`, `-0-0` = 404 live karena dulu terbit tanpa field `slug` → jatuh ke `p-<hash>`. Worker tidak punya endpoint alias/update. Opsi:
- (a) tambah alias di worker (paling bersih, tidak mutus link lama)
- (b) `UPDATE posts SET slug=...` langsung di D1 (cepat tapi mutus link lama)
- (c) biarkan — footer web sudah punya fallback "Catatan rilis belum tersedia"

Ini keputusan produk, bukan teknik. Founder yang putuskan.

### 2.6 Watchdog "connected tapi belum ada frame"
`HANDOFF.md` item Client Flutter: `RtcPhase.connected` dipicu transport ICE/DTLS, bukan frame video pertama. Kalau track video tidak pernah sampai, user tatap layar hitam yang klaim tersambung. `SessionStats.hasVideo` + `resolutionLabel='Belum ada gambar'` sudah ada — tinggal jadi pemicu timer 10 detik → banner jujur + tawarkan `selectDisplay`/retry.

Belum dikerjakan karena butuh Flutter toolchain.

---

## 3. Zero-Copy Roadmap (kenapa encode masih 30ms @360p)

Benchmark 6.1.0: openh264 CPU ~30ms @640x360. Target ROADMAP <10ms @1080p60 → wajib hardware.

Kondisi sekarang:
- `host/src/screen.rs` → `pixfmt.rs` RGBA→NV12 di CPU (rata-rata blok 2x2, BT.601)
- `nvenc.rs` terima NV12 dari CPU, copy ke D3D11 texture, baru encode

**Upgrade yang masih murni user-mode (tanpa driver, tanpa EV signing):**
1. **Zero-copy DXGI→NVENC via shared NT handle** — `IDXGIResource::GetSharedHandle` → `ID3D11Device::OpenSharedResource` → NVENC `NV_ENC_INPUT_RESOURCE_TYPE_DIRECTX`. Buang salin CPU.
2. **Pilih adapter diskrit sebelum encoder** — `CreateDXGIFactory1` + `EnumAdapters1` + prefer GPU dengan `NVENC` caps, bukan GPU yang render UI.
3. **Per-app audio capture** — `AUDIOCLIENT_ACTIVATION_PARAMS` + `PROCESS_LOOPBACK_MODE_TARGET` (Win10 2004+) biar cuma suara game yang ke HP, bukan semua output PC.

Ketiganya dicatat di `HANDOFF.md` Host Engine, belum dikerjakan. Estimasi gain: 15-20ms.

---

## 4. Keputusan yang TIDAK diambil (sengaja)

- **C++: JANGAN.** Sudah diputuskan di audit 6 Sep: C sudah jalan (`build.rs` + libopus vendor via `cc`), NVENC Rust murni FFI dinamis, IddCx butuh EV signing berbayar nabrak ROADMAP. Pakai `ge9/IddSampleDriver` MIT+CC0 kalau butuh display virtual.
- **Dark mode Android: JANGAN.** `ROADMAP.md` bilang terang (Paper) saja — satu set kontras teruji.
- **Garis pemisah di web/desktop: BIARKAN DULU.** `docs/DESIGN.md` catat sebagai penyimpangan disengaja. Hapus 282 pemakaian `border` di web tanpa ganti hierarki = visual collapse. Butuh design pass terpisah.

---

## 5. Checklist sebelum 6.8.0

- [ ] Isi TURN static + verifikasi `tool/check_turn_live.js` → `providers[0].ok=true`
- [ ] Ukur latency 10 sampel LAN + 10 sampel internet via TURN, tulis di `README.md` + `docs/LATENCY.md`
- [ ] Jalankan `host/TEST-LAB-WINDOWS.md` 5 blok di PC Windows nyata, tulis log asli ke HANDOFF
- [ ] Watchdog "connected tapi no frame" di Flutter + Web
- [ ] `update.json` URL audit di client
- [ ] Keputusan 6 slug 404 (alias vs biarkan)
- [ ] Zero-copy DXGI→NVENC skeleton (kalau mau kejar gaming)

Semua di atas tanpa bump versi — bump versi tetap keputusan founder di chat.

---

> Catatan Operator: repo ini sudah di atas rata-rata repo remote desktop open-source. Yang kurang bukan kode, tapi angka lapangan. Bukti dulu, baru poles.
