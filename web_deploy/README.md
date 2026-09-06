# XyDesk Web (Vite + React)

Frontend browser XyDesk. Flutter Web ditinggalkan untuk target browser:
bundle CanvasKit terlalu berat (unduhan MB-an sebelum layar pertama muncul).
Client web ringan (~65 KB gzip) di folder `web/` memakai backend yang sama
persis dengan aplikasi Android/Windows.

- Frontend produksi: `https://app.xydesk.my.id`
- API, autentikasi, dan signaling: `https://signal.xydesk.my.id`
- Fitur: login OTP email, sambung ke host (ID 9 digit + password pairing),
  viewer WebRTC + input mouse/scroll ke data channel biner.

Deployment otomatis mengambil artefak `XyDesk-Web` dari workflow Build yang
sukses (job Web Application menjalankan `npm ci && npm run build` di `web/`),
lalu mempublikasikannya ke Cloudflare Workers Static Assets.
