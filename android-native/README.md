# XyDesk Android Native

Project Android native untuk migrasi client XyDesk dari Flutter ke Kotlin,
Jetpack Compose, dan AndroidX.

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

Scaffold ini adalah fondasi migrasi: Compose, JNI, tiga library native, dan
port codec input sudah disiapkan. Signaling, PeerConnection, audio route,
MediaProjection, auth, PiP, dan seluruh layar produk dipindahkan bertahap
setelah kontrak byte dan build native terkunci.
