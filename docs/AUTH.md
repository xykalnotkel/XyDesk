# XyDesk Auth — integrasi produksi

Autentikasi XyDesk memakai **Cloudflare Worker + Durable Object** untuk backend
dan aplikasi Flutter root (`lib/`) sebagai client. Alur mock lama sudah tidak
dipakai.

## Endpoint

| Method | Path | Body/header | Hasil |
|---|---|---|---|
| `POST` | `/auth/request-otp` | `{ "email": "..." }` | `{ ok, expires_in, resend_in }` |
| `POST` | `/auth/verify-otp` | `{ "email": "...", "otp": "123456" }` | `{ token, user }` |
| `POST` | `/auth/google` | `{ "id_token": "..." }` | `{ token, user }` |
| `GET` | `/auth/me` | `Authorization: Bearer <JWT>` | `{ user }` |
| `OPTIONS` | `/auth/*` | preflight CORS | `204` |

- JWT memakai HS256, berlaku 30 hari, dan ditandatangani `AUTH_SECRET`
  (fallback kompatibilitas: `XYDESK_SECRET`).
- OTP berisi 6 digit, berlaku 10 menit, cooldown kirim ulang 60 detik, maksimal
  5 percobaan, sekali pakai, dan hanya hash-nya yang disimpan.
- Produksi mengembalikan kegagalan bila email tidak benar-benar terkirim. Record
  OTP yang gagal dikirim langsung dihapus sehingga tidak ada kode yang tak
  mungkin diterima pengguna.

## Alur Flutter

1. `AuthScreen` meminta OTP melalui Worker atau memperoleh ID token dari
   `google_sign_in`.
2. Worker memverifikasi kredensial dan mengembalikan JWT XyDesk.
3. JWT disimpan dengan `flutter_secure_storage`; JWT tidak disimpan di
   `SharedPreferences` dan tidak dicetak ke log.
4. Saat aplikasi dibuka kembali, JWT dibaca sebelum `runApp`, lalu divalidasi
   melalui `/auth/me`.
   - respons definitif `401`/`404`: JWT dan metadata akun lokal dihapus;
   - timeout, server `5xx`, atau jaringan sementara putus: sesi lokal
     dipertahankan agar pengguna tidak otomatis keluar karena gangguan sesaat.
5. Sign-out mencoba keluar dari provider Google, menghapus JWT secure storage,
   lalu membersihkan metadata sesi lokal.

Mode tamu tetap lokal dan tidak menghasilkan JWT.

## Konfigurasi aplikasi Flutter

Konfigurasi publik ditanam saat build:

```bash
flutter build apk --release \
  --dart-define=XYDESK_API_URL=https://signal.xystudio.my.id \
  --dart-define=GOOGLE_CLIENT_ID=<web-oauth-client-id>
```

`XYDESK_API_URL` sudah memiliki nilai default produksi. OAuth client ID bukan
secret, tetapi dikelola sebagai GitHub Actions repository variable agar build
dev dan produksi dapat memakai project berbeda.

### Google Sign-In Android

Implementasi Android mengirim OAuth **Web client ID** sebagai `serverClientId`.
Selain itu, Google Cloud Console tetap harus memiliki OAuth client tipe Android
dengan:

- package/application ID: `com.xystudio.xydesk`;
- SHA-1 (dan sebaiknya SHA-256) dari keystore yang menandatangani APK produksi.

Fingerprint harus berasal dari keystore yang sama dengan GitHub Actions secrets
`KEYSTORE_BASE64`, `KEY_ALIAS`, dan password signing. Jika CI memakai fallback
debug signing, fingerprint debug runner tidak stabil untuk distribusi produksi;
konfigurasikan keystore rilis sebelum menerbitkan APK.

Tombol Google kustom saat ini ditujukan untuk Android. Di Web, paket Google
mewajibkan tombol Google Identity Services yang dirender provider; sampai UI
tersebut ditambahkan, pengguna Web/Windows harus memakai OTP email.

## Konfigurasi Worker dan GitHub Actions

### GitHub Actions secrets

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `XYDESK_SECRET`
- `ADMIN_SECRET`
- `AUTH_SECRET`
- `RESEND_API_KEY`
- secrets signing Android bila APK produksi ditandatangani

### GitHub Actions repository variables

- `GOOGLE_CLIENT_ID`
- `RESEND_FROM`, misalnya `XyDesk <auth@domain-terverifikasi.example>`

Workflow deploy memasang `AUTH_SECRET`, `RESEND_API_KEY`, `GOOGLE_CLIENT_ID`,
dan `RESEND_FROM` sebagai Worker secrets sebelum menjalankan
`wrangler deploy`. Nilai kosong membuat deploy gagal lebih awal.

`RESEND_FROM` harus memakai domain yang sudah diverifikasi di Resend. Jangan
memakai `onboarding@resend.dev` untuk pengiriman produksi umum.

## CORS

Semua respons `/auth/*`, termasuk error, memperoleh header CORS. Preflight
`OPTIONS` mengembalikan `204` dan mengizinkan `GET`, `POST`, `OPTIONS`, header
`Authorization`, serta `Content-Type`.

Worker variable opsional `CORS_ORIGINS` menerima allowlist origin yang
dipisahkan koma. Tanpa nilai tersebut default-nya `*`. Auth memakai bearer token
dan tidak memakai browser credentials/cookie. Untuk deployment Web yang origin-
nya sudah tetap, sebaiknya isi allowlist eksplisit.

## Keamanan Google backend

Worker memverifikasi signature RS256 dengan Google JWKS serta memeriksa
`aud`, `iss`, `exp`, `email_verified`, dan `sub`. Akun disambungkan ke `sub`
Google yang stabil; percobaan memakai identitas Google berbeda untuk email yang
sudah terikat ditolak dengan `identity-conflict`.

Tanpa `GOOGLE_CLIENT_ID`, endpoint mengembalikan
`503 google-not-configured`. Tanpa secret auth, endpoint auth mengembalikan
`503 auth-not-configured`.

## Validasi

```bash
# Dijalankan oleh GitHub Actions, bukan perangkat pengguna:
flutter pub get
flutter analyze --fatal-infos
flutter test --reporter compact

cd cloudflare
npm ci
# Workflow menyalakan wrangler dev lalu menjalankan:
node test/signaling.test.mjs
node test/auth.test.mjs
```

Jangan menguji OTP produksi dengan alamat acak: permintaan yang berhasil akan
mengirim email sungguhan dan memakai kuota Resend.
