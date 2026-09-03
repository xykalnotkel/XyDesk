# AGENT.md — Aturan Kerja Agent AI di XyDesk

> **WAJIB dibaca penuh di awal SETIAP sesi, sebelum menyentuh satu file pun.**
> Dokumen ini adalah kontrak kerja. Melanggar dokumen ini = kerja sesi itu
> dianggap tidak sah. Sumber kebenaran teknis tetap `ROADMAP.md`; dokumen ini
> mengatur **cara kerja dan perilaku**.

---

## 0. Ritual awal sesi (urut, jangan dilompati)

1. Baca `AGENT.md` (file ini) sampai habis.
2. Baca `AGENT_BOARD.md` — papan koordinasi. Ini yang membuat agent-agent
   **saling tahu**: siapa lagi mengunci area mana, siapa yang sedang kerja
   apa, dan push siapa yang sudah diizinkan.
3. Baca `ROADMAP.md` bagian fase yang aktif, lalu `CHANGELOG.md` bagian
   `[Belum terbit]` — supaya tahu posisi proyek hari ini, bukan menebak.
   Baca juga `HANDOFF.md`: kalau ada item untuk role-mu, itu antrian
   kerjamu.
4. Tentukan **SATU role** untuk sesi ini (lihat bagian 2):
   - Kalau operator (pemilik repo) sudah menyebut role/tugas → pakai itu.
   - Kalau tidak → pilih sendiri role yang paling cocok dengan tugas yang
     diminta, dan **sebutkan pilihanmu di awal**, contoh:
     > "Sesi ini saya ambil role **Web** sebagai *Raka - XySpace Team*.
     > Scope saya hanya `web/` dan `web_deploy/`."
5. Tentukan **identitas kontributor** (lihat bagian 3). Satu identitas
   melekat pada satu role — jangan ganti-ganti di tengah sesi.
6. **Klaim areamu** (lihat bagian 5): sampaikan ke operator (di chat
   laporan sesi) ID sesi `SESI-<YYYYMMDD>-<NAMA>-<AREA>` + area + ringkasan.
   Kalau area itu sudah diklaim agent lain, JANGAN masuk — ambil role
   lain atau tunggu. Baris `LAGI KERJA` di papan ikut terbit pada push
   pertamamu; baris `DISETUJUI` ditulis operator pada commit persetujuan.
7. Baru mulai kerja.

---

## 1. Aturan emas: 1 sesi = 1 role

- Satu sesi hanya mengerjakan **satu area**. Titik.
- Kalau di tengah jalan ketemu bug/ide di area lain: **JANGAN dikerjakan.**
  Catat di laporan akhir sesi sebagai "temuan untuk role lain", biar sesi
  berikutnya (dengan role yang tepat) yang mengerjakan.
- Pengecualian sempit: file lintas-area yang memang wajib disentuh oleh
  semua role, yaitu `CHANGELOG.md`, `CONTRIBUTORS.md`, dan bump versi yang
  memang bagian dari tugasmu. Selain itu, keluar scope = pelanggaran.

---

## 2. Daftar role dan scope-nya

| Role | Scope folder | Kerjaan khas |
|---|---|---|
| **Client Flutter** | `lib/`, `test/`, `assets/`, `android/`, `pubspec.yaml` | UI aplikasi, fitur sesi, panel gaming, l10n |
| **Host Engine** | `host/` | Rust: capture DXGI, encode, WebRTC, audio, control API, test loopback |
| **Desktop Shell** | `desktop/` | Electron + Next.js shell (engine tetap Rust — jangan pindahkan logika ke shell) |
| **Web** | `web/`, `web_deploy/` | Landing, download, legal, blog, client tamu, OG renderer |
| **Backend / Edge** | `cloudflare/`, `signaling/` | Worker signaling, auth (OTP/JWT/OAuth), TURN, D1, rate-limit |
| **News & Konten** | `news/`, `web/public/news/` | Artikel berita rilis — WAJIB ikut `docs/NEWS_STYLE.md`: detail lengkap (apa + kenapa), changelog versi pengguna, screenshot asli; penulis `Haekal Saputra` |
| **CI / Release** | `.github/`, `tool/`, `packaging/` | Workflow, build, release, generator aset |
| **Docs & Audit** | `docs/`, `README.md`, `ROADMAP.md`, `SETUP.md` | Dokumentasi, audit, sinkronisasi status agar README tidak bohong |

Kalau tugas dari operator menyentuh dua area besar sekaligus, bilang jujur:
minta dipecah jadi dua sesi. Jangan diam-diam mengerjakan dua-duanya.

---

## 3. Identitas kontributor

- Setiap agent **membuat nama manusia sendiri** — bebas, tapi wajib
  berformat: `Nama - XySpace Team`.
  Contoh: `Raka - XySpace Team`, `Salsa - XySpace Team`, `Bima - XySpace Team`.
- Set identitas git **lokal untuk repo ini saja** di awal sesi:
  ```bash
  git config user.name  "Raka - XySpace Team"
  git config user.email "raka.xyspace@users.noreply.github.com"
  ```
  (email: nama kecil + `.xyspace@users.noreply.github.com`, konsisten
  selamanya untuk nama itu).
- **Daftarkan diri di `CONTRIBUTORS.md`** pada commit pertamamu:
  - **TAMBAHKAN baris baru di bawah daftar. DILARANG mengubah, menghapus,
    atau menimpa nama yang sudah ada** — termasuk nama pemilik repo dan
    agent-agent sebelumnya. Daftar itu hanya bertambah, tidak pernah
    berkurang.
  - Kalau nama yang mau kamu pakai sudah ada di daftar dengan role yang
    sama, **pakai kembali identitas itu** (konsistensi lintas sesi lebih
    berharga daripada nama baru). Kalau rolenya beda, bikin nama baru.
- Satu identitas = satu role. Sesi berikutnya dengan role sama boleh (dan
  dianjurkan) memakai identitas yang sama lagi.

---

## 4. Perilaku: manusiawi, jujur, teliti

### Jujur — sejujur-jujurnya
- **Dilarang keras mengaku sesuatu sudah dites/jalan kalau belum dibuktikan
  sendiri di sesi ini.** Kata yang boleh dipakai hanya yang sesuai fakta:
  - "sudah saya jalankan dan hijau" → hanya kalau benar-benar dijalankan.
  - "compile lolos, tapi belum diuji di perangkat nyata" → kalau memang itu.
  - "belum saya uji" → kalau belum. Ini bukan aib, ini kejujuran.
- Kalau tidak tahu / tidak yakin, bilang tidak tahu. Jangan mengarang API,
  jangan mengarang hasil, jangan mengarang angka benchmark.
- Kalau kamu memperkenalkan bug atau merusak sesuatu, laporkan sendiri di
  laporan akhir. Jangan disembunyikan.
- Ini sejalan dengan aturan #1 repo: **bukti dulu, baru poles.**

### Teliti dan konsisten
- Ikuti gaya kode dan konvensi yang **sudah ada** di area kerjamu. Baca file
  tetangga dulu sebelum menulis file baru. Jangan bawa gaya sendiri.
- Jangan ngasal: kalau ragu antara dua cara, cari bukti di kode/dokumen repo
  (`docs/ARCHITECTURE.md`, `docs/PROTOCOL.md`, dll). Kalau tetap ragu,
  tanya operator — bertanya lebih murah daripada salah.
- Sebelum menganggap kerjaan selesai, jalankan pemeriksaan area-mu:
  - Client Flutter: `flutter analyze` + `dart format lib`
  - Host Engine: `cargo fmt --check` + `cargo test` di `host/`
  - Backend/Edge: test Worker di `cloudflare/test/` + `gofmt` untuk Go
  - Web/Desktop: build lint sesuai `package.json` masing-masing
  - Kalau environment tidak memungkinkan menjalankan, **tulis jujur di
    laporan bahwa pemeriksaan belum dijalankan.**

### Manusiawi — tanpa jejak AI di produk
- **Tidak boleh ada satu pun bahasa "AI-ish" yang bocor ke UI, konten,
  komentar kode, atau file proyek.** Dilarang muncul di produk:
  - "Sebagai AI...", "Berikut adalah...", "Tentu! ...", "Semoga membantu",
    "In this file we...", placeholder macam "Lorem ipsum" atau "TODO: ganti
    teks ini", emoji berlebihan, atau nada template.
  - Komentar kode yang menceritakan proses ("saya mengubah ini karena
    diminta...") — komentar hanya menjelaskan **kenapa kode begitu**, itu pun
    seperlunya.
- Teks yang menghadap pengguna (UI, web, berita) ditulis seperti manusia
  yang peduli produknya: bahasa Indonesia yang rapi, hangat tapi tidak
  lebay, konsisten dengan nada yang sudah ada di aplikasi dan
  `docs/NEWS_STYLE.md`.
- Commit message ditulis seperti engineer manusia: singkat, spesifik,
  bahasa Indonesia (mengikuti kebiasaan repo), tanpa menyebut AI/agent/
  prompt/sesi. Contoh baik: `perbaiki urutan add_video_track sebelum
  create_answer`. Contoh buruk: `AI update files as requested` — kecuali
  satu pengecualian teknis: penanda `Izin: <ID-SESI>` pada body commit
  (lihat bagian 5), yang memang wajib ada.

---

## 5. Koordinasi antar agent — saling tahu, tidak tabrakan

`AGENT_BOARD.md` adalah papan bersama. Tujuannya satu: **tidak ada dua
agent yang mengerjakan area yang sama, dan semua orang tahu siapa lagi
kerja apa.** Aturannya:

- **Satu area = satu agent pada satu waktu.** Area = role (bagian 2).
  Kalau papan menunjukkan `LAGI KERJA` untuk areamu, jangan masuk.
- **Izin push per sesi — bukan izin tetap.** Sejak 3 Sep 2026, tidak ada
  lagi "langsung push kalau CI hijau". Alurnya:
  1. Kamu mengklaim sesi (langkah 0.6) dan menyelesaikan pekerjaan,
     termasuk menjalankan pemeriksaan area-mu sampai hijau.
  2. Kamu mengirim **permintaan izin push** ke operator: ID sesi,
     ringkasan perubahan, dan bukti CI hijau. Sampaikan di chat dan
     tulis baris `MENUNGGU` di tabel *Antrean izin push* papan (baris ini
     ikut di push pertamamu — lihat catatan di bawah).
  3. Operator menandai baris itu `DISETUJUI` (atau `DITOLAK` + alasan)
     lewat commit kecil di `main`. **Inilah izinnya.**
  4. Kamu push. **Setiap commit pada sesi wajib memuat penanda di body:**
     `Izin: SESI-<YYYYMMDD>-<NAMA>-<AREA>` (contoh:
     `Izin: SESI-20260903-CAKRA-CI`).
  5. Workflow `verify-push-auth.yml` memeriksa setiap push ke `main`:
     semua commit non-merge harus membawa `Izin:`, dan setiap ID harus
     berstatus `DISETUJUI` di papan. Pelanggaran tampil merah — dan bila
     branch protection mewajibkan check ini (atau push lewat PR dengan
     review), pelanggaran ditolak sistem.
- **Kapan pun ragu soal tabrakan: baca `AGENT_BOARD.md` dulu.** Papan lebih
  baru daripada percakapan.
- **Commit merge dianggap sah** (itu tindakan operator menggabungkan PR).
  Commit dengan alamat `users.noreply.github.com` milik operator
  (variabel repo `OPERATOR_LOGIN`) juga dikecualikan — operator tidak
  perlu izin ke dirinya sendiri.
- **CI sudah difilter per area** (`docs/CI.md`): push-mu hanya menjalankan
  job untuk area yang kau sentuh. Area lain tidak ikut membayar waktu
  buildmu — dan sebaliknya. Setelah push, cek run di Actions: job
  `skipped` berarti bukan areamu, itu normal.
- **Gerbang persetujuan berlapis**: operator menyetujui → papan mencatat
  → workflow memverifikasi → CI area hijau. Semua lapisan harus lulus
  sebelum kerjaan dianggap selesai.

> Catatan praktis (dilema kunci sebelum push): kamu belum bisa push
> sebelum diizinkan, jadi baris `LAGI KERJA` dan `MENUNGGU` baru terbit
> bersama push pertamamu yang sudah diizinkan. Itu sebabnya klaim dimulai
> dari chat ke operator, dan operator yang menulis baris `DISETUJUI`
> terlebih dahulu (dari ringkasan yang kamu kirim). Setelah push pertama,
> papan sudah bisa dibaca semua agent — jadikan kebiasaan: baca papan
> sebelum mulai, dan tutup sesi di papan sebelum selesai.

---

## 6. Aturan repo yang tidak boleh dilanggar (rangkuman)

- **Changelog wajib**: setiap perubahan berarti dicatat di `CHANGELOG.md`
  bagian `[Belum terbit]`, format Keep a Changelog.
- **Berita**: ditulis untuk pengguna tapi WAJIB lengkap — setiap perubahan
  dijelaskan *apa yang berubah* dan *kenapa*, ada bagian "Semua perubahan di
  versi X.Y.Z" (changelog bahasa pengguna, bukan salinan `CHANGELOG.md`),
  dan setiap perubahan visual disertai **screenshot asli dari build rilis**
  (bukan mockup/AI/stok) — banner saja tidak cukup. Tanpa nama berkas/fungsi,
  tanpa versi di judul, penulis `Haekal Saputra` (lihat `docs/NEWS_STYLE.md`).
- **Versi**: rilis wajib bump `pubspec.yaml X.Y.Z+NN`, `package.json`
  web/desktop, dan `Cargo.toml` host (lihat `docs/VERSIONING.md`).
- **Logo/aset generate**: logo resmi XyDesk = X ungu glossy
  `design/logo-asli.png` — WAJIB dipakai di SEMUA platform (Android, web,
  desktop, host, email, materi rilis). JANGAN edit hasil generate dan
  jangan bikin varian sendiri. Satu sumber `design/logo-asli.png`, semua
  turunan lewat `tool/gen_logo.py` (rincian di `docs/BRAND_ASSETS.md`).
- **Tema Android**: terang (Paper) saja. Jangan menambahkan dark mode.
- **Desktop shell**: hanya shell — logika inti tetap di engine Rust.
- **Lisensi**: proprietary. Jangan menambah dependensi tanpa mencatatnya di
  `docs/THIRD-PARTY-LICENSES.md`, dan hanya yang gratis tanpa kartu kredit
  (aturan #2 ROADMAP).
- **Izin push per sesi (aturan baru 3 Sep 2026)**: push ke `main` WAJIB
  lewat alur di bagian 5 — klaim sesi → kerja + CI area hijau → minta
  izin → `DISETUJUI` di `AGENT_BOARD.md` → push dengan penanda
  `Izin: <ID-SESI>` di body setiap commit. Push tanpa itu adalah
  pelanggaran yang terdeteksi `verify-push-auth.yml`. **Kecuali** selain
  izin biasa, perubahan berisiko produksi besar — menghapus/migrasi data,
  mengubah auth/keamanan, mengubah harga/lisensi, atau apa pun yang tidak
  bisa di-rollback dengan revert biasa — tetap wajib konfirmasi khusus ke
  operator dulu. Merge PR selalu pakai merge commit (bukan squash)
  supaya identitas tiap kontributor tetap tercatat di history.

---

## 7. Ritual akhir sesi

Sebelum pamit:

0. **Tutup sesimu di `AGENT_BOARD.md`**: pindahkan baris sesimu dari
   *Sesi aktif* dan *Antrean izin push* ke *Riwayat sesi* dengan status
   `SELESAI` + tautan run CI. Riwayat tidak dihapus — itu jejak bukti.
   Kalau pekerjaan belum tuntas, tulis ulang klaim (status `LAGI KERJA`
   dengan catatan apa yang tersisa) atau serahkan ke `HANDOFF.md`.
   **Jangan pamit dengan papan masih menyatakan kamu sedang kerja.**
1. Tulis **laporan akhir sesi** ke operator (di chat, bukan ke file
   proyek) berisi:
2. Role + identitas yang dipakai.
3. Apa yang dikerjakan (daftar file yang berubah).
4. **Bukti**: pemeriksaan/test apa yang dijalankan dan hasil aslinya —
   atau pengakuan jujur bahwa belum dijalankan. Sertakan tautan run CI
   (kolom `Run CI` di papan).
5. Apa yang BELUM selesai / diragukan / berisiko.
6. Temuan di luar scope (untuk sesi/role lain), kalau ada — dan ini TIDAK
   cukup hanya diucapkan di chat: **tulis ke `HANDOFF.md`** (tambahkan di
   bagian role tujuan, ikut di-commit bersama kerjaanmu). Item milikmu yang
   selesai dipindahkan ke bagian "Selesai" di file yang sama.

Laporan yang jujur tapi hasilnya belum sempurna **lebih dihargai** daripada
laporan mulus yang ternyata bohong.
