# XyDesk Client — integrasi WebRTC (drop-in)

Kode Dart yang menyambungkan app Flutter-mu (yang sudah punya `SessionPage`)
ke signaling server (Cloudflare Worker) dan ke aliran video WebRTC sungguhan —
menggantikan `RTCVideoView` placeholder.

## File

| File | Peran |
|---|---|
| `lib/webrtc/signaling_client.dart` | koneksi WebSocket ke signaling (hello/pair/offer/answer/ice) |
| `lib/webrtc/rtc_service.dart` | RTCPeerConnection + data channel input + render + TURN |

## Dependensi tambahan (tambah ke pubspec.yaml)

```yaml
dependencies:
  flutter_webrtc: ^0.10.5   # WebRTC (mitra webrtc-rs di host)
  web_socket_channel: ^3.0.0 # signaling WebSocket
  http: ^1.2.0               # fetch kredensial TURN dari /turn-ice
```

## Cara sambung ke SessionPage

`SessionPage` sekarang menampilkan placeholder. Ganti dengan:

```dart
final rtc = RtcService();
final video = await rtc.startSession(
  signalingUrl: 'wss://signal.xystudio.my.id/ws', // Cloudflare, gratis
  hostId: 'gaming-pc-01',
  token: '<token client>',
  deviceId: 'pixel-7',
);
// tampilkan di widget:
RTCVideoView(video.renderer, mirror: false);
```

## ICE: STUN + TURN otomatis

- STUN default = `stun.cloudflare.com` (gratis tanpa batas).
- TURN (`turn.cloudflare.com`, 1 TB/bln gratis) **otomatis diambil** dari
  endpoint `/turn-ice` dengan token signaling perangkat (bukan admin secret).
  Bila TURN belum dikonfigurasi, client lanjut pakai STUN saja (cukup untuk
  LAN & mayoritas NAT).

## Alur (client sebagai penelepon)

1. `SignalingClient.connect` → kirim `hello` role=client.
2. `pair` ke host (bawa PIN 6 digit).
3. Terima `pair-response` accepted → buat `RTCPeerConnection`, `createOffer`.
4. Kirim `offer` → terima `answer` → `setRemoteDescription`.
5. Tukar `ice` bolak-balik.
6. `onTrack` → render `RTCVideoView`. Input mouse/keyboard dikirim lewat
   data channel (reliable).

## Catatan

- PIN pairing dikirim lewat `pair`; verifikasi terjadi di host (lihat
  `../host/`). Client tidak memverifikasi apa pun.
- Token: minta dari server (`/issue`), jangan hardcode.
