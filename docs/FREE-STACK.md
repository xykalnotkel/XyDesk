# Stack Gratis — Tanpa Kartu Kredit, Tanpa VM/VPS

Komitmen: **XyDesk berjalan penuh dengan biaya Rp 0**, di atas Cloudflare (serverless),
tanpa VM/VPS, tanpa API berbayar, tanpa kartu kredit.

## Arsitektur biaya-nol

| Kebutuhan | Solusi | Biaya | Kartu? |
|---|---|---|---|
| Signaling server | **Cloudflare Worker + Durable Object** (`cloudflare/`) | Rp 0 (100K req/hari) | ❌ |
| STUN | `stun.cloudflare.com` (publik, anycast) | gratis tanpa batas | ❌ |
| TURN (NAT ketat) | `turn.cloudflare.com` | **1.000 GB/bulan gratis** | ❌ |
| TLS | otomatis workers.dev / custom domain | Rp 0 | ❌ |
| Auth | Firebase **Spark** / Supabase free / HMAC self-host | Rp 0 | ❌ |
| Encode/decode | NVENC/AMF/QuickSync (GPU onboard) | Rp 0 | ❌ |
| Library | flutter_webrtc, webrtc-rs, str0m, ws | Rp 0 (MIT/Apache/BSD) | ❌ |

## Kenapa media TIDAK membebani Cloudflare

Media (video/audio) berjalan **end-to-end** antar host & client lewat WebRTC
(DTLS-SRTP). Server signaling hanya merelay SDP/ICE (KB per sesi), jadi:
- **Tidak kena kuota egress** Worker (yang mahal di serverless).
- **Tidak kena biaya TURN** kecuali koneksi benar-benar butuh relay (NAT simetris,
  ±15-20% kasus), dan itu pun 1.000 GB/bulan gratis.

Cloudflare TURN bersifat transparan + terenkripsi: Cloudflare hanya meneruskan
paket DTLS yang sudah terenkripsi, tidak bisa membaca layar [2](https://developers.cloudflare.com/realtime/turn/faq/).

## Batas yang perlu disadari (jujur)

1. **Free tier Workers = 100K request/hari.** Sekali koneksi WebSocket = 1
   request + beberapa detik CPU. Untuk personal & komunitas kecil, jauh dari
   batas. Kalau menembusnya, itu artinya kamu sudah cukup besar untuk naik ke
   $5/bln Workers Paid (masih tanpa VM).
2. **TURN gratis 1.000 GB/bulan** — lebih dari itu kena $0,05/GB. Remote desktop
   gaming ~1-4 GB/jam lewat relay; artinya 250-1000 jam/bulan gratis. Di atas itu
   artinya kamu pengguna super-aktif (dan bisa evaluasi opsi lain).
3. **STUN (stun.cloudflare.com) gratis tanpa batas** — kebanyakan koneksi
   (port-restricted NAT) cukup pakai STUN, tanpa TURN sama sekali.

## Deploy (total 5 menit, tanpa kartu)

```bash
cd cloudflare
npm install
npx wrangler login                                    # akun gratis, tanpa kartu
npx wrangler secret put XYDESK_SECRET                 # openssl rand -hex 32
npx wrangler secret put ADMIN_SECRET
npx wrangler deploy
```

## Yang WAJIB dihindari (agar tetap gratis)

1. **Jangan** pakai TURN berbayar (Twilio/Metered) — Cloudflare TURN gratis 1 TB.
2. **Jangan** upgrade ke Workers Paid kecuali benar-benar butuh.
3. **Jangan** rute media lewat Worker — pertahankan end-to-end.
4. **Jangan** taruh `XYDESK_SECRET` di `wrangler.toml` atau commit `.dev.vars`.

**Kesimpulan:** gratis & tanpa VM itu layak secara teknis karena arsitektur
end-to-end membuat server hampir bebas beban — Cloudflare Workers cukup.
