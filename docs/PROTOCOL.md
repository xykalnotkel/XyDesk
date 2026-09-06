# Protokol Signaling XyDesk

WebSocket ber-autentikasi, JSON per frame. Server = **relay SDP/ICE murni**,
tidak pernah menyentuh media. Desain ini membuat server ringan dan privat.

## Koneksi

```
GET /ws?id=<deviceId>&role=host|client
Authorization: Bearer <token>
```

- `token` = HMAC-SHA256 berumur 5 menit, diterbitkan dengan secret bersama.

`POST /host-token` melayani tiga jalur:

| Isi permintaan | Untuk | Balasan |
|---|---|---|
| `{id, claim}` | perangkat baru (TOFU), atau host tanpa kredensial tersimpan | `200` token teks polos (kompatibel aplikasi lama); dengan `v: 2` → `{token, refresh}` |
| `{id, refresh}` | menyambung ulang — tanpa password, tanpa rem klaim | `200 {token}` |
| `{id, refresh, claim}` | password pairing diganti di PC | `200 {token, refresh}` — hash claim diperbarui |

Kredensial penyegaran berbentuk `<kedaluwarsa>.<id>.<HMAC(secret, hostref \x00 id \x00 kedaluwarsa)>`.
Ganti password tanpa kredensial ini akan **mengunci perangkat selamanya**:
hash claim lama tersimpan di server dan lima kali gagal memicu kunci 15
menit — karena itu jalur ikat ulang wajib menyertakannya.
  Format (IDENTIK di Worker Cloudflare dan server Go self-host):

  ```
  <detik-unix>.<purpose>.<sig>
  sig = HMAC-SHA256(secret, purpose \x00 role \x00 <detik-unix>)
  ```

  **Role ikut ditandatangani** — token untuk `role=client` tidak bisa dipakai
  ulang sebagai `host`, dan sebaliknya. `purpose` = deviceId (host) atau
  `client`.
- `id` dan `role` di URL diwajibkan cocok dengan token; pesan `hello` tidak
  dapat mengganti identitas setelah gerbang auth.
- `deviceId` unik per perangkat; duplikat online ditolak (`id sudah online`).

Terbitkan token:

```bash
# Cloudflare (produksi): endpoint operator /issue (header X-Admin).
curl -H "X-Admin: $ADMIN_SECRET" "https://signal.xydesk.my.id/issue?purpose=gaming-pc-01"

# Server Go (self-host): flag -issue, role dipilih eksplisit.
XYDESK_SECRET=... ./signaling -issue gaming-pc-01 -role host
XYDESK_SECRET=... ./signaling -issue client-abc -role client
```

## Tipe pesan

| Tipe | Arah | Isi | Arti |
|---|---|---|---|
| `hello` | c→s | `to`=id, `from`=nama, `reason`=platform | daftar perangkat (`id` wajib cocok dengan token; role diambil dari token, bukan pesan) |
| `welcome` | s→c | `from`=id | ack registrasi |
| `pair` | client→host | `to`, `pin` | minta pairing (PIN diverifikasi host) |
| `pair-response` | host→client | `to`, `accepted` | terima/tolak |
| `offer` / `answer` | peer↔peer | `to`, `sdp` | negosiasi WebRTC |
| `ice` | peer↔peer | `to`, `candidate` | ICE candidate |
| `bye` | peer↔peer | `to` | sesi berakhir |
| `list` | c→s | — | minta daftar perangkat |
| `devices` | s→c | `devices[]` | daftar perangkat — id client TIDAK PERNAH disiarkan. Worker Cloudflare mengembalikan kosong; server Go self-host membagikan host saja (disiarkan otomatis saat host naik/turun) |
| `ping` / `pong` | dua arah | — | keep-alive (server juga ping level WS) |
| `error` | s→c | `error`, `reason` | kesalahan |

## Aturan yang ditegakkan server

1. `from` **selalu** ditimpa server dengan id pengirim — peer tak bisa memalsukan identitas.
2. Relay hanya ke peer yang **online**; selain itu `error: peer-offline`.
3. PIN pairing **tidak disimpan server** — diverifikasi di host.
4. Idle > 90 detik tanpa pong → koneksi ditutup (sweeper).

## Alur pairing (urutan normal)

```
client                server                 host
  |-- hello ----------->|                     |
  |<-- welcome ---------|                     |
  |                     |<-- hello -----------|
  |                     |-- welcome --------->|
  |-- list ------------>|                     |
  |<-- devices ---------|                     |
  |-- pair (pin) ------>|-- pair (pin) ------>|
  |<-- pair-response ---|<-- pair-response ---|
  |-- offer ----------->|-- offer ----------->|
  |<-- answer ----------|<-- answer ----------|
  |<-- ice ------------>|-- ice ------------->|
  |       ... WebRTC tersambung, media end-to-end ...       |
  |-- bye ------------->|-- bye ------------->|
```

## Contoh JSON

```json
{"type":"pair","to":"gaming-pc-01","pin":"483920"}
{"type":"pair-response","to":"pixel-7","accepted":true}
{"type":"offer","to":"gaming-pc-01","sdp":{"type":"offer","sdp":"v=0..."}}
{"type":"ice","to":"gaming-pc-01","candidate":{"candidate":"...","sdpMid":"0"}}
```

## Keamanan

- **Media**: WebRTC DTLS-SRTP, end-to-end. Server tidak bisa menyadap.
- **Transport signaling**: pasang TLS (Caddy/nginx di depan) agar SDP/ICE
  tidak bisa disadap dan pairing tidak bisa dibajak. Di LAN murni boleh tanpa TLS.
- **Token**: HMAC 5 menit — kompromi secret = kompromi semua; rotasi secret
  wajib saat bocor. Umur pendek ini **hanya berlaku saat handshake**: sesi
  yang sudah tersambung tidak diperiksa ulang.
- **Kredensial penyegaran host** (90 hari): identitas perangkat yang menetap,
  diterbitkan bersama token pertama dan disimpan di berkas identitas host —
  bukan di command line. Host menukarnya menjadi token sesi kapan saja tanpa
  password pairing, sehingga menyambung ulang tidak lagi mematikan engine.
  Kredensial ini juga satu-satunya bukti "ini perangkat yang sama" saat
  password pairing diganti (lihat `/host-token` di bawah).
