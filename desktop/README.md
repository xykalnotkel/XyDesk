# XyDesk Desktop (Tauri + Next.js)

Shell Tauri v2 + Next.js (static export) untuk host Windows. Dokumentasi lengkap:
[`../docs/DESKTOP_SHELL.md`](../docs/DESKTOP_SHELL.md).

## Struktur

```
desktop/
├── src-tauri/          # Core backend Tauri v2 (Rust)
│   ├── Cargo.toml      # Konfigurasi dependensi Rust (Tauri, tokio, reqwest)
│   ├── tauri.conf.json # Konfigurasi window, tray, resource bundle
│   ├── icons/          # Icon aplikasi & tray (dari tool/gen_logo.py)
│   └── src/
│       ├── main.rs     # Entry point binary Tauri
│       ├── lib.rs      # Setup plugin, tray, command handlers
│       ├── engine.rs   # Supervisor xydesk-host.exe & HTTP Control API
│       ├── auth.rs     # Google OAuth PKCE loopback + Email OTP
│       ├── tray.rs     # System tray menu & minimize-to-tray
│       └── commands.rs # Tauri command handlers (get_status, run_action, dll.)
├── app/                # Frontend Next.js (App Router, static export)
│   ├── layout.tsx
│   ├── page.tsx        # Sidebar: Home / Connect / News / Profile / Settings
│   ├── bridge.ts       # Jembatan runtime window.xydesk -> Tauri invoke
│   ├── news.ts         # Klien API berita publik (news.xydesk.my.id)
│   └── globals.css     # Token Quiet Surface (identik lib/core/tokens.dart)
├── global.d.ts         # Tipe kontrak IPC
├── next.config.mjs     # output: 'export'
└── package.json        # Skrip build frontend & typecheck
```

## Menjalankan

```bash
cd desktop
npm install
npm run dev             # Frontend saja (mode demo di browser): http://localhost:3470
npm run build           # Static export Next.js ke desktop/out/
```

## Membangun Paket Windows

```bash
# Dari root repo:
cargo build --release -p xydesk-desktop --manifest-path desktop/src-tauri/Cargo.toml
```

CI otomatis menangani kompilasi dan pembuatan installer Inno Setup via `.github/workflows/build-desktop.yml`.
