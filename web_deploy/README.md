# XyDesk Flutter Web

Frontend Web tetap menggunakan Flutter agar Android, Windows, dan browser
berbagi UI serta logika produk yang sama. Bundle hasil job `Web Application`
dipublikasikan ke Cloudflare Workers Static Assets.

- Frontend produksi: `https://app.xystudio.my.id`
- API, autentikasi, dan signaling: `https://signal.xystudio.my.id`
- Renderer produksi: CanvasKit bawaan Flutter. Build Wasm/Skwasm baru diaktifkan
  setelah kompatibilitas browser dan seluruh plugin divalidasi manual.

Deployment otomatis hanya mengambil artefak Web dari workflow Build yang sukses;
frontend tidak dibangun ulang dengan dependency yang berbeda saat deployment.
