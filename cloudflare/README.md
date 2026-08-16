# XyDesk Signaling — Cloudflare (tanpa VM/VPS)

Signaling WebRTC di atas **Cloudflare Workers + Durable Objects** — gratis,
tanpa kartu kredit, tanpa server sendiri. Pengganti total versi Go/VM.

## Kenapa Cloudflare?

| Kebutuhan | Solusi | Biaya |
|---|---|---|
| WebSocket persisten | Worker + Durable Object (Hibernation API) | Rp 0 |
| STUN | `stun.cloudflare.com` | gratis tanpa batas |
| TURN (NAT ketat) | `turn.cloudflare.com` | 1.000 GB/bulan gratis |
| TLS | otomatis (custom domain signal.xystudio.my.id) | Rp 0 |

Free tier Workers: **100K request/hari**. Signaling hanya KB per sesi, jadi
cukup untuk pemakaian personal + komunitas kecil. Media TIDAK lewat sini
(end-to-end), jadi tidak kena kuota egress.

## Deploy (3 perintah, tanpa kartu kredit)

```bash
npm install
npx wrangler login                  # browser, akun Cloudflare gratis (tanpa kartu)
npx wrangler secret put XYDESK_SECRET   # isi: openssl rand -hex 32
npx wrangler secret put ADMIN_SECRET    # isi: kata sandi admin /issue
npx wrangler deploy                    # → https://signal.xystudio.my.id
```

## Terbitkan token (host & client)

```bash
curl -H "X-Admin: $ADMIN_SECRET" \
  "https://signal.xystudio.my.id/issue?purpose=gaming-pc-01"
# → 1786843937.gaming-pc-01.<sig>   (berlaku 5 menit)
```

Host pakai `purpose = deviceId`-nya; client pakai `purpose = deviceId`-nya juga.
Token dibawa sebagai `?token=` (client Flutter) atau header `Authorization:
Bearer` (host Rust).

## Uji lokal

```bash
npm run dev    # wrangler dev di :8787
npm test       # 7 skenario end-to-end (butuh server dev jalan)
```

## Struktur

```
cloudflare/
├── wrangler.toml        # binding DO + migrasi
├── src/worker.js        # entrypoint: rute + auth HMAC + /issue
├── src/hub.js           # Durable Object: registri + relay (hibernation)
├── test/signaling.test.mjs
└── .dev.vars            # secret lokal SAJA (jangan commit)
```

## Skala

Satu DO global cukup untuk personal. Saat ramai, ubah `idFromName('global')`
jadi sharding (`idFromName('shard-' + deviceId[0])`) — protokol tidak berubah.
