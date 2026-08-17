# XyDesk — aturan ProGuard/R8 untuk build rilis.
#
# Prinsipnya: buang sebanyak mungkin, TAPI jangan pernah membuang kelas yang
# hanya dirujuk lewat refleksi atau JNI. R8 tidak bisa melihat rujukan semacam
# itu, jadi setiap keep rule di bawah punya alasan yang ditulis eksplisit.
# Keep rule tanpa alasan adalah utang teknis: ia membesarkan APK diam-diam.

# ── Flutter engine ──────────────────────────────────────────────────────
# Embedding dipanggil dari kode native lewat JNI. Tanpa keep, aplikasi crash
# saat start dengan ClassNotFoundException yang membingungkan.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter embedding memuat dukungan opsional deferred components untuk Android
# App Bundle. XyDesk merilis APK tunggal dan tidak memakai deferred components,
# sehingga Play Feature Delivery sengaja tidak menjadi dependensi. Tanpa aturan
# ini R8 gagal pada referensi opsional SplitInstall walau jalurnya tidak pernah
# dipakai (Build run #32031233134).
-dontwarn com.google.android.play.core.**

# ── flutter_webrtc / libjingle ──────────────────────────────────────────
# libjingle_peerconnection_so.so memanggil balik kelas Java ini lewat JNI.
# Obfuscation di sini memutus jembatan JNI dan mematikan seluruh sesi WebRTC.
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**

# ── MainActivity dan MethodChannel update ───────────────────────────────
# Nama kelas dirujuk dari AndroidManifest dan dari sisi Dart lewat nama
# channel. Isinya boleh diobfuscate; yang wajib bertahan adalah nama kelas
# dan entry point Activity-nya.
-keep class com.xystudio.xydesk.MainActivity { *; }

# ── OneSignal ───────────────────────────────────────────────────────────
# Payload push dideserialisasi lewat refleksi.
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# ── Google Play Services / Sign-In ──────────────────────────────────────
# Model auth dibangun lewat refleksi oleh SDK.
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.libraries.identity.googleid.** { *; }

# ── androidx.security / flutter_secure_storage ──────────────────────────
# Keystore diakses lewat provider yang di-resolve saat runtime.
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# ── Kotlin coroutines ───────────────────────────────────────────────────
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**

# ── Anotasi yang dipakai R8 untuk keputusan keep ────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ── Jejak crash tetap terbaca ───────────────────────────────────────────
# Tanpa ini, stack trace produksi jadi nomor baris acak dan mustahil dibaca.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
