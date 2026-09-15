# XyDesk Android Native

Project Android native untuk migrasi client XyDesk dari Flutter ke Kotlin,
Jetpack Compose, dan AndroidX. Package rebrand: `net.xyspace.xydesk`.

Project ini sengaja berdiri di samping `android/` yang masih menjadi build
Flutter. APK native belum menggantikan APK Flutter dan belum masuk artifact
rilis.

## Lapisan native

- `xydesk_control.so`: state dan kontrak kontrol sesi.
- `xydesk_audio.so`: clock audio dan format PCM dasar untuk jalur Android.
- `xydesk_streamer.so`: lifecycle media client; integrasi WebRTC native menjadi
  sumber media, bukan renderer Flutter.
- `xydesk_bridge.so`: JNI tipis yang menghubungkan library tersebut ke Kotlin.
- `InputCodec.kt`: port Kotlin dari `lib/webrtc/input_codec.dart`; byte wire
  harus identik dengan `host/src/input.rs`.

Library StarDesk seperti `libstreamer.so` tidak dipakai. XyDesk membangun
library miliknya sendiri dan menggunakan WebRTC Android SDK sebagai transport
media terbuka.

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

`android/` Flutter masih fallback. Native belum boleh menggantikan fallback
sebelum satu full GitHub Actions build menghasilkan artifact dan pengujian
perangkat operator membuktikan auth, pairing, audio, video, input, PiP,
reconnect, update, serta lifecycle. Build/CI dan device test sengaja belum
dijalankan pada tahap implementasi ini.
