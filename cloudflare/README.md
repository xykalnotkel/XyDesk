# XyDesk Signaling — Cloudflare (tanpa VM/VPS)

Signaling WebRTC di atas **Cloudflare Workers + Durable Objects** — gratis,
tanpa kartu kredit, tanpa server sendiri. Pengganti total versi Go/VM.

## Kenapa Cloudflare?

| Kebutuhan | Solusi | Biaya |
|---|---|---|
| WebSocket persisten | Worker + Durable Object (Hibernation API) | Rp 0 |
| STUN | `stun.cloudflare.com` | gratis tanpa batas |
| TURN (NAT ketat) | multi-penyedia, lihat `src/turn.js` | tergantung penyedia; secret statis tak perlu kartu kredit |
| TLS | otomatis (custom domain signal.xydesk.my.id) | Rp 0 |

Free tier Workers: **100K request/hari**. Signaling hanya KB per sesi, jadi
cukup untuk pemakaian personal + komunitas kecil. Media TIDAK lewat sini
(end-to-end), jadi tidak kena kuota egress.

## Deploy (3 perintah, tanpa kartu kredit)

```bash
npm install
npx wrangler login                  # browser, akun Cloudflare gratis (tanpa kartu)
npx wrangler secret put XYDESK_SECRET   # isi: openssl rand -hex 32
npx wrangler secret put ADMIN_SECRET    # isi: kata sandi admin /issue

# TURN — boleh lebih dari satu, semuanya dipakai sebagai cadangan.
# Penyedia termurah dan paling tangguh: secret statis (ExpressTurn atau
# coturn sendiri). Kredensialnya dihitung di Worker, jadi tetap hidup
# meski penyedia lain sedang mogok.
npx wrangler secret put TURN_STATIC_URLS   # mis. turn:free.expressturn.com:3478
npx wrangler secret put TURN_STATIC_SECRET # shared secret dari penyedia
# npx wrangler secret put TURN_STATIC_USER # opsional, default: xydesk
# Penyedia lain (tambahan, bukan pengganti):
# npx wrangler secret put TURN_KEY_ID      # Cloudflare Realtime
# npx wrangler secret put TURN_KEY_TOKEN
# npx wrangler secret put OPENRELAY_API_KEY   # Open Relay Project
# npx wrangler secret put TURN_REST_URL       # penyedia REST lain
# npx wrangler secret put TURN_REST_API_KEY
npx wrangler deploy                    # → https://signal.xydesk.my.id
```

### Dua jalur memasang secret — dan satu bug yang membuat TURN tidak pernah hidup

Jalur kanonik adalah **workflow `Deploy Signaling`** (`.github/workflows/
deploy-signaling.yml`, `workflow_dispatch`) yang membaca GitHub Secrets. Perintah
`wrangler` di atas adalah jalur alternatif untuk pengerjaan lokal.

Perlu dicatat karena ini nyata terjadi: workflow itu **tidak pernah meneruskan
secret TURN sama sekali** — ia hanya memasang `XYDESK_SECRET`, `ADMIN_SECRET`,
`AUTH_SECRET`, `RESEND_API_KEY`, dan `GOOGLE_CLIENT_ID`. Jadi mengisi
`OPENRELAY_API_KEY` di GitHub Secrets tidak berpengaruh apa pun; worker tetap
tidak melihatnya dan `/turn-ice` tetap menjawab daftar kosong. Kegagalannya
diam, karena TURN yang kosong memang keadaan sah (worker dirancang jalan dengan
STUN saja). Kini kedelapan secret TURN diteruskan, dan yang kosong dilewati
dengan catatan alih-alih menggagalkan deploy.

Satu hal yang sengaja dibuat keras: **secret TURN berpasangan**. `configured()`
di `src/turn.js` menuntut keduanya, jadi mengisi `TURN_STATIC_URLS` tanpa
`TURN_STATIC_SECRET` (atau sebaliknya) membuat penyedia itu dilewati TANPA
PESAN — persis kelas kegagalan diam yang coba dihabiskan. Workflow menolaknya
sebelum deploy.

### Memilih penyedia TURN tanpa kartu kredit

`ROADMAP.md` mengikat: semua gratis, tanpa kartu kredit, tanpa VM/VPS. Itu
menyisakan pilihan sempit dan tidak semuanya enak:

| Penyedia | Secret | Penilaian jujur |
|---|---|---|
| **ExpressTurn** | `TURN_STATIC_URLS` + `TURN_STATIC_SECRET` | Paling cocok dengan aturan repo. Kredensial dihitung **di dalam Worker** dengan HMAC-SHA1 — tanpa panggilan jaringan, jadi tetap hidup walau penyedia REST lain mogok, dan tidak menambah waktu tempuh `/turn-ice`. Punya tier gratis; angka pastinya perlu dicek saat mendaftar, tidak diverifikasi dari repo ini. |
| **Open Relay Project** (metered.ca) | `OPENRELAY_API_KEY` | REST, jadi menambah satu panggilan jaringan (kini dibatasi 2,5 detik). Pendaftaran gratis tanpa kartu, tetapi **kuota gratisnya dilaporkan berbeda-beda dan sumbernya saling bertentangan**: halaman harga Metered menyebut 500 MB/bulan, halaman Open Relay menyebut 20 GB/bulan, dan daftar pihak ketiga menyebut 20 GB baru terbuka setelah kartu ditambahkan. Anggap kecil sampai terbukti sendiri. |
| **coturn sendiri** | `TURN_STATIC_URLS` + `TURN_STATIC_SECRET` | Paling tangguh dan tanpa kuota, tetapi butuh VPS — bertentangan dengan "tanpa VM/VPS". Hanya masuk akal bila suatu saat sudah ada mesin yang memang berjalan. |
| **Cloudflare Realtime** | `TURN_KEY_ID` + `TURN_KEY_TOKEN` | **Butuh kartu kredit**, jadi melanggar ROADMAP. Didukung kodenya, jangan dipakai kecuali aturannya berubah. |
| **REST lain** (Metered, Turnix) | `TURN_REST_URL` + `TURN_REST_API_KEY` | Jalur umum untuk penyedia apa pun yang memberi kredensial lewat HTTP. |

Rekomendasi: isi **secret statis dulu** (satu penyedia cukup untuk mulai), lalu
tambahkan Open Relay sebagai cadangan bila kuota statisnya terasa sempit.
Multi-penyedia memang dirancang untuk itu — WebRTC mencoba semuanya bersamaan.

### Verifikasi setelah deploy

`/turn-ice` dilindungi header `X-Admin` (isi `ADMIN_SECRET`); tanpa itu ia
menjawab 403, dan 403 di sini berarti "kamu tidak membawa kuncinya", bukan
"TURN-nya rusak".

```bash
curl -s -H "X-Admin: $ADMIN_SECRET" https://signal.xydesk.my.id/turn-ice | jq
```

Balasannya punya `iceServers` (yang dipakai client) dan `providers` — daftar
penyedia mana yang menjawab, mana yang gagal, dan berapa ms masing-masing.
`providers` ada justru untuk ini: TURN yang diam tidak bisa dibedakan dari TURN
yang tidak dikonfigurasi tanpa melihat sisi servernya.

## Terbitkan token host

Gunakan Node.js 24 Active LTS. Wrangler 4.123 membutuhkan minimal Node.js 22.

```bash
curl -H "X-Admin: $ADMIN_SECRET" \
  "https://signal.xydesk.my.id/issue?purpose=gaming-pc-01"
# → 1786843937.gaming-pc-01.<sig>   (berlaku 5 menit, role host)
```

Host membawa token lewat header `Authorization: Bearer`. Client tidak memakai
endpoint admin; setelah login, client menukar JWT lewat `/signal-token` dan
mendapat token role `client`. ID dan role masuk ke signature HMAC, jadi token
client tidak bisa dipakai ulang untuk menyamar sebagai host.

## Jalankan lokal

```bash
npm test       # test JWT, OTP, rate limit, role token, dan arah relay
npm run check  # test + validasi bundle Worker tanpa deploy
npm run dev    # wrangler dev di :8787
```

Workflow deploy menjalankan `npm run check` sebelum menyentuh produksi.

## Struktur

```
cloudflare/
├── wrangler.toml        # binding DO + migrasi
├── src/worker.js        # entrypoint: rute + auth HMAC + /issue
├── src/hub.js           # Durable Object: registri + relay (hibernation)
└── .dev.vars            # secret lokal SAJA (jangan commit)
```

## Skala

Satu DO global cukup untuk personal. Saat ramai, ubah `idFromName('global')`
jadi sharding (`idFromName('shard-' + deviceId[0])`) — protokol tidak berubah.
