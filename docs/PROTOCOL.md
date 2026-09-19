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


## HOSTGEOMETRY: video, cursor dan preview wallpaper

Tambahan kompatibel pada data channel input yang sudah diotorisasi sesi:
- Biner `0x0C mode:u8` (tepat 2 byte): 0=720p, 1=1080p, 2=native maksimal 4096×2160. Ini batas gambar kirim proporsional, bukan perubahan resolusi/scaling Windows. Host membatasi lagi sesuai SDP constrained-baseline packetization-mode=1: Level3.1 → 1280×720; Level4.0 → 1920×1080; Level5.1 → native hingga4096×2160. Tidak upscale/crop/stretch. Mode native Level5.1 dibatasi15fps; lainnya30fps. Software maksimum14Mbps. Ukuran video yang diterima tetap sumber kebenaran client.
- Web memeriksa MediaCapabilities `webrtc` sebelum menaikkan level SDP. Jika API/level/offer ditolak, kembali ke offer asli Level3.1. Host lama tetap kompatibel tetapi tidak menerima fitur baru ini.
- `meta.video`: level negosiasi, requested (0/1/2), applied `[width,height]` hasil encode atau null, fpsLimit. `meta.inputGeometry`: rect monitor fisik aktif atau null, bukan angka logical DPI. `meta.cursorEmbedded` menandai cursor WGC di dalam frame.
- Pesan teks `cursor` dengan x/y ternormalisasi0..1 dan visible, diambil dari GetCursorInfo Windows maksimal20Hz. Overlay hanya digunakan jika cursor tidak sudah tertanam. Feedback tidak menghasilkan event injeksi baru. Tidak aktif saat geometri belum tersedia.
- Biner `0x0D requestId:u32le` (tepat5byte): permintaan wallpaper manual. Hanya file Windows-configured wallpaper lokal pada fixed drive, menolak UNC/device/relative/ADS/reparse points. Tidak menerima path client, tidak screenshot aplikasi, tidak minimize jendela. Sumber≤16MiB, decoder≤64MiB/alokasi dan≤16384 tiap dimensi; outputJPEG≤1920×1080 tanpa upscale, kualitas90/85/80/75 sampai≤256KiB. Jika gagal, preview lama dipertahankan.
- Balasan teks `{type:"wallpaper",id,index,total,data}`: base64 JPEG berurutan, potongan≤16384 karakter,≤22 potongan, dataURL≤350000 karakter. Kegagalan `{type:"wallpaper-error",id}`. Client timeout15detik dan membatalkan saat disconnect. Host membatasi satu pekerjaan perchannel dan satu permintaan per10detik.
- Penyimpanan riwayat memerlukan consent; JPEG header dibatasi1920×1080. Body≤384KiB dan preview dibagi≤4chunk @96000 karakter agar nilai DurableObject tidak melampaui128KiB. Chunk ikut transaksi akun, retensi20 dan penghapusan/revokasi akun yang sama. Fetch besar tidak memakai keepalive.
- Tamu menyimpan satu preview perID dan membuang preview lebih lama bila kuota habis; preview baru tidak diam-diam dibuang dengan status sukses. Akun disimpan di server, tidak dialihkan ke penyimpanan tamu saat permintaan gagal.
- Input down yang sukses dicatat dan dilepas saat data channel tutup. Antrean dibatasi. Tidak menjamin injeksi ke secure desktop/UAC atau aplikasi dengan privilege lebih tinggi.

Batas bukti: uji SDP/RTP/decoder sintetis bukan bukti Windows/RDP atau Chrome Android nyata. Pergantian monitor/resizing masih memiliki jeda polling500ms dan transport; tidak ada jaminan sinkron per-frame lintas video dan data channel.

## Browser adaptive video and FPS (2026-09-19)
Authenticated input-channel packet `0x0f fps:u8` accepts exactly30 or60. Host advertises `video.fpsControl`, `fpsRequested`, and negotiated `fpsLimit`. Level3.1 caps720p30; Level4.0 allows720p60 but1080p30; Level5.1 allows1080p60, native4K remains15. Never changes the Windows display mode. Actual decoded FPS is measured separately. Old hosts omit capability and receive no FPS command.
Browser presets are bitrate ceilings; interval packet loss, jitter-buffer delay and RTT reduce targets, with12s cooldown and20 healthy samples before gradual recovery. No upscaling or latency guarantee.
