# SETUP — dari workspace ke produksi (tanpa VM/VPS, tanpa kartu kredit)

Panduan memindahkan pekerjaan ini ke repo GitHub `xykalnotkel/XyDesk` dan
menjalankan semuanya lewat **GitHub Actions** (build/compile tidak dilakukan
di mesin lokal).

## 0. Kredensial yang kamu berikan (disimpan di `uploads/`)

| File | Isi | Dipakai untuk |
|---|---|---|
| `CloudflareApiToken (1).txt` | Cloudflare API token (`cfut_...`) | deploy Worker via wrangler |
| `PakeAja.txt` | GitHub PAT (`ghp_...`) | (opsional) operasi repo via CLI/API |

> ⚠️ **ROTASI SETELAH PAKAI.** Kedua token terkirim sebagai teks polos.
> Revoke & buat baru setelah selesai setup. Jangan pernah commit ke repo.

## 1. Salin ke repo GitHub

```
XyDesk/
├── cloudflare/          # signaling produksi (Worker + DO)
├── signaling/           # opsi self-host LAN (Go)
├── host/                # host Rust (scaffolding)
├── docs/                # PROTOCOL, ARCHITECTURE, FREE-STACK
├── .github/workflows/   # deploy-signaling.yml, build-host.yml
├── client/              # drop-in Flutter WebRTC (lib/webrtc/*.dart)
├── ROADMAP.md, SETUP.md
```

## 2. Setting GitHub Secrets (repo → Settings → Secrets → Actions)

| Secret | Nilai |
|---|---|
| `CLOUDFLARE_API_TOKEN` | isi file `CloudflareApiToken (1).txt` |
| `CLOUDFLARE_ACCOUNT_ID` | ID akun Cloudflare (dashboard → Workers → kanan bawah) |
| `XYDESK_SECRET` | `openssl rand -hex 32` |
| `ADMIN_SECRET` | kata sandi acak untuk endpoint `/issue` |

## 3. Trigger build

- **Deploy signaling** → push perubahan di `cloudflare/**`, atau manual
  (Actions → "Deploy Signaling" → Run workflow). Workflow akan:
  1. uji end-to-end 7 skenario (wrangler dev + test),
  2. pasang secret ke Worker,
  3. `wrangler deploy`.
- **Build host** → push perubahan di `host/**` → menghasilkan
  `xydesk-host-windows` (artifact EXE).
- **Build APK Flutter** → workflow `build.yml` yang SUDAH ada di repo-mu.

## 4. Setelah deploy signaling jalan

Terbitkan token untuk host & client (pakai ADMIN_SECRET):

```bash
curl -H "X-Admin: <ADMIN_SECRET>" \
  "https://xydesk-signaling.<akun>.workers.dev/issue?purpose=gaming-pc-01"
```

## 5. Urutan kerja selanjutnya (dari ROADMAP.md)

1. Isi `host/src/screen.rs` (DXGI + NVENC) — build di Windows runner.
2. Colok `client/lib/webrtc/rtc_service.dart` ke `SessionPage`.
3. Ukur latency < 40 ms — **jangan poles UI dulu**.

## Troubleshooting umum

- **wrangler gagal auth**: pastikan token punya scope `Workers Scripts:Edit`
  dan `Account Settings:Read`. Token `cfut_` harus kompatibel sebagai
  `CLOUDFLARE_API_TOKEN`; kalau ditolak, buat token baru bertipe "Edit Cloudflare
  Workers" di dashboard.
- **Durable Object error saat local dev**: pastikan `Hub` di-export dari
  `src/worker.js` (sudah ditangani).
- **`npm ci` gagal**: pastikan `package-lock.json` ikut ter-commit (sudah ada).
