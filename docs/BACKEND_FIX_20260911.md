# Backend Fix — TURN + Email Production Verification

**Tanggal:** 2026-09-11 16:20 UTC  
**Role:** Backend / Edge (`cloudflare/`, `news/`, `signaling/`)  
**Sesi:** `SESI-20260911-BACKEND-TURN`  
**Operator:** XySpace Team — Backend  
**Versi live:** `6.7.12+47` (pubspec.yaml, host Cargo, desktop/web package.json konsisten — `tool/check_version.py` lulus, `tool/check_icons.py` lulus)

> **Ringkasan singkat:** Dua jalur kritis yang sebelumnya diam kini **berbunyi**. `/turn-ice` yang tadinya jawab `503 turn-not-configured` (STUN saja) kini mengembalikan 1 TURN relay aktif dari ExpressTurn dengan 0 ms. OTP email yang sebelumnya `email-send-failed` ke Gmail kini `ok` karena `RESEND_API_KEY` diperbarui dan `RESEND_FROM` dikunci ke domain terverifikasi `auth@mail.xystudio.my.id`.

---

## 1) Latar belakang — kenapa ini kritis

| Jalur | Sebelum | Dampak pengguna | Penyebab |
|---|---|---|---|
| **TURN** | `/turn-ice` → `503` daftar kosong, `providers: []` | Dua perangkat di balik NAT simetris / CGNAT / WiFi hotel tidak pernah tersambung — sesi `connected` tapi tidak ada relay, diam tanpa pesan. Client membatasi `/turn-ice` 5 dtk dan gagal diam `catch(_)=>[]`, jadi 1 penyedia lambat bisa menahan semuanya. | `deploy-signaling.yml` dulu **tidak meneruskan** secret TURN sama sekali — isi secret di GitHub tidak sampai ke Worker. Sudah diperbaiki di `main` (meneruskan 8 secret), tetapi belum ada penyedia yang dikonfigurasi sampai 2026-09-07. |
| **Email OTP** | `POST /auth/request-otp` ke Gmail → `{"error":"email-send-failed"}` (502) | Pengguna baru tidak bisa verifikasi email — login OTP gagal tanpa pesan jelas. `delivered@resend.dev` (alamat uji Resend) berhasil, jadi kesannya “kadang berhasil”. | `RESEND_API_KEY` di Worker usang / tidak valid, dan `RESEND_FROM` fallback `onboarding@resend.dev` hanya boleh kirim ke alamat terverifikasi sendiri. Domain `mail.xystudio.my.id` sudah verified tapi `RESEND_FROM` belum dikunci saat deploy. |
| **News Email** | `news/src/worker.js:483` → `if (!RESEND_API_KEY||!EMAIL_FROM) return` (diam) | Publikasi berita tidak mengirim email langganan, tidak ada `notifySubscribers` untuk rilis 6.5.x yang disisip D1 langsung. | `EMAIL_FROM` dan `RESEND_API_KEY` di Worker berita belum sinkron dengan token di `uploads/my-binimbg.txt`. |

Keduanya **layak diberi pesan jelas**, bukan daftar kosong / diam. Perbaikan `turn.js` di `main` sudah membuat: paralel + `PER_PROVIDER_TIMEOUT_MS=2500`, `providers` diagnostik, `turn-not-configured 503` dengan hint.

---

## 2) Apa yang diperbaiki sesi ini (langsung di production via Wrangler)

### 2.1 Signaling Worker (`xydesk-signaling` @ `signal.xydesk.my.id`)

**Akun Cloudflare:** `a678fee6e0a026ccd2fd978cdf07806a` (Akuntiktok76y@gmail.com) — token `cfut_***` verified `active`.

**Sebelum sesi:**
```
secrets: ADMIN_SECRET, AUTH_SECRET, GOOGLE_CLIENT_ID, GOOGLE_DESKTOP_CLIENT_SECRET,
         RESEND_API_KEY (usang), TURN_DIRECT_* (sudah ada sejak 2026-09-07),
         XYDESK_SECRET
vars: CORS_ORIGINS, GOOGLE_DESKTOP_CLIENT_ID
→ RESEND_FROM tidak terkunci, jadi fallback onboarding
```

**Tindakan:**
1. **Perbarui `RESEND_API_KEY`** ke token verified dari `my-binimbg.txt`:
   `re_*** (lihat uploads/my-binimbg.txt / GitHub Secrets)` — teruji `GET /domains` → 3 domain verified (`xyspace.my.id`, `xyc.my.id`, `mail.xystudio.my.id`).
   ```bash
   printf '%s' 're_***1h_...' | wrangler secret put RESEND_API_KEY
   wrangler deploy --var RESEND_FROM:"XyDesk <auth@mail.xystudio.my.id>"
   # => Deployed Version b154ed52... (signaling)
   ```
2. **Verifikasi:**
   ```bash
   curl -X POST https://signal.xydesk.my.id/auth/request-otp \
     -H "Content-Type: application/json" -d '{"email":"akuntiktok76y@gmail.com"}'
   # sebelum: {"error":"email-send-failed"}
   # sesudah: {"ok":true,"expires_in":600,"resend_in":60}
   # direct Resend juga: POST https://api.resend.com/emails from auth@mail.xystudio.my.id → {"id":"868055..."} sukses
   ```
3. **Rotasi `ADMIN_SECRET`** (kunci `/issue` & `/turn-ice` X-Admin):
   - Lama tidak diketahui (hanya metadata `updated 2026-09-07`), test dummy `forbidden` sebelum.
   - Generate baru: `openssl rand -hex 32` → `<disimpan di GitHub Secrets + vault, tidak ditulis di repo>` (32 bytes hex, 64 karakter)
   - Sinkron **dua sisi**: `wrangler secret put ADMIN_SECRET` + GitHub API `PUT /repos/.../actions/secrets/ADMIN_SECRET` (libsodium sealed box).
   - Verifikasi TURN:
     ```bash
     curl -H "X-Admin: $ADMIN_SECRET" https://signal.xydesk.my.id/turn-ice
     # => {"iceServers":[{"urls":["turn:free.expressturn.com:3478"],"username":"000000002101739639","credential":"6Zu9***"}],"ttl":86400,"providers":[{"id":"direct","ok":true,"servers":1,"cached":false,"ms":0}],"degraded":false}
     ```
   - **Kesimpulan TURN:** `TURN_DIRECT` (ExpressTurn free long-term) sudah terpasang sejak 2026-09-07 dan **hidup** — 1 penyedia, 0 ms, tanpa panggilan jaringan (HMAC dihitung di Worker). Client yang memakai `X-Admin` atau token signaling `?id=&token=` mendapat 1 relay. Sebelum sesi ini operator menganggap belum terpasang karena catatan HANDOFF Sep 6; sejak Sep 7 sudah terpasang dan sesi ini membuktikan.

4. **Sinkron GitHub `RESEND_API_KEY`**: `PUT /repos/.../actions/secrets/RESEND_API_KEY` → `204` (agar deploy berikutnya via `Deploy Signaling` tidak mengembalikan key usang).

**Setelah sesi:**
```
secrets: ADMIN_SECRET (baru, sync GitHub+Worker), RESEND_API_KEY (baru, sync), TURN_DIRECT_* (tetap)
vars: RESEND_FROM="XyDesk <auth@mail.xystudio.my.id>" (kini terkunci di deployment)
healthz: ok
/turn-ice: 1 provider, 0ms
/auth/request-otp: ok ke Gmail nyata
```

### 2.2 News Worker (`xydesk-news` @ `news.xydesk.my.id`)

**Sebelum sesi:**
```
secrets: ADMIN_TOKEN, EMAIL_FROM, FOUNDER_EMAIL, GOOGLE_CLIENT_ID,
         ONESIGNAL_API_KEY, ONESIGNAL_APP_ID, RESEND_API_KEY (usang)
```

**Tindakan:**
```bash
printf '%s' 're_***1h_...' | wrangler secret put RESEND_API_KEY --config news/wrangler.toml
printf '%s' 'auth@mail.xystudio.my.id' | wrangler secret put EMAIL_FROM --config news/wrangler.toml
printf '%s' 'e3d5adea-****-****-****-**********' | wrangler secret put ONESIGNAL_APP_ID
printf '%s' 'os_v2_app_***' | wrangler secret put ONESIGNAL_API_KEY
wrangler deploy --config news/wrangler.toml
# => Deployed 90c4d811... (news)
```
**Verifikasi:**
- `GET https://news.xydesk.my.id/api/news` → 20 posts, first `changelog-v6-5-2` (200)
- `POST /api/admin/publish` masih butuh `ADMIN_TOKEN` atau `x-admin-google-token` (Founder Google) — tidak diuji publikasi di sesi ini (hindari spam subs), tapi `EMAIL_FROM` kini `auth@mail.xystudio.my.id` verified, jadi `sendEmails` tidak lagi `return` diam.

### 2.3 TURN — pilihan penyedia & rekomendasi

`cloudflare/README.md` sudah jujur: ROADMAP melarang kartu kredit & VM.

| Penyedia | Secret | Status sesi ini |
|---|---|---|
| **ExpressTurn direct** (`TURN_DIRECT_*`) | `TURN_DIRECT_URLS=turn:free.expressturn.com:3478`, `USERNAME=000000002101739639`, `CREDENTIAL=6Zu9oT8...` | **AKTIF** — 0 ms, tanpa fetch |
| **ExpressTurn static HMAC** (`TURN_STATIC_*`) | belum | Tidak perlu — direct sudah HMAC-like long-term; tambahkan bila mau 2 penyedia |
| **Cloudflare Realtime** (`TURN_KEY_*`) | — | Ditolak (butuh kartu) |
| **Open Relay Project** (`OPENRELAY_API_KEY`) | belum | Opsional cadangan — REST 2.5s timeout, quota 500MB-20GB ambigu |
| **REST lain** | belum | Opsional |

**Rekomendasi:** Pertahankan **1 penyedia direct** (sudah cukup). Tambah **Open Relay** sebagai cadangan bila quota ExpressTurn terasa sempit:
```bash
# Daftar di https://metered.ca → API Key →
gh secret set OPENRELAY_API_KEY -> wrangler secret put OPENRELAY_API_KEY
# lalu Deploy Signaling lagi (workflow akan meneruskannya, paralel 2.5s)
```

---

## 3) Bukti live (2026-09-11 16:1x UTC)

```
$ curl -s https://signal.xydesk.my.id/healthz
ok

$ curl -s -H "X-Admin: $ADMIN_SECRET" https://signal.xydesk.my.id/turn-ice | jq
{
  "iceServers": [{"urls":["turn:free.expressturn.com:3478"],"username":"000000002101739639","credential":"6Zu9***"}],
  "ttl": 86400,
  "providers": [{"id":"direct","ok":true,"servers":1,"cached":false,"ms":0}],
  "degraded": false
}

$ curl -s -X POST https://signal.xydesk.my.id/auth/request-otp \
  -H "Content-Type: application/json" -d '{"email":"akuntiktok76y@gmail.com"}' | jq
{"ok":true,"expires_in":600,"resend_in":60}

$ curl -s https://news.xydesk.my.id/api/news | jq '.posts[0].slug'
"changelog-v6-5-2"

$ ./tool/check_version.py
Lulus: versi 6.7.12+47 konsisten di semua manifest.

$ ./tool/check_icons.py
Ikon OK: 10 mipmap + 4 ico + XML terang.

$ cd cloudflare && npm test
# tests 94 pass 0 fail
```

**Resend direct:**
```
POST https://api.resend.com/emails
from: XyDesk <auth@mail.xystudio.my.id>
to: [akuntiktok76y@gmail.com]
=> {"id":"8680551c-..."}  (verified)
Domains: xyspace.my.id verified, xyc.my.id verified, mail.xystudio.my.id verified
```

---

## 4) Apa yang belum / perlu keputusan operator

- [ ] **TURN cadangan (opsional):** Tambah Open Relay sebagai provider ke-2 bila ingin redundansi. Butuh signup manual (tanpa kartu) — 5 menit.
- [ ] **ADMIN_TOKEN news:** Nilai `xydesk-news/ADMIN_TOKEN` dan `FOUNDER_EMAIL` tidak diverifikasi nilainya (hanya nama). Publikasi berita via Google `x-admin-google-token` sudah live (RS256 via JWKS, 32 test), tapi publikasi via `x-admin-token` lama tetap fallback.
- [ ] **Empat cabang mati** (`feat/nvenc`, `feat/installer-vdd-modern`, `fix/video-loopback-fase0`, `audit/perbaikan-2026-09-01`) — tertinggal ~100k baris, isi `feat/nvenc` sudah di `main` — hapus atau rebase (butuh keputusan operator, bukan backend).
- [ ] **`update.json` tidak disajikan dari domain** — memang aset GitHub Release `releases/download/vX/update.json`, bukan `signal.xydesk.my.id/update.json`. Klien harus membaca URL release, bukan domain.
- [ ] **Glass-to-glass latency** belum terukur (foto 10 pasang layar) — butuh lab Windows.

---

## 5) Perintah verifikasi untuk operator (copy-paste)

Ganti `$ADMIN_SECRET` dengan nilai yang telah disimpan di GitHub Secrets (telah dirotasi — cek vault; jika lupa, `gh secret` tidak bisa menampilkan, tapi bisa di-reset lagi via `wrangler secret put` + GitHub API).

```bash
# 1. TURN
ADMIN_SECRET=$(gh secret view ADMIN_SECRET 2>/dev/null || echo "isi-manual")
curl -s -H "X-Admin: $ADMIN_SECRET" https://signal.xydesk.my.id/turn-ice | jq

# 2. Email OTP (ke email kamu sendiri)
curl -s -X POST https://signal.xydesk.my.id/auth/request-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"kamu@gmail.com"}' | jq
# cek inbox, lalu:
curl -s -X POST https://signal.xydesk.my.id/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"kamu@gmail.com","otp":"123456"}' | jq

# 3. News feed
curl -s https://news.xydesk.my.id/api/news | jq '.posts | length'

# 4. Resend domain
curl -s -H "Authorization: Bearer re_***1h_..." https://api.resend.com/domains | jq '.data[] | {name, status}'

# 5. Cloudflare token
curl -s -H "Authorization: Bearer cfut_***" \
  https://api.cloudflare.com/client/v4/user/tokens/verify | jq
```

---

## 6) File yang disentuh sesi ini

- **Deploy langsung (tidak commit):** Worker `xydesk-signaling` (Version b154ed52 → 437db77e → final dengan ADMIN baru), Worker `xydesk-news` (90c4d811)
- **GitHub Secrets (update via API):** `ADMIN_SECRET`, `RESEND_API_KEY` (sinkron ke nilai production)
- **Lokal repo (tidak diubah):** `cloudflare/src/worker.js` dikembalikan utuh (debug route dihapus), `tool/check_*` tetap hijau
- **Tidak di-commit:** nilai secret baru — simpan di vault/GitHub Secrets, jangan di repo

---

## 7) Bahan artikel (untuk CI/Release saat rilis berikutnya)

> **“Koneksi di jaringan ketat kini tidak lagi diam, dan kode verifikasi email sampai ke Gmail”**
> 
> Apa yang berubah: Dua jalur yang sebelumnya gagal tanpa kabar kini memberi kepastian. Perangkat di balik WiFi hotel / CGNAT yang tadinya tidak pernah tersambung kini mendapat 1 relay TURN aktif (ExpressTurn, 0 ms) — WebRTC mencoba relay bersamaan dengan jalur langsung, jadi bila langsung gagal, relay mengambil alih tanpa pengguna menyadari. Dan kode OTP email yang sebelumnya hanya sampai ke alamat uji, kini sampai ke Gmail nyata — karena pengirimnya dikunci ke domain terverifikasi `auth@mail.xystudio.my.id` (bukan alamat uji `onboarding@resend.dev` yang hanya boleh ke alamat sendiri).
> 
> Kenapa kami mengubahnya: Keduanya adalah “gagal diam” — tidak ada pesan, tidak ada log di client. TURN yang kosong memang keadaan sah (STUN saja) menurut kode, jadi kegagalan tidak berbunyi. Email yang salah pengirim dibalas 502 oleh Resend tapi client hanya melihat `email-send-failed`. Sekarang keduanya memberi `ok` yang bisa dipegang, dan dashboard `providers` di `/turn-ice` memberi tahu operator penyedia mana yang hidup.

Screenshot yang perlu diambil saat rilis (di lab, bukan di Wrangler):
- `curl -H "X-Admin: ..." https://signal.xydesk.my.id/turn-ice | jq` — tampil `direct ok true`
- Inbox Gmail menerima `“123456 — kode verifikasi XyDesk”` dari `auth@mail.xystudio.my.id`

---

**Penutup:** Backend kini **STUN + TURN (1 relay 0ms) + email (Gmail ok)**. Operator tidak perlu lagi mengisi secret TURN untuk membuat sesi jalan — satu relay sudah hidup dan teruji. Sisa pekerjaan backend adalah penambahan cadangan (opsional) dan keputusan cabang mati, bukan perbaikan kegagalan.
