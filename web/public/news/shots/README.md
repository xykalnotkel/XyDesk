# Screenshot berita (news/shots)

Folder ini wadah screenshot ASLI yang menyertai artikel berita — diwajibkan
`docs/NEWS_STYLE.md` bagian 3. Ter-deploy ke
`https://app.xydesk.my.id/news/shots/<file>.jpg`.

Aturan singkat:

- Screenshot diambil dari **build yang benar-benar dirilis** — bukan mockup,
  bukan Figma, bukan hasil edit/AI.
- Nama file: `<versi>-<apa>.jpg`, huruf kecil, tanpa spasi.
  Contoh: `6.3.0-panel-koneksi-baru.jpg`, `6.3.0-login-sebelum.jpg`,
  `6.3.0-login-sesudah.jpg`.
- Batch `web-sesi-*.jpg` (2026-09-03): layar sesi web hasil harness
  `web/e2e/` — build rilis + host pola uji via WebRTC nyata, bukan
  mockup. Tanpa prefiks versi karena menggambarkan UI sesi web yang
  dirilis setelah 6.3.0 tanpa bump versi aplikasi.
- Format JPG, lebar wajar (≤ 1600 px) supaya halaman berita tetap ringan.
- Sampul/banner artikel BUKAN di sini — tetap di `../covers/` (1424×752).

Sintaks pemakaian di badan berita (baris sendiri):

```
![Keterangan yang menjelaskan gambar](https://app.xydesk.my.id/news/shots/6.3.0-panel-koneksi-baru.jpg)
```
