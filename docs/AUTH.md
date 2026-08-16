# XyDesk Auth — autentikasi asli (Cloudflare Worker, gratis)

Auth XyDesk berjalan penuh di **Cloudflare Worker + Durable Object**, tanpa
VM/VPS, tanpa kartu kredit. Menggantikan "Google tiruan" + OTP palsu di
AuthScreen.

## Endpoint

| Method | Path | Body | Hasil |
|---|---|---|---|
| POST | `/auth/request-otp` | `{ email }` | `{ ok, expires_in, resend_in }` |
| POST | `/auth/verify-otp` | `{ email, otp }` | `{ token, user }` |
| POST | `/auth/google` | `{ id_token }` | `{ token, user }` |
| GET | `/auth/me` | (header `Authorization: Bearer`) | `{ user }` |

- **Token** = JWT (HS256) berumur 30 hari, ditandatangani `AUTH_SECRET` (atau
  `XYDESK_SECRET`).
- **OTP** 6 digit, disimpan **hashed** (SHA-256 + secret), cooldown kirim ulang
  60 dtk, maks 5 percobaan, kedaluwarsa 10 menit, **sekali pakai**.

## Alur (client → server)

```
request-otp ──(email)──▶ Worker/AuthStore: buat OTP, simpan hash
   (kirim OTP via email — lihat "Pengiriman OTP" di bawah)
verify-otp ──(email, otp)──▶ cocok → buat user → kembalikan JWT
auth/me ──(Bearer JWT)──▶ profil user
```

## Keamanan (jujur)

- OTP & password tidak pernah disimpan polos; JWT stateless (tanpa tabel sesi).
- **Pengiriman OTP belum tersambung ke layanan email** (gratis & tanpa kartu
  itu butuh integrasi: Resend free tier / SES / Mailgun). Saat ini, di mode dev
  (`XYDESK_DEV=true`) OTP dikembalikan di respons (`dev_otp`) untuk pengujian.
  Untuk produksi, sambungkan pengiriman email di `requestOtp` (authstore.js).

## Google OAuth asli

1. Buat project di [Google Cloud Console](https://console.cloud.google.com)
   (gratis, tanpa kartu) → Credentials → OAuth client ID (Android/Web).
2. Simpan client ID sebagai secret Worker:
   ```bash
   npx wrangler secret put GOOGLE_CLIENT_ID
   ```
3. Di app Flutter, pakai `google_sign_in` untuk mendapat `id_token`, kirim ke
   `/auth/google` (lihat `client/lib/auth/auth_service.dart`).

Tanpa `GOOGLE_CLIENT_ID`, endpoint mengembalikan `503 google-not-configured`.

## Integrasi ke AuthScreen (Flutter)

```dart
final auth = AuthService(baseUrl: 'https://signal.xystudio.my.id');

// OTP:
await auth.requestOtp(email);
final session = await auth.verifyOtp(email, otp);
// simpan session.token (mis. di shared_preferences), pakai untuk sesi.

// Google:
// (google_sign_in) → idToken → await auth.signInWithGoogle(idToken);
```

## Skala

Data user/OTP disimpan di Durable Object `AuthStore` (KV storage, persisten).
Untuk skala besar, pindahkan ke **D1** (SQLite) tanpa mengubah protokol HTTP —
lihat catatan di `cloudflare/src/authstore.js`.
