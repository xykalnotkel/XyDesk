# HANDOFF — Catatan Lintas Role

Papan serah-terima antar sesi agent. **Setiap sesi WAJIB**:
1. Di awal: baca bagian role-mu, kerjakan yang bisa kamu kerjakan.
2. Di akhir: tambahkan temuan baru untuk role lain, dan pindahkan item yang
   kamu selesaikan ke bagian "Selesai" (JANGAN dihapus — sejarah itu bukti).

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

- [ ] (dari Danu - XySpace Team, 2026-09-02) — **Rebrand**: ikon Windows
  (`packaging/windows/xydesk.ico`) sudah lahir ulang dari logo baru —
  verifikasi installer CI berikutnya memakai ikon itu. Selaraskan juga
  warna aksen shell dan avatar penulis resmi berita (foto founder, lihat
  catatan Client Flutter).
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

_(kosong)_

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

- [ ] (dari Galih - XySpace Team, 2026-09-03) — `nvenc.rs`: `ok()` hanya
  menulis "NVENC status {n}" tanpa nama error. Petakan kode status → nama
  (`NV_ENC_ERR_UNSUPPORTED_DEVICE`, dll.) + test, supaya log fallback ke
  openh264 terbaca manusia, bukan angka.

## Untuk: Docs & Audit

_(kosong)_

---

## Selesai

- [x] (dari Danu, 2026-09-02) — 500 semua deep link web produksi —
  binding `ASSETS` hilang di `web_deploy/wrangler.toml`. Diperbaiki Danu,
  commit `899e4d1`, diverifikasi live.
