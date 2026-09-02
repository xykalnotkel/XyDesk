# HANDOFF — Catatan Lintas Role

Papan serah-terima antar sesi agent. **Setiap sesi WAJIB**:
1. Di awal: baca bagian role-mu, kerjakan yang bisa kamu kerjakan.
2. Di akhir: tambahkan temuan baru untuk role lain, dan pindahkan item yang
   kamu selesaikan ke bagian "Selesai" (JANGAN dihapus — sejarah itu bukti).

> File ini mencatat **temuan lintas role**. Untuk keadaan *real-time* —
> siapa lagi mengunci area apa, push siapa yang sudah diizinkan — baca
> `AGENT_BOARD.md`, bukan percakapan lama.

Format item: `- [ ] (dari <Identitas>, <tanggal>) — <apa> — <kenapa/konteks>`

---

## Untuk: Client Flutter

- [ ] (dari Danu - XySpace Team, 2026-09-02) — **Rebrand**: logo X baru sudah
  masuk lewat `design/logo-asli.png` + `tool/gen_logo.py` (ikon launcher,
  splash, aset Flutter ikut lahir ulang). Verifikasi hasilnya di build
  Android nyata. Selaraskan juga token ungu `lib/core/tokens.dart` dengan
  web: accent `#7C3AED`, deep `#5B21B6`, lavender `#A78BFA`.
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Avatar penulis resmi berita:
  web kini memakai foto founder (`web/public/team/founder.jpg`, live di
  `https://app.xystudio.my.id/team/founder.jpg`) menggantikan badge logo X.
  Samakan di Flutter (boleh load dari URL itu).
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Render gambar inline
  `![keterangan](url)` di `lib/features/news/news_detail_page.dart` —
  web & desktop sudah; ini blocker terakhir sebelum berita bergambar boleh
  terbit (`docs/NEWS_STYLE.md` bag. 3). Hanya URL `app.xystudio.my.id`.
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Avatar komentar berita:
  samakan dengan web — official pakai logo XyDesk, selainnya
  `https://api.dicebear.com/9.x/adventurer/svg?seed=<author>` (seed = nama
  penulis, jadi wajah konsisten lintas platform tanpa perubahan backend).
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Nama komentator: web kini
  membuat nama manusia acak (deterministik dari fingerprint, daftar nama di
  `web/src/news.ts`) menggantikan `tamu-xxxx`. Samakan derivasinya di
  Flutter supaya perangkat yang sama tetap satu identitas.

## Untuk: Desktop Shell

- [ ] (dari Galih - XySpace Team, 2026-09-03) — Control API kini punya aksi
  `video-bitrate` (field `bitrate_mbps`, 1–50) dan `/status` melaporkan
  `targetBitrateBps`. Tambahkan kontrol di panel (input Mbps + tampilkan
  nilai aktif) — endpoint-nya sudah jadi & teruji, UI-nya belum.
- [ ] (dari Danu - XySpace Team, 2026-09-02) — **Rebrand**: ikon Windows
  (`packaging/windows/xydesk.ico`) sudah lahir ulang dari logo baru —
  verifikasi installer CI berikutnya memakai ikon itu. Selaraskan juga
  warna aksen shell dan avatar penulis resmi berita (foto founder, lihat
  catatan Client Flutter).
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Waktu komentar berita di web
  kini relatif ("5 menit lalu"); samakan di Flutter dan Desktop
  (`formatRelativeTime` di `web/src/news.ts` sebagai acuan). Avatar
  penulis resmi juga kini bulat penuh.
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Form komentar berita: pindah
  ke BAWAH daftar komentar + auto-scroll saat "Balas" (web sudah; alasan:
  input di atas menyulitkan setelah membaca komentar).
- [ ] (dari Danu - XySpace Team, 2026-09-02) — Avatar + nama manusia
  komentar: ikuti pola web (`web/src/news.ts` — `newsDisplayName`,
  `newsAvatarUrl`).

## Untuk: CI / Release

- [ ] (dari Danu - XySpace Team, 2026-09-02) — Pin Node ≥ 22 untuk tooling
  wrangler terbaru: compat date `2026-08-17` butuh wrangler baru, wrangler
  baru menolak Node 20. Hari ini uji lokal terpaksa memakai compat date
  lama.

## Untuk: Web

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — Push `0081742` (keyboard
  virtual, panel gaming) membuat run `verify-push-auth.yml` MERAH: commit
  tidak memuat penanda `Izin: <ID-SESI>` di body. Aturan baru (lihat
  `AGENT.md` bagian 5): klaim sesi → minta persetujuan operator di
  `AGENT_BOARD.md` → push dengan `Izin: ...` di body. Commit tetap masuk,
  tapi audit mencatatnya sebagai pelanggaran.

## Untuk: Backend / Edge

- [ ] (dari Danu - XySpace Team, 2026-09-02) — Template email berita
  (`news/src/worker.js`) memakai `badge-xyspace.png` dan menampilkan logo
  lama sebagai identitas pengirim. `logo.png` di web sudah otomatis berganti
  (URL sama, isi baru), tapi `badge-xyspace.png` TIDAK dihasilkan
  `tool/gen_logo.py` — cek asalnya, regenerasi dengan brand baru, dan
  pertimbangkan foto founder untuk blok penulis email.

## Untuk: News & Konten

- [ ] (dari Sena - XySpace Team, 2026-09-02) — Setelah Flutter selesai
  merender gambar inline: artikel rilis berikutnya wajib memakai format
  baru `docs/NEWS_STYLE.md` (apa+kenapa, changelog pengguna, screenshot di
  `web/public/news/shots/`).

## Untuk: Host Engine

- [ ] (dari Cakra - XySpace Team, 2026-09-03) — Push `f12dace` (bitrate
  live via control API) membuat run `verify-push-auth.yml` MERAH: commit
  tidak memuat penanda `Izin: <ID-SESI>` di body. Aturan baru: klaim
  sesi → persetujuan operator di `AGENT_BOARD.md` → push dengan penanda
  `Izin: ...` di body commit.

## Untuk: Docs & Audit

_(kosong)_

---

## Selesai

- [x] (dari Galih - XySpace Team, 2026-09-03) — `nvenc.rs`: `ok()` hanya
  menulis "NVENC status {n}" tanpa nama error — log fallback ke openh264
  terbaca angka, bukan penyebab. Dipetakan `status_name`/`status_hint` di
  `nvenc_config.rs` (0–26 dari nvEncodeAPI.h) + test. Sekalian perakit
  `build_config`/`build_init` dipindah & dikunci uji; VBV dikecilkan dari
  `bitrate/2` ke 1 frame.
- [x] (dari Danu, 2026-09-02) — 500 semua deep link web produksi —
  binding `ASSETS` hilang di `web_deploy/wrangler.toml`. Diperbaiki Danu,
  commit `899e4d1`, diverifikasi live.
