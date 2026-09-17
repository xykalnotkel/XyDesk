# Login admin: password + authenticator

## Migrasi tanpa kehilangan akses

1. Sebelum akun password diaktifkan, pemilik memakai login Google admin yang sudah ada untuk membuktikan identitas. Google tidak menjadi metode login permanen.
2. Pemilik memilih username 3–32 karakter (`a-z`, angka, `.`, `_`, `-`) dan password unik 14–128 karakter. Penyiapan dimulai paling lambat 10 menit sejak login Google.
3. Server membuat kunci TOTP. Masukkan kunci ke aplikasi authenticator dengan jenis berbasis waktu (SHA1, enam digit, 30 detik), atau buka tautan otpauth di perangkat yang mempunyai aplikasi authenticator. Penyiapan berlaku 10 menit.
4. Pemilik memasukkan kode authenticator. **Baru setelah kode valid**, transaksi menyimpan akun, menerbitkan sesi cookie, serta menutup login Google dan menolak semua JWT admin lama.
5. Sepuluh kode pemulihan tampil sekali. Unduh/simpan di tempat aman, terpisah dari password, lalu buka dashboard. Kode pemulihan menggantikan TOTP sekali saja; password tetap diperlukan.

Jika halaman ditutup sebelum konfirmasi, login Google masih tersedia. Tidak ada username/password/seed authenticator yang dibuatkan operator di chat. Tidak ada tombol atau endpoint publik untuk membuka kembali bootstrap setelah akun aktif. Model saat ini satu akun admin awal; bukan sistem multi-admin.

## Penyimpanan dan proteksi

- Password: PBKDF2-HMAC-SHA256 dengan salt acak 16 byte, 100.000 iterasi (batas WebCrypto Workers). Verifier kemudian diberi HMAC-SHA256 dengan pepper server `ADMIN_AUTH_KEY`. Ini pilihan sesuai batas platform, bukan klaim setara parameter Argon2id atau rekomendasi PBKDF2 yang lebih tinggi. Wajib memakai password unik yang panjang.
- Seed TOTP: acak 20 byte, disimpan terenkripsi AES-GCM dengan IV acak. Kunci berasal dari `ADMIN_AUTH_KEY`, terpisah dari secret sesi web/APK.
- Kode TOTP: jendela toleransi satu langkah sebelum/sesudah waktu server. Counter yang sudah diterima tidak dapat dipakai lagi, termasuk percobaan paralel. Setelah login/setup, tunggu kode periode berikutnya bila masuk kembali menggunakan authenticator.
- Kode pemulihan: masing-masing 128 bit acak, hanya hash yang disimpan; konsumsi dilakukan dalam transaksi agar tidak bisa dipakai ulang.
- Login dibatasi 5 percobaan per username per 15 menit dan 20 per IP per 15 menit, termasuk percobaan berhasil. Verifikasi Turnstile terjadi sebelum hashing password. Setup/start dan confirm dibatasi masing-masing 5 percobaan per pemilik per 15 menit. Identitas IP pada limiter di-hash dengan key server.
- Sesi: token acak 256 bit, hanya hash disimpan server. Cookie `__Host-xydesk_admin`, `Secure`, `HttpOnly`, `SameSite=Strict`, `Path=/`, berlaku satu jam. Cookie host-only untuk signal.xydesk.my.id. Token password tidak dikirim dalam JSON atau localStorage.
- Semua POST admin memeriksa Origin admin. CORS ber-credentials hanya diberikan kepada origin admin yang diizinkan (default `https://admin.xydesk.my.id`), tidak memakai wildcard. JSON dibatasi 8 KiB. Logout mencabut sesi di storage dan menghapus cookie.
- Audit mencatat setup dan login berhasil (termasuk recovery), tanpa password, seed TOTP, token sesi, atau kode pemulihan.

## Konfigurasi produksi

- `ADMIN_AUTH_KEY`: secret acak minimal 32 karakter, khusus penyimpanan/verifier admin. Jangan dimasukkan ke frontend, source, screenshot, atau log. Jangan mengganti/menghapusnya setelah aktivasi tanpa rencana pemulihan: seed TOTP dan verifier memakai key ini.
- `TURNSTILE_SECRET` + sitekey publik admin tetap diperlukan.
- `ADMIN_GOOGLE_CLIENT_ID` hanya untuk bootstrap; saat akun password sudah aktif, `/admin/login` menolak Google dengan HTTP 410. Script Google hanya dimuat ketika layar bootstrap diperlukan.
- `AUTH_SECRET`, `GOOGLE_CLIENT_ID`, dan secret web/APK tidak dirotasi oleh perubahan ini.

`GET /admin/auth/config` hanya mengungkap status aktivasi, bukan username atau data akun. Bootstrap memerlukan Google JWT admin allowlist yang valid dan masih baru; cookie password tidak memberi akses untuk mengulangi setup.

## Pemulihan dan batas saat ini

- Authenticator hilang: gunakan password dan satu kode pemulihan. Jangan berikan kode kepada siapa pun.
- Password terlupa atau authenticator serta seluruh kode pemulihan hilang: belum ada reset mandiri. Perlu prosedur pemulihan manual oleh pemilik akun infrastruktur dengan persetujuan eksplisit, bukan menghidupkan bypass Google.
- UI ganti password, enrollment ulang TOTP, dan regenerasi kode pemulihan belum tersedia pada paket ini. Jangan menganggap fitur tersebut sudah ada.
- Baris session kedaluwarsa dibersihkan saat diakses; belum ada job berkala pembersih semua limiter/session lama.
- Tidak ada bypass captcha atau TOTP untuk produksi. Bootstrap/captcha ditirukan hanya dalam tes lokal.

## Verifikasi

`cloudflare npm test` mencakup vektor RFC6238, hashing/salt, penyimpanan terenkripsi, replay TOTP, recovery sekali pakai, konflik paralel, expiry, rate limit, CSRF, cookie flags, dan pemutusan JWT/Google lama. `npm run test:runtime` menguji crypto dan transaksi pada runtime SQLite lokal.

Pemeriksaan browser lokal menjalankan build panel terhadap runtime backend lokal: setup → konfirmasi TOTP → kode pemulihan → cookie HttpOnly → reload → logout → login recovery → replay ditolak, tanpa pageerror. Proof bootstrap dan captcha ditirukan dalam pengujian ini, bukan bypass produksi.

Pengguna tetap harus melakukan setup dan login nyata sendiri. Operator tidak mengisi atau mengetahui password/seed TOTP pemilik saat rollout.
