# XyDesk Desktop (developer notes)

Shell Electron + Next.js untuk host Windows. Dokumentasi lengkap:
[`../docs/DESKTOP_SHELL.md`](../docs/DESKTOP_SHELL.md).

## Struktur

```
desktop/
├── electron/
│   ├── main.cjs        # proses utama: jendela, supervisor engine, IPC
│   └── preload.cjs     # contextBridge → window.xydesk
├── app/                # renderer Next.js (App Router, static export)
│   ├── layout.tsx
│   ├── page.tsx        # panel status/identitas/sesi/log
│   └── globals.css     # token Quiet Surface (sama dengan lib/core/tokens.dart)
├── global.d.ts         # tipe kontrak IPC
├── next.config.mjs     # output: 'export'
└── package.json        # skrip + konfigurasi electron-builder
```

## Menjalankan

```bash
npm install
# Build engine dulu (dari repo root):
#   cd ../host && cargo build --release
npm run dev          # renderer saja (browser): http://localhost:3470
npm run electron     # aplikasi desktop penuh (dev mode)
```

## Paket Windows

```bash
npm run package              # installer NSIS + portable → dist/
npm run package:portable     # portable saja
```

Catatan: `electron-builder` berjalan di Windows (atau Wine); di CI
ditangani `.github/workflows/build-desktop.yml`.
