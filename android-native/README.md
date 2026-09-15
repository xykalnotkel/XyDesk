# XyDesk Android Native

Project Android native XyDesk berbasis Kotlin, Jetpack Compose, AndroidX,
WebRTC Android resmi, dan JNI library milik XyDesk. Package: `net.xyspace.xydesk`.

Jalur APK produk sekarang memakai project ini. Tidak ada Flutter, `libflutter.so`,
atau renderer Flutter di artifact native. Source Flutter lama tidak menjadi
input build APK native.

## Lapisan native

- `xydesk_control.so`: state dan kontrak kontrol sesi.
- `xydesk_audio.so`: clock audio dan format PCM dasar untuk jalur Android.
- `xydesk_streamer.so`: lifecycle media client milik XyDesk; integrasi WebRTC
  native menjadi sumber media.
- `xydesk_bridge.so`: JNI tipis yang menghubungkan library tersebut ke Kotlin.
- `libjingle_peerconnection_so.so`: runtime WebRTC resmi dari AAR Android,
  wajib ada untuk media video/audio di setiap ABI.
- `InputCodec.kt`: port Kotlin dari `lib/webrtc/input_codec.dart`; byte wire
  harus identik dengan `host/src/input.rs`.

`libstreamer.so` StarDesk tidak disalin dan tidak boleh dipakai sebagai
ketergantungan tersembunyi. Itu bukan nama library XyDesk dan artefak publik
StarDesk tidak membuktikan lisensi, ABI, atau protokol yang cocok. Pengganti
media native yang benar adalah kombinasi `libjingle_peerconnection_so.so`
resmi + `libxydesk_streamer.so` milik XyDesk.

## ABI

Target awal adalah `arm64-v8a` dan `armeabi-v7a`, sama seperti APK Flutter
rilis. `x86` dan `x86_64` tidak termasuk target perangkat XyDesk.

## Status

Native client sekarang mencakup alur auth OTP dan secure storage, QR pairing,
riwayat host terenkripsi, signaling WebSocket, WebRTC video/audio/mikrofon,
kontrol mouse/keyboard/clipboard/display, PiP, foreground notification,
auto-reconnect terbatas, stats sesi, pengaturan persisten, dan pemeriksaan
update resmi. UI Compose tetap jujur menampilkan error pairing, host offline,
host sibuk, dan kegagalan ICE.

Artifact native debug dipakai untuk uji perangkat sebelum ada keputusan
release. Acceptance test operator wajib mencakup auth Google/OTP/guest,
QR pairing, audio, video, input, PiP, reconnect, update, dan lifecycle.
Build CI sedang dijalankan; release tetap tidak dibuat sebelum operator
mengonfirmasi APK dan perangkat berfungsi.
