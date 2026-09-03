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
4. **Build/kompilasi/kemasan/deploy/rilis = kewenangan role CI/Release
   (Cakra)** — semua lewat `workflow_dispatch` setelah izin operator;
   push agent lain **tidak boleh memicu actions** (kecuali gerbang audit
   izin `verify-push-auth.yml`). Agent push kode + dokumen saja.
5. **Jalur deploy cepat (restu operator di chat, 3 Sep 2026)** — untuk
   layanan yang butuh cepat live: **Web app** (Danu) serta **worker
   Backend/Edge dan worker berita** boleh deploy langsung tanpa menunggu
   dispatch CI/Release. Syarat kumulatif: (a) push sudah di `main` dan
   `verify-push-auth` hijau; (b) build memakai env produksi yang benar
   (mis. `VITE_GOOGLE_CLIENT_ID` untuk web); (c) verifikasi pasca-deploy
   wajib dan tercatat (contoh web: md5 bundle live == build, content-type
   JS benar); (d) dicatat terbuka di baris sesi papan + item HANDOFF ke
   CI/Release pada sesi yang sama. Build/rilis penuh (APK, Windows,
   installer, tag rilis) TETAP kewenangan CI/Release. Kredensial deploy
   adalah milik operator — pembagiannya ke lingkungan agent lain adalah
   keputusan operator, bukan agent.

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

> Kosong = tidak ada area yang sedang dikunci. Baris `SELESAI` **tidak boleh**
> menumpuk di sini — begitu sesi ditutup, pindahkan ke *Riwayat sesi* (langkah
> 3 alur sesi). Tabel ini hanya untuk yang benar-benar `LAGI KERJA`.

| ID Sesi | Agent | Role / Area | Status | Sedang mengerjakan | Mulai |
|---|---|---|---|---|---|

_Tidak ada sesi aktif (3 Sep 2026, setelah SESI-20260903-GALIH-HOST-AUDIT ditutup)._

## Antrean izin push

| ID Sesi | Agent | Ringkasan perubahan | Status izin | Disetujui oleh | Kapan | Run CI |
|---|---|---|---|---|---|---|
| SESI-20260903-SENA-DOCS | Sena - XySpace Team | Docs & Audit (restu operator di chat, lintas area News+Client): rapi papan koordinasi — pindah semua baris SELESAI dari Sesi aktif & Antrean ke Riwayat, catat rilis 6.4.0 yang belum tercatat; selaraskan byline sisa 'Tim XyDesk' -> 'Haekal Saputra' (news/schema.sql, news/seed.sql, news/README.md, fallback client news_service.dart); CHANGELOG [Belum terbit]; HANDOFF ditutup | DISETUJUI | Xyckal (chat) | 2026-09-03 | Verifikasi izin push (run gate) — lihat push sesi ini |
| SESI-20260903-SENA-DOCS-AUDIT | Sena - XySpace Team | Docs & Audit (tanpa perubahan kode): README §Build/Release tidak lagi mengklaim push memicu build; `docs/CI.md` tabel workflow dilengkapi (build-desktop/deploy-news/test-lab) + bagian Release diluruskan (dispatch, bukan push) + aturan #3 dikoreksi; `docs/VERSIONING.md` versi acuan 6.2.0+22 → 6.4.0+27, tag contoh v6.4.0, kalimat "rilis berikutnya 6.2.0" dihapus, peringatan slug changelog 404; `docs/NEWS_STYLE.md` +blok "Siapa yang menulis"; `HANDOFF.md` 2 item Docs ditutup + 5 temuan baru (slug changelog 404, contoh author `Tim XyDesk` di news/README, butir CHANGELOG 6.4.0 terpotong, tabel LOCK penuh baris SELESAI, ID sesi rilis dipakai dua kali); `CHANGELOG.md` [Belum terbit] | DISETUJUI | Xyckal (chat) | 2026-09-03 | Push `a184818` — Verifikasi Izin Push **hijau** (run 2026-09-03T14:32Z); tidak ada build yang terpicu, sesuai kebijakan 3 Sep |
| SESI-20260903-SENA-DOCS2 | Sena - XySpace Team | Docs & Audit (restu operator 'gas aja' di chat): verifikasi sinkronisasi aturan rilis baru di docs/CI.md + NEWS_STYLE.md + news/README.md (ternyata sudah sinkron, tanpa perubahan kode); pastikan client OAuth web lewat bundle live — 'dp1k3678' = benar, 'cadhmro3' di berkas kunci = salah, dikoreksi di berkas operator; HANDOFF: semua item Docs & Audit ditutup | DISETUJUI | Xyckal (chat) | 2026-09-03 | Verifikasi izin push (run gate) — lihat push sesi ini |
| SESI-20260903-TARA-TESTS | Tara - XySpace Team | Backend / Edge (dipilih operator via chat): audit & perkuat tes worker signaling/berita — verifyGoogleIdToken (nol-test) dikunci 14 kasus RSA sungguhan, verifyJwt +6 kasus tepi, token signaling +kasus tamper/rusak, relayAllowed bye/ice, adminPublish +8 kasus (slug changelog); tanpa perubahan kode produksi; cloudflare/ 51/51 + news/ 20/20 hijau | DISETUJUI | Xyckal (chat) | 2026-09-03 | Verifikasi izin push (run gate) — lihat push sesi ini |

## Riwayat sesi (hanya bertambah)

| ID Sesi | Agent | Area | Status | Ringkasan | Selesai |
|---|---|---|---|---|---|
| SESI-20260903-GALIH-HOST-AUDIT | Galih - XySpace Team | Host Engine | SELESAI | Audit penuh `host/` + 8 perbaikan: (1) `Disconnected` diberi masa tenggang 15 dtk (blip Wi-Fi tidak lagi mencabut pairing; kebijakan dipindah ke `session::slot_action`, 3 uji); (2) pelepasan slot kini MENUTUP peer connection supaya capture+encoder berhenti pasti, dijaga `ControlState::stop_session_if_current` agar teardown sesi lama tidak menimpa sesi baru (1 uji); (3) `offer`/renegosiasi menutup sesi lama — satu sesi media per host; (4) 0x06 TEXT diinject per 32 karakter mengikuti nilai kembali `SendInput` + batas 4.096 unit UTF-16 dipotong di batas karakter (5 uji, menutup item HANDOFF kontrak keyboard dari Laras); (5) `set_streaming` pakai `recover_lock` (satu-satunya `.lock().unwrap()` produksi yang tersisa); (6) papan klip: `GlobalFree` saat `GlobalLock`/`SetClipboardData` gagal; (7) dua lint Windows-only diperbaiki — `tool/check-host-windows.sh --clippy` MERAH di main sebelumnya; (8) `host/Cargo.lock` disinkronkan 6.3.0 → 6.4.0. Ditambah `host/TEST-LAB-WINDOWS.md` (langkah uji lab Windows siap jalan). Izin operator DISETUJUI via chat; gerbang izin push hijau (run 33769638361). Perilaku runtime di Windows BELUM diuji di lab — itu tugas sesi berikutnya. | 2026-09-03 |
| SESI-20260903-SENA-DOCS | Sena - XySpace Team | Docs & Audit | SELESAI | Audit + beres-beres: AGENT_BOARD.md dirapikan (baris SELESAI dipindah dari Sesi aktif & Antrean ke Riwayat; rilis 6.4.0 dicatat), byline sisa 'Tim XyDesk' -> 'Haekal Saputra' di schema/seed/README news + fallback client; CHANGELOG [Belum terbit]; HANDOFF diperbarui | 2026-09-03 |
| SESI-20260903-SENA-DOCS2 | Sena - XySpace Team | Docs & Audit | SELESAI | Verifikasi sinkronisasi aturan rilis baru (CI.md/NEWS_STYLE.md/news README sudah sinkron — tanpa perubahan kode) + pastikan client OAuth web via bundle live (dp1k3678 benar; berkas kunci operator dikoreksi); semua item Docs & Audit di HANDOFF ditutup | 2026-09-03 |
| SESI-20260903-TARA-TESTS | Tara - XySpace Team | Backend / Edge | SELESAI | Audit & perkuat tes worker signaling/berita tanpa ubah produksi: verifyGoogleIdToken 14 kasus (RSA sungguhan), verifyJwt +6, token signaling +tamper, relayAllowed bye/ice, adminPublish +8 (slug changelog — akar 404 footer 6.4.0); cloudflare/ 51/51 & news/ 20/20 hijau; CI memungut otomatis | 2026-09-03 |
| SESI-20260903-CAKRA-RILIS64 | Cakra - XySpace Team | CI / Release | SELESAI | Rilis 6.4.0+27: bump 4cbbc22 -> Build 33728695280 12/12 -> Release 33729544852 5/5 (tag v6.4.0, 8 aset, update.json build 27, OneSignal e4f5574a); aset artikel cache-bust 8b1ebbd -> Build 33732158168 -> deploy 33732896248; artikel p-8f5aa26aa3bc (id 73) live | 2026-09-03 |
| SESI-20260903-CAKRA-RILIS | Cakra - XySpace Team | CI / Release | SELESAI | Rilis 6.3.0: bump versi 6.3.0+25 (pubspec/Cargo/web/desktop), changelog, artikel berita changelog-v6-3-0, screenshot asli, verifikasi rantai Build->Release->Deploy | 2026-09-03 |
| SESI-20260903-SENA-DOCS-AUDIT | Sena - XySpace Team | Docs & Audit | SELESAI | Audit konsistensi repo: README & `docs/CI.md` disamakan dengan kebijakan pemicu 3 Sep (push tidak memicu build), tabel workflow dilengkapi 3 berkas, `docs/VERSIONING.md` dimutakhirkan ke 6.4.0+27 + peringatan slug changelog 404, `docs/NEWS_STYLE.md` +pembagian penulisan berita; 5 temuan lintas role dicatat di HANDOFF (slug changelog 404, contoh author `Tim XyDesk` di news/README, butir CHANGELOG 6.4.0 terpotong, tabel LOCK penuh baris SELESAI, ID sesi rilis dipakai dua kali). Tanpa perubahan kode; flutter/cargo tidak tersedia di lingkungan — analisis tidak dijalankan (tidak diperlukan untuk perubahan Markdown) | 2026-09-03 |
| SESI-20260903-GALIH-HOST-DIAG | Galih - XySpace Team | Host Engine | SELESAI | Diagnostik & konsistensi UI desktop: "Engine belum siap" menyertakan sebab (lastEngineError) + ID/password tetap tampil saat engine mati; nav/judul dibumikan (Beranda/Hubungkan/Berita/Profil/Pengaturan); tab Berita timeout 10 dtk + pesan Indonesia + Coba lagi + tautan web; uji tsc/next build/node --check; jalur signaling terverifikasi end-to-end (host-token→/ws 101→welcome) | 2026-09-03 |
| SESI-20260903-DANU-WEB9 | Danu - XySpace Team | Web | SELESAI | Aturan papan #5: jalur deploy cepat Web + worker Backend/berita (syarat: main + izin hijau, env produksi, verifikasi pasca-deploy tercatat, info ke CI); tanpa perubahan kode | 2026-09-03 |
| SESI-20260903-DANU-WEB8 | Danu - XySpace Team | Web | SELESAI | Fix avatar ganda komentar resmi (prop avatar=false di komentar/reply) + byline 5 artikel lama 'Tim …' dinormalisasi di D1; verifikasi visual + D1 hijau | 2026-09-03 |
| SESI-20260903-DANU-WEB7 | Danu - XySpace Team | Web | SELESAI | Sewa PC: durasi custom 1–24 jam + stok per paket (angka operator) + fix deep link /billing; layar sesi: chip durasi & sisa waktu tamu 2 jam + Total/Sisa di tab Sesi; parity APK di-HANDOFF; verifikasi izin hijau, dispatch CI menunggu (kebijakan baru) | 2026-09-03 |
| SESI-20260903-GALIH-HOST-STABIL | Galih - XySpace Team | Host Engine | SELESAI | Hardening stabilitas: capture berhenti saat sesi tutup (FrameSource + stop saat Disconnected), retry capture saat ditutup OS, mutex poison-safe (recover_lock), timeout supervisor (token/control API); uji 66 unit + loopback + cross-check Windows-gnu; verifikasi runtime di lab Windows (HANDOFF) | 2026-09-03 |
| SESI-20260903-LARAS-CLIENT2 | Laras - XySpace Team | Client Flutter | SELESAI | Tombol Billing di topbar (buka Langganan), isolasi data lokal per akun (fix kebocoran data antar akun — security-relevant), changelog lengkap di Pusat Update (body GitHub Release); analyze bersih, 53/53 test hijau | 2026-09-03 |
| SESI-20260903-DANU-WEB6 | Danu - XySpace Team | Web | SELESAI | Tombol hero "Status rilis" → "Ingatkan saya" + popup kanal kabar rilis (email/WA/Telegram); diuji E2E (validasi, sukses, tutup, responsif HP); live terverifikasi 32e24fb | 2026-09-03 |
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
