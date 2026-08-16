# Protokol Signaling XyDesk

WebSocket ber-autentikasi, JSON per frame. Server = **relay SDP/ICE murni**,
tidak pernah menyentuh media. Desain ini membuat server ringan dan privat.

## Koneksi

```
GET /ws?id=<deviceId>&role=host|client
Authorization: Bearer <token>
```

- `token` = HMAC-SHA256 berumur 5 menit, diterbitkan dengan secret bersama.
  Buat token: `XYDESK_SECRET=... ./signaling -issue <deviceId>`.
- `deviceId` unik per perangkat; duplikat online ditolak (`id sudah online`).

## Tipe pesan

| Tipe | Arah | Isi | Arti |
|---|---|---|---|
| `hello` | c→s | `to`=id, `from`=nama, `reason`=role/platform | daftar perangkat |
| `welcome` | s→c | `from`=id | ack registrasi |
| `pair` | client→host | `to`, `pin` | minta pairing (PIN diverifikasi host) |
| `pair-response` | host→client | `to`, `accepted` | terima/tolak |
| `offer` / `answer` | peer↔peer | `to`, `sdp` | negosiasi WebRTC |
| `ice` | peer↔peer | `to`, `candidate` | ICE candidate |
| `bye` | peer↔peer | `to` | sesi berakhir |
| `list` | c→s | — | minta daftar perangkat |
| `devices` | s→c | `devices[]` | daftar (juga disiarkan otomatis) |
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
  wajib saat bocor.
