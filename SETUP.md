# SETUP — dari workspace ke produksi (tanpa VM/VPS, tanpa kartu kredit)

Panduan menjalankan seluruh sistem XyDesk lewat **GitHub Actions**
(build/compile tidak dilakukan di mesin lokal).

## Status terkini

| Item | Status |
|---|---|
| Signaling Worker live | `https://signal.xydesk.my.id` (custom domain) |
| Worker secrets (XYDESK_SECRET, ADMIN_SECRET) | terpasang |
| Custom domain | `signal.xydesk.my.id` -> worker (zona `xydesk.my.id`; custom domain di zona lama dilepas pada rilis 6.5.4) |
| Endpoint TURN `/turn-ice` | jadi (butuh TURN key di dashboard) |
| Endpoint `/signal-token` (JWT -> token signaling) | jadi |
| Host WebRTC (webrtc-rs) | implementasi tersedia |
| CI "Build" (Flutter) | hijau |
| CI "Build Host" (Windows EXE) | hijau |
| CI "Deploy Signaling" | hijau |

## Tindakan yang butuh operator (di luar sandbox)

1. **TURN key** (opsional, untuk remote via internet): dashboard Cloudflare ->
   **Realtime -> TURN -> Create TURN key**, lalu:
   ```bash
   npx wrangler secret put TURN_KEY_ID     # id turn key
   npx wrangler secret put TURN_KEY_TOKEN  # api token turn key
   ```
2. **Uji capture layar** di Windows (DXGI + NVENC) — lihat `host/README.md`.

## 1. Struktur repo

```
XyDesk/
├── cloudflare/          # signaling + auth produksi (Worker + DO)
├── signaling/           # opsi self-host LAN (Go)
├── host/                # host Rust (WebRTC + data channel input)
├── lib/webrtc/          # transport WebRTC client (signaling, RTC, input)
├── docs/                # PROTOCOL, ARCHITECTURE, FREE-STACK
├── .github/workflows/   # build, release, deploy
├── ROADMAP.md, SETUP.md
```

## 2. Setting GitHub Secrets (repo -> Settings -> Secrets -> Actions)

| Secret | Nilai |
|---|---|
| `CLOUDFLARE_API_TOKEN` | API token Cloudflare (scope Workers Scripts:Edit) |
| `CLOUDFLARE_ACCOUNT_ID` | ID akun Cloudflare (dashboard -> Workers) |
| `XYDESK_SECRET` | `openssl rand -hex 32` |
| `ADMIN_SECRET` | kata sandi acak untuk endpoint `/issue` |
| `AUTH_SECRET` | kunci JWT/OTP terpisah |
| `RESEND_API_KEY` | kunci API pengirim email OTP |

Variable repo: `GOOGLE_CLIENT_ID` dan `RESEND_FROM`.

Nilai semua secret dikelola operator secara privat di luar repo. Jangan pernah
menulis nilai secret ke file yang di-commit.

## 3. Trigger build

- **Deploy signaling** -> push perubahan di `cloudflare/**`, atau manual
  (Actions -> "Deploy Signaling" -> Run workflow). Workflow memasang secret ke
  Worker lalu menjalankan `wrangler deploy`.
- **Build host** -> push perubahan di `host/**` -> menghasilkan
  `xydesk-host-windows` (artifact EXE).
- **Build APK Flutter** -> workflow `build.yml`.

## 4. Setelah deploy signaling jalan

Terbitkan token untuk host (pakai ADMIN_SECRET):

```bash
curl -H "X-Admin: <ADMIN_SECRET>" \
  "https://signal.xydesk.my.id/issue?purpose=gaming-pc-01"
```

Client app tidak memakai `/issue`: setelah pengguna login, app menukar JWT
sesi menjadi token signaling lewat `GET /signal-token?id=<deviceId>` dengan
header `Authorization: Bearer <jwt>`.

## 5. Urutan kerja selanjutnya (dari ROADMAP.md)

1. Isi `host/src/screen.rs` (DXGI + NVENC) — build di Windows runner.
2. Ukur latency < 40 ms — **jangan poles UI dulu**.

## Troubleshooting umum

- **wrangler gagal auth**: pastikan token punya scope `Workers Scripts:Edit`.
- **Durable Object error saat local dev**: pastikan `Hub` di-export dari
  `src/worker.js` (sudah ditangani).
- **`npm ci` gagal**: pastikan `package-lock.json` ikut ter-commit (sudah ada).
- **TURN 503 `turn-not-configured`**: buat TURN key di dashboard dulu (lihat
  bagian "Tindakan yang butuh operator").
