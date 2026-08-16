# SETUP — dari workspace ke produksi (tanpa VM/VPS, tanpa kartu kredit)

Panduan memindahkan pekerjaan ini ke repo GitHub `xykalnotkel/XyDesk` dan
menjalankan semuanya lewat **GitHub Actions** (build/compile tidak dilakukan
di mesin lokal).

## ✅ Status terkini

| Item | Status |
|---|---|
| Signaling Worker live | `https://signal.xystudio.my.id` (custom domain) |
| Worker secrets (XYDESK_SECRET, ADMIN_SECRET) | terpasang |
| Custom domain | `signal.xystudio.my.id` → worker (zona `xystudio.my.id`) |
| Endpoint TURN `/turn-ice` | jadi + teruji (butuh TURN key di dashboard) |
| Host WebRTC (webrtc-rs) | jadi + uji e2e dua peer lulus |
| Signaling test | 11/11 lulus (auth, relay, pair, TURN, dsb.) |
| GitHub Secrets (4) | terpasang |
| CI "Build" (Flutter) | hijau ✅ |
| CI "Build Host" (Windows EXE) | hijau ✅ |
| CI "Deploy Signaling" | hijau ✅ |

Kredensial rahasia tersimpan di `uploads/credentials.txt` (kunci kita berdua).

## ⏭️ Tindakan yang butuh KAMU (di luar sandbox)

1. **TURN key** (opsional, untuk remote via internet): dashboard Cloudflare →
   **Realtime → TURN → Create TURN key**, lalu:
   ```bash
   npx wrangler secret put TURN_KEY_ID     # id turn key
   npx wrangler secret put TURN_KEY_TOKEN  # api token turn key
   ```
   (Token Cloudflare `cfut_` saat ini tidak punya izin produk Realtime —
   buat TURN key lewat dashboard dulu.)
2. **Uji capture layar** di Windows (DXGI + NVENC) — lihat `host/README.md`.
3. **Compile client Flutter** (butuh Flutter SDK) — `client/` sudah siap.

---

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
├── host/                # host Rust (WebRTC + data channel input)
├── docs/                # PROTOCOL, ARCHITECTURE, FREE-STACK
├── .github/workflows/   # deploy-signaling.yml, build-host.yml
├── client/              # drop-in Flutter WebRTC (lib/webrtc/*.dart)
├── ROADMAP.md, SETUP.md
```

## 2. Setting GitHub Secrets (repo → Settings → Secrets → Actions)

| Secret | Nilai |
|---|---|
| `CLOUDFLARE_API_TOKEN` | isi file `CloudflareApiToken (1).txt` |
| `CLOUDFLARE_ACCOUNT_ID` | ID akun Cloudflare (dashboard → Workers) |
| `XYDESK_SECRET` | `openssl rand -hex 32` |
| `ADMIN_SECRET` | kata sandi acak untuk endpoint `/issue` |

## 3. Trigger build

- **Deploy signaling** → push perubahan di `cloudflare/**`, atau manual
  (Actions → "Deploy Signaling" → Run workflow). Workflow akan:
  1. uji end-to-end 11 skenario (wrangler dev + test),
  2. pasang secret ke Worker,
  3. `wrangler deploy`.
- **Build host** → push perubahan di `host/**` → menghasilkan
  `xydesk-host-windows` (artifact EXE) + jalankan `cargo test`.
- **Build APK Flutter** → workflow `build.yml` yang SUDAH ada di repo-mu.

## 4. Setelah deploy signaling jalan

Terbitkan token untuk host & client (pakai ADMIN_SECRET):

```bash
curl -H "X-Admin: <ADMIN_SECRET>" \
  "https://signal.xystudio.my.id/issue?purpose=gaming-pc-01"
```

## 5. Urutan kerja selanjutnya (dari ROADMAP.md)

1. Isi `host/src/screen.rs` (DXGI + NVENC) — build di Windows runner.
2. Colok `client/lib/webrtc/rtc_service.dart` ke `SessionPage`.
3. Ukur latency < 40 ms — **jangan poles UI dulu**.

## Troubleshooting umum

- **wrangler gagal auth**: pastikan token punya scope `Workers Scripts:Edit`.
  Token `cfut_` harus kompatibel sebagai `CLOUDFLARE_API_TOKEN`.
- **Durable Object error saat local dev**: pastikan `Hub` di-export dari
  `src/worker.js` (sudah ditangani).
- **`npm ci` gagal**: pastikan `package-lock.json` ikut ter-commit (sudah ada).
- **TURN 503 `turn-not-configured`**: buat TURN key di dashboard dulu (lihat
  bagian "Tindakan yang butuh KAMU").
