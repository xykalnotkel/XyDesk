# AGENT_BOARD.md — Papan Koordinasi Agent XyDesk

Papan ini adalah satu-satunya sumber kebenaran **siapa lagi kerja apa** dan
**push siapa yang sudah diizinkan**. `AGENT.md` mewajibkan: baca papan ini di
awal sesi, **kunci** areamu, barulah kerja. `HANDOFF.md` mencatat *hasil*
lintas role; papan ini mencatat *keadaan saat ini* (real-time).

> Papan ini ikut berkembang lewat commit ke `main`. Karena agent baru boleh
> push setelah diizinkan, alur persetujuannya:
> 1. Agent menyampaikan permintaan izin (chat/laporan sesi) berisi ID sesi +
>    ringkasan, dan menulis baris `MENUNGGU` di antrean bawah.
> 2. Operator mengubah status baris itu menjadi `DISETUJUI` pada commit
>    kecil di `main`.
> 3. Agent push dengan setiap commit memuat `Izin: <ID-SESI>` di body.
>    Workflow `verify-push-auth.yml` memeriksa ini di setiap push.

## Aturan operator (sejak 3 Sep 2026)

1. **Versi & berita ditentukan operator** — agent tidak menetapkan nomor
   versi, isi/terbitnya berita, atau bump `pubspec.yaml` sendiri.
2. **Cek sesi lain sebelum rilis** — build penuh/rilis hanya diajukan bila
   semua sesi yang menyentuh area rilis sudah `SELESAI`; kalau belum →
   tahan, lapor operator, jangan memaksakan.
3. **Tiap agent menulis bahan artikel kerjanya** — blok dampak pengguna +
   screenshot asli (gaya `docs/NEWS_STYLE.md`), ditulis saat sesi
   ditutup; role CI/Release menyatukan bahan semua agent menjadi SATU
   artikel saat rilis.

## Alur sesi (3 langkah)

1. **Kunci sesi** — tambah baris di tabel *Sesi aktif*, status `LAGI KERJA`.
   Format ID: `SESI-<YYYYMMDD>-<NAMA>-<AREA>`, contoh `SESI-20260903-CAKRA-CI`.
   Satu area hanya boleh dikunci satu agent. Area yang terkunci = jangan
   masuk tanpa menunggu.
2. **Minta izin push** — setelah CI area-mu hijau, pindahkan baris ke
   *Antrean izin push* (`MENUNGGU`) + ringkasan. Operator menulis
   `DISETUJUI` (atau `DITOLAK` + alasan).
3. **Tutup sesi** — setelah push hijau, pindahkan baris ke *Riwayat sesi*
   (`SELESAI` + tautan run CI). Riwayat tidak boleh dihapus.

## Sesi aktif (LOCK)

| ID Sesi | Agent | Role / Area | Status | Sedang mengerjakan | Mulai |
|---|---|---|---|---|---|
| SESI-20260903-DANU-WEB6 | Danu - XySpace Team | Web | LAGI KERJA | Tombol hero "Status rilis" → "Ingatkan saya" + popup pilih kanal kabar rilis (email / saluran WhatsApp / Telegram) | 2026-09-03 |
| SESI-20260903-DANU-WEB5 | Danu - XySpace Team | Web | SELESAI | Audit responsivitas semua halaman (desktop/tablet/HP) + perbaikan, tombol panah-bawah lompat ke akhir artikel di detail berita, pengingat mandar operator ke News (artikel wajib lengkap + screenshot perubahan) via HANDOFF | 2026-09-03 |
| SESI-20260903-DANU-WEB4 | Danu - XySpace Team | Web | SELESAI | Halaman Connect: blok "Dukung kami di" pindah ke atas "Cara main", input ID rata kiri menyamai field password, tombol show/hide password pairing | 2026-09-03 |
| SESI-20260903-DANU-WEB3 | Danu - XySpace Team | Web | SELESAI | Overhaul layar sesi web (rail ikon + panel 4 tab + stats live + papan klip ambil/kirim + E2E lokal), penulis berita → Haekal Saputra, screenshot sesi web untuk artikel | 2026-09-03 |
| SESI-20260903-CAKRA-RILIS | Cakra - XySpace Team | CI / Release | SELESAI | Rilis 6.3.0: bump versi + changelog + artikel berita + verifikasi rilis — v6.3.0 terbit (Build+Release hijau, artikel changelog-v6-3-0 live) | 2026-09-03 |
| SESI-20260903-GALIH-HOST-KEEPALIVE | Galih - XySpace Team | Host Engine | SELESAI | Host selalu aktif: balas ping WebSocket + sambung-ulang dalam proses (fix hidup-mati); push hijau, gate izin run 33721191903 | 2026-09-03 |

## Antrean izin push

| ID Sesi | Agent | Ringkasan perubahan | Status izin | Disetujui oleh | Kapan | Run CI |
|---|---|---|---|---|---|---|
| SESI-20260903-DANU-WEB6 | Danu - XySpace Team | Web: tombol hero "Status rilis" menjadi "Ingatkan saya" — popup pilihan kanal kabar rilis (email via subscribeNews berlabel unduhan, saluran WhatsApp, Telegram); CHANGELOG | DISETUJUI | Xyckal (chat) | 2026-09-03 | — |
| SESI-20260903-DANU-WEB5 | Danu - XySpace Team | Web: audit responsivitas lintas viewport semua halaman (+perbaikan temuan), tombol melayang panah-bawah di detail berita untuk lompat ke paling bawah (komentar), HANDOFF pengingat mandat operator ke News soal artikel lengkap; CHANGELOG | DISETUJUI | Xyckal (chat) | 2026-09-03 | Build 33722499575 + Verifikasi + Deploy Web hijau; live terverifikasi (bundle Bt6-jtJI = artifact, content-type JS, tombol lompat terdeteksi) |
| SESI-20260903-DANU-WEB4 | Danu - XySpace Team | Web: halaman Connect — urutan blok "Dukung kami di" naik di atas "Cara main", input ID perangkat rata kiri menyamai gaya field password (dulu angka besar terpusat), tombol show/hide password pairing; CHANGELOG | DISETUJUI | Xyckal (chat) | 2026-09-03 | Build 33721068628 + Verifikasi hijau; deploy CI kena race (lihat HANDOFF CI) — ditebus manual wrangler 66bca5d8 dari artifact resmi, live terverifikasi (bundle w_YYZNwL + tombol mata + ID kiri) |
| SESI-20260903-DANU-WEB3 | Danu - XySpace Team | Web: overhaul layar sesi web ke paritas aplikasi — rail kontrol ikon vertikal (Suara PC, Mik ke PC, Keyboard, Gamepad, Trackpad, papan klip kirim/ambil, layar penuh, pengaturan, putuskan, sembunyikan kontrol), panel pengaturan 4 tab (Gambar/Suara/Kontrol/Sesi) + statistik live dari getStats, pemilih layar masuk panel; tooltip badge resmi; lintas area news/ atas restu operator: penulis default worker berita `Haekal Saputra (XySpace)` → `Haekal Saputra` + README news + NEWS_STYLE + AGENT.md; harness E2E lokal web/e2e + 11 screenshot sesi web; CHANGELOG + HANDOFF screenshot semua platform | DISETUJUI | Xyckal (chat) | 2026-09-03 | Build 33718727238 + Verifikasi 33718727252 + Deploy Web 33718763308 + Deploy News 33718948271 (semua hijau; live terverifikasi: bundle baru srail+papan klip, client Google benar, byline Haekal Saputra) |
| SESI-20260903-CAKRA-CI | Cakra - XySpace Team | Filter area di `build.yml` (job `changes` + jobs terpisah), `check-meta`/`check-news`/`check-signaling` baru, skip gracful `deploy-web.yml`, workflow `verify-push-auth.yml`, `AGENT_BOARD.md`, pembaruan `AGENT.md`/`docs/CI.md`/`CHANGELOG.md`/`CONTRIBUTORS.md` | DISETUJUI | Xyckal | 2026-09-03 | Run 1: Build 33663421875 + Verifikasi 33663421843 · Run 2: Build 33663874463 + Verifikasi 33663874589 |
| SESI-20260903-CAKRA-NOTIF | Cakra - XySpace Team | Notifikasi push tanpa izin ke ntfy/Telegram pada `verify-push-auth.yml` + dokumentasi `docs/CI.md` + `CHANGELOG.md` | DISETUJUI | Xyckal | 2026-09-03 | Build 33664638977 + Verifikasi 33664638941 |
| SESI-20260903-GALIH-HOST | Galih - XySpace Team | Host Engine: bitrate video live lewat control API (aksi `video-bitrate` 1–50 Mbps, `targetBitrateBps` di `/status`), perbaikan E0308 build Windows (satu sumber tipe NVENC), pindah konstanta/perakit NVENC ke `nvenc_config.rs` + uji | DISETUJUI | Xyckal (chat) | 2026-09-03 | Build 33665824839 + Verifikasi 33665824719 |
| SESI-20260903-TARA-BACKEND | Tara - XySpace Team | Paritas keamanan signaling Go (token bind role, middleware tolak penyamar, relayAllowed, daftar host saja) + uji Go + email berita (badge 404) + engines Node ≥ 22 + dokumentasi protokol | DISETUJUI | Xyckal | 2026-09-03 | Build 33666899679 + Verifikasi 33666899695 + Deploy 33666899727 |
| SESI-20260903-CAKRA-GOTEST | Cakra - XySpace Team | `go vet` + `go test` signaling ditambahkan ke `check-signaling` + docs/CI.md | DISETUJUI | Xyckal | 2026-09-03 | Build 33666899679 + Verifikasi 33666899695 |
| SESI-20260903-CAKRA-RILIS | Cakra - XySpace Team | Rilis 6.3.0: bump versi 6.3.0+25 (pubspec/Cargo/web/desktop), changelog, artikel berita changelog-v6-3-0, screenshot asli, verifikasi rantai Build→Release→Deploy | DISETUJUI | Xyckal | 2026-09-03 | — |
| SESI-20260903-GALIH-HOST-LATENCY | Galih - XySpace Team | Host: metrik latensi pipeline (capture→encode→write RTP) di `/status` (`video.latencyMs` EMA + `video.latencyMaxMs`) + label encoder (`video.encoder`) + durasi sampel/fps nominal 60 diseragamkan + uji | DISETUJUI | Xyckal (chat) | 2026-09-03 | Build 33668808596 + Verifikasi 33668808668 + Installer Windows 33668808665 |

| SESI-20260903-DANU-WEB | Danu - XySpace Team | Web Connect: pemindai QR (BarcodeDetector + fallback jsQR, dep baru jsqr@1.4.0 Apache-2.0), panduan "Cara main" client/host, blok sosmed Telegram/WhatsApp/TikTok, TikTokIcon, sembunyikan tombol QR tanpa API kamera; termasuk pengesahan retroaktif push a7b2863+e9f4fc2 (sebelum gerbang berlaku) | DISETUJUI | Xyckal (chat) | 2026-09-03 | Build 33681414047 + Verifikasi 33681414017 + Deploy 33681469908 |
| SESI-20260903-DANU-WEB-AUDIT | Danu - XySpace Team | Pengesahan retroaktif 4 push Web pra-gerbang: d3522bb (overlay kontrol sesi + Connect responsif), 0081742 (keyboard virtual + panel gaming + trackpad), 4785561 (mandat logo + kata penting ungu), bff26bb (panel pengaturan sesi) — semua dipush sebelum verify-push-auth.yml berlaku, semua sudah live & hijau | DISETUJUI | Xyckal (chat) | 2026-09-03 | — |
| SESI-20260903-GALIH-HOST-MIC | Galih - XySpace Team | Host: mic input PC → client — WASAPI `eCapture` (perangkat komunikasi default, 48 kHz mono) → Opus 20 ms → track audio kedua (stream `mic`), otomatis hanya bila ada perangkat capture; `/status` + `meta` melaporkan `micAvailable`/`micPipeline`; uji 64 unit + loopback + cross-check Windows | DISETUJUI | Xyckal (chat) | 2026-09-03 | Verifikasi 33685216940 (push host tidak memicu build otomatis — kebijakan 7ddb594) |
| SESI-20260903-DANU-WEB2 | Danu - XySpace Team | Web: halaman Sewa PC (/billing, paket+durasi mulai 1 jam/Rp5.000, pesan via WA), mode founder komentar (xycdigital@gmail.com + ADMIN_TOKEN → Haekal Saputra + badge XySpace), badge "Resmi"→"XySpace", teks beranda dibumikan, CORS worker berita +X-Admin-Token (1 baris, lintas area news/ atas restu operator) | DISETUJUI | Xyckal (chat) | 2026-09-03 | Build+Izin+Deploy hijau di 439944d; deploy-news manual sukses; CORS live terverifikasi |
| SESI-20260903-LARAS-CLIENT | Laras - XySpace Team | Client Flutter: ikon nav bawah/rail AI 3D ungu glossy (2 mode off=abu/on=warna, `assets/img/nav/*`), pilih sumber papan ketik sesi (XyDesk vs Sistem/IME → 0x06 TEXT), perbaikan tombol Kirim & balas komentar (listener), identitas komentar login/tamu tetap berprofil, highlight kata penting + email/URL klik di Legal, jarak chip Riwayat↔input ID | DISETUJUI | Xyckal | 2026-09-03 | — |
| SESI-20260903-GALIH-HOST-UI | Galih - XySpace Team | Host Windows: GUI kembali ke shell Electron/Next.js (bukan jendela native 5MB) + tray always-on (tutup jendela = sembunyi ke tray, engine tetap hidup); `desktop/electron/main.cjs` diberi Tray/menu/close-to-tray; installer & CI diubah (build.yml `windows` → electron-builder `--dir`, `desktop/**` masuk filter host, release.yml hapus job `windows-host`) | DISETUJUI | Xyckal (chat) | 2026-09-03 | Verifikasi 33717936050 (push host tidak memicu build otomatis — kebijakan 7ddb594) |
| SESI-20260903-GALIH-HOST-KEEPALIVE | Galih - XySpace Team | Host: fix hidup-mati — engine balas ping WebSocket (server signaling menendang koneksi diam > 90 dtk) + `main()` sambung-ulang dalam proses dgn backoff (keluar hanya bila token ditolak/tak terjangkau 10×); supervisor Electron anti-spawn-ganda + hormati backoff + log kode keluar; uji 65 unit + loopback | DISETUJUI | Xyckal (chat) | 2026-09-03 | Verifikasi izin push 33721191903 (push host tidak memicu build otomatis — kebijakan 7ddb594) |

## Riwayat sesi (hanya bertambah)

| ID Sesi | Agent | Area | Status | Ringkasan | Selesai |
|---|---|---|---|---|---|
| SESI-20260903-DANU-WEB5 | Danu - XySpace Team | Web | SELESAI | Tombol lompat panah-bawah/atas di detail berita + fix overflow langganan email di HP (33–63 px) hasil audit responsivitas 7 halaman × 5 viewport + pengingat mandat artikel lengkap ke News; live terverifikasi 261352f | 2026-09-03 |
| SESI-20260903-GALIH-HOST-KEEPALIVE | Galih - XySpace Team | Host Engine | SELESAI | Fix hidup-mati: engine balas ping WebSocket (server menendang koneksi diam > 90 dtk) + `main()` sambung-ulang dalam proses dgn backoff (keluar hanya bila token ditolak/tak terjangkau 10×); supervisor Electron anti-spawn-ganda + hormati backoff + log kode keluar; uji 65 unit + loopback; verifikasi idle > 5 menit tetap di lab Windows (HANDOFF) | 2026-09-03 |
| SESI-20260903-DANU-WEB4 | Danu - XySpace Team | Web | SELESAI | Halaman Connect: "Dukung kami di" di atas "Cara main", input ID rata kiri, tombol show/hide password; live via deploy manual 66bca5d8 setelah race deploy-web.yml (dilaporkan ke CI di HANDOFF) | 2026-09-03 |
| SESI-20260903-DANU-WEB3 | Danu - XySpace Team | Web | SELESAI | Layar sesi web paritas aplikasi: rail ikon + panel 4 tab + statistik live + ambil/kirim papan klip + harness E2E lokal (web/e2e) + 11 screenshot sesi asli; penulis berita → Haekal Saputra (worker+docs, restu operator); live terverifikasi 235a447 | 2026-09-03 |
| SESI-20260903-GALIH-HOST-UI | Galih - XySpace Team | Host Engine (UI/UX) | SELESAI | Host Windows kembali ke shell Electron/NextJS (installer) + tray always-on (tutup jendela = sembunyi ke tray, engine hidup); CI build.yml windows → electron-builder --dir + desktop/** di filter host; release.yml hapus windows-host | 2026-09-03 |
| SESI-20260903-DANU-WEB2 | Danu - XySpace Team | Web | SELESAI | Halaman Sewa PC (/billing) + mode founder komentar + badge XySpace + beranda dibumikan + CORS X-Admin-Token worker berita (deploy-news manual, terverifikasi live) | 2026-09-03 |
| SESI-20260903-DANU-WEB-AUDIT | Danu - XySpace Team | Web | SELESAI | Pengesahan retroaktif push pra-gerbang (d3522bb/0081742/4785561/bff26bb) + tutup item audit Web di HANDOFF | 2026-09-03 |
| SESI-20260903-DANU-WEB | Danu - XySpace Team | Web | SELESAI | Connect: pemindai QR (BarcodeDetector + jsQR) + panduan Cara main + sosmed Telegram/WhatsApp/TikTok; tombol QR disembunyikan tanpa API kamera; bundle web terpublikasi (fitur sempat tertahan karena deploy d358203 skip) | 2026-09-03 |
| SESI-20260903-CAKRA-CI | Cakra - XySpace Team | CI / Release | SELESAI | Filter area CI (build.yml), skip pintar deploy-web.yml, gerbang verify-push-auth.yml, papan koordinasi, pembaruan AGENT.md/docs/CI.md/CHANGELOG/CONTRIBUTORS/HANDOFF | 2026-09-03 |
| SESI-20260903-CAKRA-NOTIF | Cakra - XySpace Team | CI / Release | SELESAI | Notifikasi push tanpa izin (ntfy/Telegram) di verify-push-auth.yml + docs/CI.md | 2026-09-03 |
| SESI-20260903-GALIH-HOST | Galih - XySpace Team | Host Engine | SELESAI | Bitrate video live via control API (video-bitrate 1–50 Mbps + targetBitrateBps di /status) + uji; perbaikan E0308 build Windows; pindah konstanta/perakit NVENC ke nvenc_config.rs + uji | 2026-09-03 |
| SESI-20260903-TARA-BACKEND | Tara - XySpace Team | Backend / Edge | SELESAI | Paritas keamanan signaling Go dgn Worker (role di token, middleware tolak penyamar, relayAllowed, daftar host saja) + uji Go + email berita (badge 404) + engines Node ≥ 22 + docs protokol | 2026-09-03 |
| SESI-20260903-CAKRA-GOTEST | Cakra - XySpace Team | CI / Release | SELESAI | `go vet` + `go test` signaling jadi pengawal di check-signaling (kini step "Uji unit Go (signaling)") + docs/CI.md | 2026-09-03 |
| SESI-20260903-GALIH-HOST-LATENCY | Galih - XySpace Team | Host Engine | SELESAI | Metrik latensi pipeline (capture→encode→write RTP) di `/status` (`video.latencyMs` EMA + `video.latencyMaxMs`) + label encoder (`video.encoder`) + durasi sampel/fps nominal 60 + uji | 2026-09-03 |
| SESI-20260903-GALIH-HOST-MIC | Galih - XySpace Team | Host Engine | SELESAI | Mic input PC → client (WASAPI eCapture → Opus mono, stream `mic`), otomatis bila ada perangkat capture; `/status` + `meta` melaporkan micAvailable/micPipeline; uji 64 unit + loopback + cross-check Windows | 2026-09-03 |
| SESI-20260903-LARAS-CLIENT | Laras - XySpace Team | Client Flutter | SELESAI | Ikon nav bawah/rail AI 3D ungu glossy (2 mode off=abu/on=warna), pilih sumber papan ketik sesi (XyDesk vs Sistem/IME), perbaikan tombol Kirim & balas komentar, identitas komentar login/tamu tetap berprofil, highlight kata penting + email/URL klik di Legal, jarak chip Riwayat↔input ID | 2026-09-03 |
