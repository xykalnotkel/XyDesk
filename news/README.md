# XyDesk News — Worker + D1 (news.xystudio.my.id)

Umpan berita publik untuk Android, Desktop, dan Web. Terpisah total dari
Worker signaling.

## Endpoint publik

| Metode | Path | Fungsi |
|---|---|---|
| GET | `/api/news?category=…&limit=…` | Daftar berita (terbit) |
| GET | `/api/news/<slug>` | Detail + komentar |
| POST | `/api/news/<slug>/like` | Toggle like (body: `fp`) |
| GET/POST | `/api/news/<slug>/comments` | Daftar / kirim komentar (bisa `parentId` untuk balasan) |
| POST | `/api/subscribe` | Langganan email berita (body: `email`) |
| GET | `/n/<slug>` | Halaman berbagi OpenGraph untuk crawler |

## Menerbitkan artikel baru (ADMIN)

Setiap rilis WAJIB punya artikel berita.

**Baca dulu [`docs/NEWS_STYLE.md`](../docs/NEWS_STYLE.md) sebelum menulis.**
Berita bukan changelog: tulis dampaknya untuk pengguna, bukan daftar
pekerjaan. Tidak ada nama berkas, nama modul, atau nomor versi di judul.
Penulis artikel selalu `Haekal Saputra` (identitas resmi; label `XySpace`
tampil otomatis sebagai badge di klien).

**Pembagian penulisan (sejak 3 Sep 2026):** tiap agent menulis bahan
artikel untuk kerjanya sendiri — blok dampak pengguna + screenshot asli,
gaya NEWS_STYLE — saat sesinya ditutup. Saat rilis, role CI/Release
menyatukan bahan semua agent menjadi **SATU artikel rilis**; tidak
menerbitkan banyak artikel per rilis.

Terbitkan lewat endpoint admin —
**slug dibuat otomatis sebagai HASH acak** (mis. `p-d5b4512f7d17`), tidak
menebak urutan dan tidak membocorkan judul di URL:

```bash
curl -X POST "https://news.xystudio.my.id/api/admin/publish" \
  -H "Content-Type: application/json" \
  -H "x-admin-token: <ADMIN_TOKEN>" \
  -d '{
    "title": "Judul rilis",
    "excerpt": "Ringkasan 1-2 kalimat untuk kartu + OG",
    "content": "Isi panjang — paragraf dipisah baris kosong.",
    "cover": "https://app.xystudio.my.id/news/covers/<file>.jpg",
    "category": "rilis|teknik|umum",
    "author": "Haekal Saputra"
  }'
```

> ⚠️ **Artikel changelog rilis WAJIB mengirim `slug` sendiri.** Footer web
> dan layar "Tentang" menautkan versi ke `changelog-v<major>-<minor>-<patch>`
> (`web/src/version.ts` → `CHANGELOG_SLUG`). Kalau field `slug` tidak
> dikirim, slug jatuh ke hash acak `p-…` dan tautan versi itu menunjuk ke
> artikel yang tidak ada (404) — persis yang terjadi pada rilis 6.4.0.
> Satu-satunya slug yang boleh dipilih sendiri adalah pola
> `changelog-vX-Y-Z` (mis. `changelog-v6-4-1`); slug lain tetap diacak
> worker:
>
> ```bash
> curl -X POST "https://news.xystudio.my.id/api/admin/publish" \
>   -H "Content-Type: application/json" \
>   -H "x-admin-token: <ADMIN_TOKEN>" \
>   -d '{
>     "title": "Judul rilis",
>     "excerpt": "Ringkasan 1-2 kalimat untuk kartu + OG",
>     "content": "Isi panjang — paragraf dipisah baris kosong.",
>     "cover": "https://app.xystudio.my.id/news/covers/<file>.jpg",
>     "category": "rilis",
>     "author": "Haekal Saputra",
>     "slug": "changelog-v6-4-1"
>   }'
> ```

### Dua jalur admin (sejak 3 Sep 2026)

Admin (publish artikel & badge resmi komentar) menerima **dua** bukti:

1. **`x-admin-token: <ADMIN_TOKEN>`** — jalur lama, tetap sah.
2. **`x-admin-google-token: <id_token>`** — Google ID token (OpenID). Worker
   memverifikasi signature + audience langsung ke JWKS Google, lalu hanya
   menerima bila email token == `FOUNDER_EMAIL`. Founder tidak perlu lagi
   menempel `ADMIN_TOKEN` manual — cukup masuk dengan Google. CORS untuk
   header ini sudah dibuka.

```bash
curl -X POST "https://news.xystudio.my.id/api/admin/publish" \
  -H "Content-Type: application/json" \
  -H "x-admin-google-token: <ID_TOKEN_GOOGLE>" \
  -d '{"title":"Judul rilis","content":"Isi rilis lengkap.","slug":"changelog-v6-4-1"}'
```

Saat terbit, worker **otomatis** (asinkron, `waitUntil`):
1. Kirim push OneSignal ke semua pengguna opt-in (judul + gambar sampul).
2. Kirim email Resend ke seluruh `subscribers` (dari `news@mail.xystudio.my.id`).

Secret Worker (via `wrangler secret put`): `ADMIN_TOKEN`, `ONESIGNAL_APP_ID`,
`ONESIGNAL_API_KEY`, `RESEND_API_KEY`, `EMAIL_FROM`.
Jalur Google butuh dua secret tambahan: `GOOGLE_CLIENT_ID` (audience token
OAuth web; bisa daftar pisah-koma bila Android ikut) dan `FOUNDER_EMAIL`
(email Google founder yang diizinkan). Tanpa keduanya jalur Google nonaktif
(gagal-tertutup); jalur `ADMIN_TOKEN` tetap bekerja.

## Sampul berita

Sampul (1424×752) disimpan di `web/public/news/covers/` dan ikut ter-deploy
ke `app.xystudio.my.id/news/covers/<file>.jpg` — jangan pakai URL luar.

## Skema

`news/schema.sql` idempoten. Migrasi tambahan (mis. kolom baru) lewat
`news/migrate.mjs` (ALTER TABLE aman-ulang) atau langsung `wrangler d1 execute`.

## Aturan batas (anti spam)

- Like: idempoten per `fp` (toggle).
- Komentar: maks 5 per 10 menit per `fp`, panjang ≤ 1000, tag HTML dibuang.
- Balasan: satu tingkat (`parentId` divalidasi milik artikel yang sama).
- Input sanitasi di semua jalur.
