# Admin XyDesk — konfigurasi dan verifikasi

## Login

Salin `.env.example` ke `.env.local` untuk build lokal:

- `VITE_GOOGLE_CLIENT_ID`: OAuth Web client ID; tambahkan origin admin yang benar di Google Authorized JavaScript Origins.
- `VITE_TURNSTILE_SITEKEY`: sitekey produksi untuk hostname admin. Tidak ada fallback captcha test.

Worker membutuhkan `GOOGLE_CLIENT_ID` (atau `GOOGLE_WEB_CLIENT_ID`), `TURNSTILE_SECRET` (atau `TURNSTILE_SECRET_KEY`), `AUTH_SECRET` (atau `XYDESK_SECRET`), dan allowlist `ADMIN_EMAILS`. Jangan simpan secret di frontend.
`ADMIN_TURNSTILE_HOSTNAMES` dapat diisi daftar hostname dipisahkan koma; default `admin.xydesk.my.id,xydesk-admin.pages.dev`.

Login memakai Google Identity Services dan token Turnstile sekali pakai. Worker memeriksa signature/audience/issuer/expiry/email terverifikasi Google, hostname captcha, dan email allowlist. Sesi berlaku satu jam, membawa `aud=xydesk-admin` serta `role=admin`. JWT lama dan JWT akun biasa tidak diterima oleh endpoint admin. HTTP 401 mengembalikan panel ke Login.

**Dampak rollout:** admin yang sudah login harus masuk ulang. Konfigurasi OAuth dan captcha harus benar sebelum rollout bersama Worker + panel. Belum ada bukti pengujian Google/captcha produksi dari sesi ini.

## Backend & server

`GET /admin/health` memerlukan sesi admin dan memeriksa:

- Worker: handler berhasil merespons.
- AuthStore: RPC pembacaan storage, tanpa mengubah data.
- Hub: RPC statistik koneksi.

Setiap probe punya batas tunggu lima detik. `latencyMs` adalah durasi RPC internal, **bukan** ping perangkat, FPS, latensi streaming, uptime historis, atau bukti kesehatan keseluruhan layanan. HTTP 200 membawa status tiap komponen; komponen dapat `unavailable`.

Belum ada agen kontrol engine/VM terautentikasi. Restart, benchmark, capture test, dan deploy dinyatakan tidak tersedia. Tidak ada perintah shell jarak jauh atau kredensial server yang ditambahkan. `POST /admin/hosting/purge` mengembalikan 501 sampai integrasi sungguhan tersedia.

## Maintenance

Panel mengirim satu POST:

```json
{
  "services": {"web": false, "desktop": false, "android": true, "signal": false},
  "message": "Perawatan Android",
  "revision": 3
}
```

AuthStore memeriksa revisi, menyimpan seluruh flag + audit log dalam transaksi, lalu menaikkan revision. Revisi basi menghasilkan HTTP 409 tanpa menimpa data. Format satu layanan lama (`service`, `enabled`, opsional `message`) masih didukung dan digabung di dalam transaksi; klien lama tanpa revision belum memiliki perlindungan edit basi.

Galat upstream/storage menghasilkan 503, bukan flag false atau sukses palsu. Saat timeout, penulisan bisa saja selesai di backend setelah UI menerima galat: muat ulang sebelum mencoba lagi. Pembacaan publik hanya mengembalikan flag dan pesan, tanpa email pengubah atau revision.

MAU, jumlah seluruh perangkat, sesi aktif/hari ini, dan billing belum punya sumber pengukuran. `/admin/stats` mengirim `null` untuk metrik tersebut; UI menampilkan `—`. Angka Hub adalah koneksi online, bukan riwayat sesi. Konsumen lain wajib mengakomodasi nilai nullable.

## Pemeriksaan lokal

```sh
cd admin
npm install
npm test
npm run build

cd ../cloudflare
npm test
# Node >=22, Wrangler sesuai package.json:
npm run test:runtime
```

Hasil pemeriksaan terakhir 17 September 2026: 15 tes API panel dan 122 tes unit Worker lolos; build panel dan bundling dry-run Worker lolos. Tes unit memakai fetch/storage tiruan, termasuk signature RSA sungguhan dengan kunci uji. `npm run test:runtime` juga lolos pada runtime lokal Wrangler 4.133.0/Miniflare dengan SQLite dan compatibility date 2026-08-17: transaksi batch, konflik konkurensi, patch legacy, audit log, health RPC, dan penolakan akses anonim. Tidak memakai storage produksi.

Uji Chromium pada build panel dengan seluruh API ditirukan juga lolos: health, kontrol engine nonaktif, draft tanpa POST, simpan satu POST, galat status, dan logout 401; tanpa pageerror.

Belum diuji: login akun Google sungguhan, captcha Turnstile admin, transaksi storage produksi, dan host Windows/VM. Tidak ada deploy/bump versi. Hasil preflight OAuth nyata dijelaskan di bawah.

## Prioritas berikutnya

1. Verifikasi konfigurasi Google/Turnstile dan lakukan smoke test login di origin resmi saat rollout disetujui.
2. Uji transaksi serta konkurensi pada runtime Durable Object, lalu smoke test maintenance tanpa mengganggu layanan pengguna.
3. Audit dampak bypass login lama dan kebutuhan invalidasi token pada endpoint non-admin. Audience baru menolak token lama di `/admin/*`, bukan pencabutan global semua JWT lama. Rotasi secret global perlu rencana karena bisa memutus sesi web/APK/host.
4. Audit enforcement ban/role/revoke dan kontrak sesi Hub. Tidak dinyatakan selesai oleh perubahan ini.
5. Rancang agen host terautentikasi dengan perintah terbatas, otorisasi per perangkat, audit, dan penanganan reconnect sebelum mengaktifkan kontrol server.


## Preflight produksi — rollout ditahan (17 September 2026)

Izin operator: verifikasi → push → deploy bila siap; tanpa rotasi secret global, restart host, atau bump versi.

- Akses GitHub push dan token Cloudflare valid; remote main belum memiliki perubahan tambahan saat preflight.
- Client ID publik web produksi cocok dengan lampiran operator: `495336144977-dp1k3678cocjrfhftb9blnqo5qnvhsr6.apps.googleusercontent.com`.
- Chromium memuat GIS asli pada origin `https://admin.xydesk.my.id` (halaman harness dicegat lokal, bukan perubahan situs live). Script GIS HTTP 200; iframe tombol HTTP 403 dengan pesan Google: **The given origin is not allowed for the given client ID.** Origin `https://app.xydesk.my.id` juga ditolak pada pengujian GIS yang sama; ini bukan bukti bahwa alur redirect web yang berbeda ikut gagal.
- Worker produksi `xydesk-signaling` belum memiliki binding `TURNSTILE_SECRET` atau `TURNSTILE_SECRET_KEY`; akun belum mempunyai widget untuk hostname admin. Tidak ada widget/secret produksi yang dibuat atau diubah di sesi ini.
- Endpoint publik `/healthz` saat preflight tetap HTTP 200 (`ok`). Tidak ada login palsu, penulisan maintenance, atau kontrol host yang dicoba di produksi.

### Tindakan pemilik akun Google

Buka Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client IDs. Pilih **Web application** dengan Client ID di atas. Tambahkan pada **Authorized JavaScript origins**:

```text
https://admin.xydesk.my.id
```

Jangan mengganti Client ID atau menghapus origin/redirect URI yang sudah ada. Tambahkan `https://xydesk-admin.pages.dev` hanya bila domain tersebut memang akan dipakai untuk login; domain produksi utama adalah admin.xydesk.my.id. Perubahan ini tidak dapat dilakukan dengan token GitHub/Cloudflare yang tersedia. Tidak perlu membagikan password Google atau client secret ke chat.

Setelah tersimpan, ulangi probe GIS; bila origin diterima, buat widget Turnstile khusus hostname admin, simpan secretnya ke Worker melalui secret binding, isi nilai publik build, kemudian rollout backend + panel dan lakukan smoke test di origin resmi. Jangan deploy build lokal tanpa env login.
