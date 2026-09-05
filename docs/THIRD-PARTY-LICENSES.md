# Lisensi Pihak Ketiga — XyDesk

> **Berkas ini dihasilkan otomatis. Jangan diedit tangan.**
> Perbarui dengan `node tool/gen-licenses.mjs` setelah mengubah dependensi.
> CI memverifikasinya lewat `node tool/gen-licenses.mjs --check`.

XyDesk sendiri adalah perangkat lunak **proprietary** (lihat `LICENSE`).
Dokumen ini mendaftar **seluruh** komponen pihak ketiga yang ikut terkirim
bersama aplikasi, beserta lisensinya — diambil langsung dari lockfile dan
teks lisensi paket yang benar-benar terpasang, bukan dari daftar ketik
tangan yang bisa ketinggalan zaman.

**Total komponen: 503**
(Dart/Flutter 109 · Rust 324 · npm 59 · aset & layanan 11)

## Ringkasan lisensi

| Lisensi | Jumlah komponen |
|---|---|
| tidak dinyatakan | 326 |
| BSD-3-Clause | 90 |
| MIT | 42 |
| Apache-2.0 | 19 |
| LGPL-3.0-or-later | 8 |
| ISC | 4 |
| Apache-2.0 AND LGPL-3.0-or-later | 2 |
| Apache-2.0 AND LGPL-3.0-or-later AND MIT | 1 |
| CC-BY-4.0 | 1 |
| 0BSD | 1 |
| OFL-1.1 | 1 |
| CC0-1.0 | 1 |
| BSD-2-Clause | 1 |
| NVIDIA Software License Agreement | 1 |
| MIT OR Apache-2.0 | 1 |
| Modified MIT (ketentuan layanan OneSignal) | 1 |
| Ketentuan Layanan Cloudflare | 1 |
| Ketentuan Layanan Resend | 1 |
| Ketentuan Layanan Google API | 1 |

### Perhatian — komponen copyleft (11)

Komponen berikut memakai lisensi copyleft. Tidak ada yang ditaut statis ke
biner XyDesk, tetapi keberadaannya harus disebut dan ditinjau ulang setiap
kali rantai dependensi berubah:

- `@img/sharp-libvips-darwin-arm64` 1.0.4 — **LGPL-3.0-or-later** · JavaScript (npm — desktop)
- `@img/sharp-libvips-darwin-x64` 1.0.4 — **LGPL-3.0-or-later** · JavaScript (npm — desktop)
- `@img/sharp-libvips-linux-arm` 1.0.5 — **LGPL-3.0-or-later** · JavaScript (npm — desktop)
- `@img/sharp-libvips-linux-arm64` 1.0.4 — **LGPL-3.0-or-later** · JavaScript (npm — desktop)
- `@img/sharp-libvips-linux-s390x` 1.0.4 — **LGPL-3.0-or-later** · JavaScript (npm — desktop)
- `@img/sharp-libvips-linux-x64` 1.0.4 — **LGPL-3.0-or-later** · JavaScript (npm — desktop)
- `@img/sharp-libvips-linuxmusl-arm64` 1.0.4 — **LGPL-3.0-or-later** · JavaScript (npm — desktop)
- `@img/sharp-libvips-linuxmusl-x64` 1.0.4 — **LGPL-3.0-or-later** · JavaScript (npm — desktop)
- `@img/sharp-wasm32` 0.33.5 — **Apache-2.0 AND LGPL-3.0-or-later AND MIT** · JavaScript (npm — desktop)
- `@img/sharp-win32-ia32` 0.33.5 — **Apache-2.0 AND LGPL-3.0-or-later** · JavaScript (npm — desktop)
- `@img/sharp-win32-x64` 0.33.5 — **Apache-2.0 AND LGPL-3.0-or-later** · JavaScript (npm — desktop)

Ekspresi ber-OR yang menyediakan alternatif permisif (mis. `MIT OR
Apache-2.0 OR LGPL-2.1-or-later` pada `r-efi`) sengaja TIDAK didaftar di
sini: kita memilih alternatif permisifnya, jadi tidak ada kewajiban copyleft
yang timbul.

Seluruh komponen di atas adalah biner prebuilt `sharp`/`libvips` yang dipakai oleh
perangkat build (optimasi gambar Next.js) dan **tidak ikut dikirim** ke
perangkat pengguna dalam APK, EXE, maupun bundle web. LGPL terpenuhi karena
pustaka dipakai apa adanya, tanpa modifikasi dan tanpa penautan statis.

---

## 1. Aset, SDK, dan layanan

### libopus — BSD-3-Clause

Codec audio Opus — Xiph.Org Foundation. Dikompilasi statis oleh host/build.rs.

*Ekosistem: Source di-vendor (host/vendor/opus) · Versi: 1.5.2*

### Inter — OFL-1.1

Font antarmuka — Rasmus Andersson. Di-bundle, bukan diunduh runtime.

*Ekosistem: Font (assets/fonts) · Versi: 3.19*

### Simple Icons — CC0-1.0

Logo resmi WhatsApp, Telegram, X, dan Facebook pada tombol berbagi. Data path disalin ke web/src/brand-icons.tsx dan lib/widgets/brand_icons.dart, bukan dipasang sebagai dependensi. CC0 tidak menuntut atribusi; dicantumkan karena memang dipakai. Merek dagang tetap milik masing-masing pemiliknya.

*Ekosistem: Set ikon · Versi: 13.21.0*

### Lucide Icons — ISC

Turunan Feather Icons (MIT), proyek Lucide.

*Ekosistem: Set ikon · Versi: via lucide_icons_flutter*

### OpenH264 — BSD-2-Clause

Encode H.264 perangkat lunak. Biaya paten MPEG LA ditanggung Cisco hanya untuk biner resmi Cisco; XyDesk menautkan build sendiri.

*Ekosistem: Encoder video (Cisco) · Versi: via crate openh264*

### NVIDIA Video Codec SDK (NVENC) — NVIDIA Software License Agreement

Hanya header yang dipakai; runtime datang dari driver NVIDIA pengguna.

*Ekosistem: SDK biner (opsional saat GPU NVIDIA ada) · Versi: 12.2*

### windows-capture / windows-rs — MIT OR Apache-2.0

Capture layar Windows.Graphics.Capture dan binding Win32.

*Ekosistem: Binding Windows · Versi: lihat Cargo.lock*

### OneSignal SDK — Modified MIT (ketentuan layanan OneSignal)

SDK klien Android; pengiriman memakai REST API OneSignal.

*Ekosistem: SDK push notifikasi · Versi: 5.x*

### Cloudflare Workers, D1, TURN — Ketentuan Layanan Cloudflare

Signaling, basis data berita, dan relay TURN. Bukan komponen yang didistribusikan.

*Ekosistem: Layanan awan · Versi: -*

### Resend — Ketentuan Layanan Resend

Pengiriman email OTP dan berita.

*Ekosistem: Layanan awan · Versi: -*

### Google Sign-In / Identity Services — Ketentuan Layanan Google API

Login opsional dengan akun Google.

*Ekosistem: Layanan awan · Versi: via google_sign_in*

---

## 2. Paket Dart / Flutter (109)

Termasuk dependensi transitif yang ikut ter-bundle di APK.

| Komponen | Versi | Lisensi |
|---|---|---|
| `args` | 2.7.0 | BSD-3-Clause |
| `async` | 2.11.0 | BSD-3-Clause |
| `characters` | 1.4.1 | BSD-3-Clause |
| `clock` | 1.1.2 | Apache-2.0 |
| `code_assets` | 1.2.1 | BSD-3-Clause |
| `collection` | 1.19.1 | BSD-3-Clause |
| `cross_file` | 0.3.5+5 | BSD-3-Clause |
| `crypto` | 3.0.7 | BSD-3-Clause |
| `dart_webrtc` | 1.8.1 | MIT |
| `ffi` | 2.2.0 | BSD-3-Clause |
| `ffi_leak_tracker` | 0.1.2 | BSD-3-Clause |
| `file` | 7.0.1 | BSD-3-Clause |
| `file_selector_linux` | 0.9.4+1 | BSD-3-Clause |
| `file_selector_macos` | 0.9.5+1 | BSD-3-Clause |
| `file_selector_platform_interface` | 2.7.0 | BSD-3-Clause |
| `file_selector_windows` | 0.9.3+6 | BSD-3-Clause |
| `flutter_plugin_android_lifecycle` | 2.0.35 | BSD-3-Clause |
| `flutter_riverpod` | 2.6.1 | MIT |
| `flutter_secure_storage` | 11.0.0 | BSD-3-Clause |
| `flutter_secure_storage_darwin` | 0.4.0 | BSD-3-Clause |
| `flutter_secure_storage_linux` | 3.0.2 | BSD-3-Clause |
| `flutter_secure_storage_platform_interface` | 2.0.3 | BSD-3-Clause |
| `flutter_secure_storage_web` | 2.1.1 | BSD-3-Clause |
| `flutter_secure_storage_windows` | 4.2.2 | BSD-3-Clause |
| `flutter_svg` | 2.3.0 | MIT |
| `flutter_webrtc` | 1.6.0 | MIT |
| `google_identity_services_web` | 0.3.3+1 | BSD-3-Clause |
| `google_sign_in` | 7.2.0 | BSD-3-Clause |
| `google_sign_in_android` | 7.2.16 | BSD-3-Clause |
| `google_sign_in_ios` | 6.3.0 | BSD-3-Clause |
| `google_sign_in_platform_interface` | 3.1.0 | BSD-3-Clause |
| `google_sign_in_web` | 1.1.3 | BSD-3-Clause |
| `hooks` | 2.0.2 | BSD-3-Clause |
| `http` | 1.6.0 | BSD-3-Clause |
| `http_parser` | 4.1.2 | BSD-3-Clause |
| `image_picker` | 1.2.3 | Apache-2.0 |
| `image_picker_android` | 0.8.13+21 | Apache-2.0 |
| `image_picker_for_web` | 3.1.1 | BSD-3-Clause |
| `image_picker_ios` | 0.8.13+7 | Apache-2.0 |
| `image_picker_linux` | 0.2.2 | BSD-3-Clause |
| `image_picker_macos` | 0.2.2+1 | BSD-3-Clause |
| `image_picker_platform_interface` | 2.11.1 | BSD-3-Clause |
| `image_picker_windows` | 0.2.2 | BSD-3-Clause |
| `intl` | 0.20.2 | BSD-3-Clause |
| `jni` | 1.0.3 | BSD-3-Clause |
| `jni_flutter` | 1.0.2 | BSD-3-Clause |
| `jni_util` | 1.0.0 | BSD-3-Clause |
| `js` | 0.7.2 | BSD-3-Clause |
| `logger` | 2.7.0 | MIT |
| `logging` | 1.3.0 | BSD-3-Clause |
| `lucide_icons_flutter` | 3.1.15 | MIT |
| `material_color_utilities` | 0.13.0 | Apache-2.0 |
| `meta` | 1.18.0 | BSD-3-Clause |
| `mime` | 2.1.0 | BSD-3-Clause |
| `mobile_scanner` | 7.4.0 | BSD-3-Clause |
| `objective_c` | 9.5.0 | BSD-3-Clause |
| `onesignal_flutter` | 5.6.7 | MIT |
| `package_config` | 3.0.0 | BSD-3-Clause |
| `package_info_plus` | 10.2.1 | BSD-3-Clause |
| `package_info_plus_platform_interface` | 4.1.0 | BSD-3-Clause |
| `path` | 1.9.1 | BSD-3-Clause |
| `path_parsing` | 1.1.0 | MIT |
| `path_provider` | 2.1.6 | BSD-3-Clause |
| `path_provider_android` | 2.3.1 | BSD-3-Clause |
| `path_provider_foundation` | 2.6.0 | BSD-3-Clause |
| `path_provider_linux` | 2.2.1 | BSD-3-Clause |
| `path_provider_platform_interface` | 2.1.2 | BSD-3-Clause |
| `path_provider_windows` | 2.3.0 | BSD-3-Clause |
| `petitparser` | 7.0.2 | MIT |
| `platform` | 3.1.6 | BSD-3-Clause |
| `plugin_platform_interface` | 2.1.8 | BSD-3-Clause |
| `pub_semver` | 2.2.0 | BSD-3-Clause |
| `record_use` | 0.6.0 | BSD-3-Clause |
| `riverpod` | 2.6.1 | MIT |
| `shared_preferences` | 2.5.3 | BSD-3-Clause |
| `shared_preferences_android` | 2.4.11 | BSD-3-Clause |
| `shared_preferences_foundation` | 2.5.4 | BSD-3-Clause |
| `shared_preferences_linux` | 2.4.1 | BSD-3-Clause |
| `shared_preferences_platform_interface` | 2.4.1 | BSD-3-Clause |
| `shared_preferences_web` | 2.4.3 | BSD-3-Clause |
| `shared_preferences_windows` | 2.4.1 | BSD-3-Clause |
| `source_span` | 1.10.0 | BSD-3-Clause |
| `stack_trace` | 1.12.1 | BSD-3-Clause |
| `state_notifier` | 1.0.0 | MIT |
| `stream_channel` | 2.1.4 | BSD-3-Clause |
| `string_scanner` | 1.3.0 | BSD-3-Clause |
| `synchronized` | 3.4.1+2 | MIT |
| `term_glyph` | 1.2.1 | BSD-3-Clause |
| `typed_data` | 1.4.0 | BSD-3-Clause |
| `url_launcher` | 6.3.2 | BSD-3-Clause |
| `url_launcher_android` | 6.3.17 | BSD-3-Clause |
| `url_launcher_ios` | 6.3.3 | BSD-3-Clause |
| `url_launcher_linux` | 3.2.1 | BSD-3-Clause |
| `url_launcher_macos` | 3.2.2 | BSD-3-Clause |
| `url_launcher_platform_interface` | 2.3.2 | BSD-3-Clause |
| `url_launcher_web` | 2.4.1 | Apache-2.0 |
| `url_launcher_windows` | 3.1.4 | BSD-3-Clause |
| `vector_graphics` | 1.2.3 | BSD-3-Clause |
| `vector_graphics_codec` | 1.1.13 | BSD-3-Clause |
| `vector_graphics_compiler` | 1.3.0 | BSD-3-Clause |
| `vector_math` | 2.2.0 | BSD-3-Clause |
| `web` | 1.1.1 | BSD-3-Clause |
| `web_socket` | 1.0.1 | BSD-3-Clause |
| `web_socket_channel` | 3.0.3 | BSD-3-Clause |
| `webrtc_interface` | 1.5.1 | MIT |
| `win32` | 6.4.0 | BSD-3-Clause |
| `xdg_directories` | 1.1.0 | BSD-3-Clause |
| `xml` | 7.0.1 | MIT |
| `yaml` | 3.1.3 | MIT |

---

## 3. Crate Rust — aplikasi Host (324)

Termasuk dependensi transitif yang ikut ditaut statis ke `xydesk.exe` dan
`xydesk-host.exe`.

| Komponen | Versi | Lisensi |
|---|---|---|
| `adler2` | 2.0.1 | tidak dinyatakan |
| `aead` | 0.5.2 | tidak dinyatakan |
| `aes` | 0.8.4 | tidak dinyatakan |
| `aes-gcm` | 0.10.3 | tidak dinyatakan |
| `aho-corasick` | 1.1.5 | tidak dinyatakan |
| `anstream` | 1.0.0 | tidak dinyatakan |
| `anstyle` | 1.0.14 | tidak dinyatakan |
| `anstyle-parse` | 1.0.0 | tidak dinyatakan |
| `anstyle-query` | 1.1.5 | tidak dinyatakan |
| `anstyle-wincon` | 3.0.11 | tidak dinyatakan |
| `anyhow` | 1.0.104 | tidak dinyatakan |
| `arc-swap` | 1.9.2 | tidak dinyatakan |
| `asn1-rs` | 0.5.2 | tidak dinyatakan |
| `asn1-rs` | 0.6.2 | tidak dinyatakan |
| `asn1-rs-derive` | 0.4.0 | tidak dinyatakan |
| `asn1-rs-derive` | 0.5.1 | tidak dinyatakan |
| `asn1-rs-impl` | 0.1.0 | tidak dinyatakan |
| `asn1-rs-impl` | 0.2.0 | tidak dinyatakan |
| `async-trait` | 0.1.92 | tidak dinyatakan |
| `atomic-waker` | 1.1.2 | tidak dinyatakan |
| `autocfg` | 1.5.1 | tidak dinyatakan |
| `axum` | 0.8.9 | tidak dinyatakan |
| `axum-core` | 0.5.6 | tidak dinyatakan |
| `base16ct` | 0.2.0 | tidak dinyatakan |
| `base64` | 0.21.7 | tidak dinyatakan |
| `base64` | 0.22.1 | tidak dinyatakan |
| `base64ct` | 1.8.3 | tidak dinyatakan |
| `bincode` | 1.3.3 | tidak dinyatakan |
| `bitflags` | 1.3.2 | tidak dinyatakan |
| `bitflags` | 2.13.1 | tidak dinyatakan |
| `block-buffer` | 0.10.4 | tidak dinyatakan |
| `block-padding` | 0.3.3 | tidak dinyatakan |
| `bumpalo` | 3.20.3 | tidak dinyatakan |
| `bytemuck` | 1.25.2 | tidak dinyatakan |
| `byteorder` | 1.5.0 | tidak dinyatakan |
| `bytes` | 1.12.1 | tidak dinyatakan |
| `cbc` | 0.1.2 | tidak dinyatakan |
| `cc` | 1.4.3 | tidak dinyatakan |
| `ccm` | 0.5.0 | tidak dinyatakan |
| `cfg-if` | 1.0.4 | tidak dinyatakan |
| `cipher` | 0.4.4 | tidak dinyatakan |
| `clap` | 4.6.6 | tidak dinyatakan |
| `clap_builder` | 4.6.6 | tidak dinyatakan |
| `clap_derive` | 4.6.4 | tidak dinyatakan |
| `clap_lex` | 1.1.0 | tidak dinyatakan |
| `colorchoice` | 1.0.5 | tidak dinyatakan |
| `const-oid` | 0.9.6 | tidak dinyatakan |
| `core-foundation` | 0.9.4 | tidak dinyatakan |
| `core-foundation-sys` | 0.8.7 | tidak dinyatakan |
| `cpufeatures` | 0.2.17 | tidak dinyatakan |
| `crc` | 3.4.0 | tidak dinyatakan |
| `crc-catalog` | 2.5.0 | tidak dinyatakan |
| `crc32fast` | 1.5.0 | tidak dinyatakan |
| `crossbeam-deque` | 0.8.7 | tidak dinyatakan |
| `crossbeam-epoch` | 0.9.20 | tidak dinyatakan |
| `crossbeam-utils` | 0.8.22 | tidak dinyatakan |
| `crypto-bigint` | 0.5.5 | tidak dinyatakan |
| `crypto-common` | 0.1.7 | tidak dinyatakan |
| `ctr` | 0.9.2 | tidak dinyatakan |
| `curve25519-dalek` | 4.1.3 | tidak dinyatakan |
| `curve25519-dalek-derive` | 0.1.1 | tidak dinyatakan |
| `data-encoding` | 2.11.1 | tidak dinyatakan |
| `der` | 0.7.10 | tidak dinyatakan |
| `der-parser` | 8.2.0 | tidak dinyatakan |
| `der-parser` | 9.0.0 | tidak dinyatakan |
| `deranged` | 0.5.8 | tidak dinyatakan |
| `digest` | 0.10.7 | tidak dinyatakan |
| `displaydoc` | 0.2.7 | tidak dinyatakan |
| `ecdsa` | 0.16.9 | tidak dinyatakan |
| `either` | 1.17.0 | tidak dinyatakan |
| `elliptic-curve` | 0.13.8 | tidak dinyatakan |
| `errno` | 0.3.14 | tidak dinyatakan |
| `ff` | 0.13.1 | tidak dinyatakan |
| `fiat-crypto` | 0.2.9 | tidak dinyatakan |
| `find-msvc-tools` | 0.1.11 | tidak dinyatakan |
| `flate2` | 1.1.9 | tidak dinyatakan |
| `form_urlencoded` | 1.2.2 | tidak dinyatakan |
| `futures` | 0.3.34 | tidak dinyatakan |
| `futures-channel` | 0.3.34 | tidak dinyatakan |
| `futures-core` | 0.3.34 | tidak dinyatakan |
| `futures-executor` | 0.3.34 | tidak dinyatakan |
| `futures-io` | 0.3.34 | tidak dinyatakan |
| `futures-macro` | 0.3.34 | tidak dinyatakan |
| `futures-sink` | 0.3.34 | tidak dinyatakan |
| `futures-task` | 0.3.34 | tidak dinyatakan |
| `futures-util` | 0.3.34 | tidak dinyatakan |
| `generic-array` | 0.14.7 | tidak dinyatakan |
| `getrandom` | 0.2.17 | tidak dinyatakan |
| `getrandom` | 0.4.3 | tidak dinyatakan |
| `ghash` | 0.5.1 | tidak dinyatakan |
| `group` | 0.13.0 | tidak dinyatakan |
| `heck` | 0.5.0 | tidak dinyatakan |
| `hex` | 0.4.3 | tidak dinyatakan |
| `hkdf` | 0.12.4 | tidak dinyatakan |
| `hmac` | 0.12.1 | tidak dinyatakan |
| `http` | 1.5.0 | tidak dinyatakan |
| `http-body` | 1.1.0 | tidak dinyatakan |
| `http-body-util` | 0.1.5 | tidak dinyatakan |
| `httparse` | 1.10.1 | tidak dinyatakan |
| `httpdate` | 1.0.3 | tidak dinyatakan |
| `hyper` | 1.11.1 | tidak dinyatakan |
| `hyper-util` | 0.1.20 | tidak dinyatakan |
| `icu_collections` | 2.3.0 | tidak dinyatakan |
| `icu_locale_core` | 2.3.0 | tidak dinyatakan |
| `icu_normalizer` | 2.3.0 | tidak dinyatakan |
| `icu_normalizer_data` | 2.3.0 | tidak dinyatakan |
| `icu_properties` | 2.3.0 | tidak dinyatakan |
| `icu_properties_data` | 2.3.0 | tidak dinyatakan |
| `icu_provider` | 2.3.0 | tidak dinyatakan |
| `idna` | 1.1.0 | tidak dinyatakan |
| `idna_adapter` | 1.2.2 | tidak dinyatakan |
| `inout` | 0.1.4 | tidak dinyatakan |
| `interceptor` | 0.12.0 | tidak dinyatakan |
| `ipnet` | 2.12.1 | tidak dinyatakan |
| `is_terminal_polyfill` | 1.70.2 | tidak dinyatakan |
| `itoa` | 1.0.18 | tidak dinyatakan |
| `jobserver` | 0.1.35 | tidak dinyatakan |
| `js-sys` | 0.3.104 | tidak dinyatakan |
| `lazy_static` | 1.5.0 | tidak dinyatakan |
| `libc` | 0.2.189 | tidak dinyatakan |
| `litemap` | 0.8.3 | tidak dinyatakan |
| `lock_api` | 0.4.14 | tidak dinyatakan |
| `log` | 0.4.33 | tidak dinyatakan |
| `matchit` | 0.8.4 | tidak dinyatakan |
| `md-5` | 0.10.6 | tidak dinyatakan |
| `memchr` | 2.8.3 | tidak dinyatakan |
| `memoffset` | 0.7.1 | tidak dinyatakan |
| `mime` | 0.3.17 | tidak dinyatakan |
| `minimal-lexical` | 0.2.1 | tidak dinyatakan |
| `miniz_oxide` | 0.8.9 | tidak dinyatakan |
| `mio` | 1.2.2 | tidak dinyatakan |
| `nasm-rs` | 0.3.2 | tidak dinyatakan |
| `nix` | 0.26.4 | tidak dinyatakan |
| `nom` | 7.1.3 | tidak dinyatakan |
| `num-bigint` | 0.4.8 | tidak dinyatakan |
| `num-conv` | 0.2.2 | tidak dinyatakan |
| `num-integer` | 0.1.47 | tidak dinyatakan |
| `num-traits` | 0.2.19 | tidak dinyatakan |
| `oid-registry` | 0.7.1 | tidak dinyatakan |
| `once_cell` | 1.21.4 | tidak dinyatakan |
| `once_cell_polyfill` | 1.70.2 | tidak dinyatakan |
| `opaque-debug` | 0.3.1 | tidak dinyatakan |
| `openh264` | 0.9.8 | tidak dinyatakan |
| `openh264-sys2` | 0.9.8 | tidak dinyatakan |
| `openssl-probe` | 0.1.6 | tidak dinyatakan |
| `p256` | 0.13.2 | tidak dinyatakan |
| `p384` | 0.13.1 | tidak dinyatakan |
| `parking_lot` | 0.12.5 | tidak dinyatakan |
| `parking_lot_core` | 0.9.12 | tidak dinyatakan |
| `pem` | 3.0.6 | tidak dinyatakan |
| `pem-rfc7468` | 0.7.0 | tidak dinyatakan |
| `percent-encoding` | 2.3.2 | tidak dinyatakan |
| `pin-project-lite` | 0.2.17 | tidak dinyatakan |
| `pin-utils` | 0.1.0 | tidak dinyatakan |
| `pkcs8` | 0.10.2 | tidak dinyatakan |
| `polyval` | 0.6.2 | tidak dinyatakan |
| `portable-atomic` | 1.15.0 | tidak dinyatakan |
| `potential_utf` | 0.1.6 | tidak dinyatakan |
| `powerfmt` | 0.2.0 | tidak dinyatakan |
| `ppv-lite86` | 0.2.21 | tidak dinyatakan |
| `primeorder` | 0.13.6 | tidak dinyatakan |
| `proc-macro2` | 1.0.107 | tidak dinyatakan |
| `quote` | 1.0.47 | tidak dinyatakan |
| `r-efi` | 6.0.0 | tidak dinyatakan |
| `rand` | 0.8.7 | tidak dinyatakan |
| `rand_chacha` | 0.3.1 | tidak dinyatakan |
| `rand_core` | 0.6.4 | tidak dinyatakan |
| `rayon` | 1.12.0 | tidak dinyatakan |
| `rayon-core` | 1.13.0 | tidak dinyatakan |
| `rcgen` | 0.13.2 | tidak dinyatakan |
| `redox_syscall` | 0.5.18 | tidak dinyatakan |
| `regex` | 1.13.1 | tidak dinyatakan |
| `regex-automata` | 0.4.18 | tidak dinyatakan |
| `regex-syntax` | 0.8.11 | tidak dinyatakan |
| `rfc6979` | 0.4.0 | tidak dinyatakan |
| `ring` | 0.17.14 | tidak dinyatakan |
| `rtcp` | 0.11.0 | tidak dinyatakan |
| `rtp` | 0.11.0 | tidak dinyatakan |
| `rustc_version` | 0.4.1 | tidak dinyatakan |
| `rusticata-macros` | 4.1.0 | tidak dinyatakan |
| `rustls` | 0.23.43 | tidak dinyatakan |
| `rustls-native-certs` | 0.7.3 | tidak dinyatakan |
| `rustls-pemfile` | 2.2.0 | tidak dinyatakan |
| `rustls-pki-types` | 1.15.1 | tidak dinyatakan |
| `rustls-webpki` | 0.103.14 | tidak dinyatakan |
| `rustversion` | 1.0.23 | tidak dinyatakan |
| `safe_arch` | 1.2.0 | tidak dinyatakan |
| `same-file` | 1.0.6 | tidak dinyatakan |
| `schannel` | 0.1.29 | tidak dinyatakan |
| `scopeguard` | 1.2.0 | tidak dinyatakan |
| `sdp` | 0.6.2 | tidak dinyatakan |
| `sec1` | 0.7.3 | tidak dinyatakan |
| `security-framework` | 2.11.1 | tidak dinyatakan |
| `security-framework-sys` | 2.17.0 | tidak dinyatakan |
| `semver` | 1.0.28 | tidak dinyatakan |
| `serde` | 1.0.229 | tidak dinyatakan |
| `serde_core` | 1.0.229 | tidak dinyatakan |
| `serde_derive` | 1.0.229 | tidak dinyatakan |
| `serde_json` | 1.0.151 | tidak dinyatakan |
| `serde_path_to_error` | 0.1.20 | tidak dinyatakan |
| `sha1` | 0.10.7 | tidak dinyatakan |
| `sha2` | 0.10.9 | tidak dinyatakan |
| `shlex` | 2.0.1 | tidak dinyatakan |
| `signal-hook-registry` | 1.4.8 | tidak dinyatakan |
| `signature` | 2.2.0 | tidak dinyatakan |
| `simd-adler32` | 0.3.10 | tidak dinyatakan |
| `slab` | 0.4.12 | tidak dinyatakan |
| `smallvec` | 1.15.2 | tidak dinyatakan |
| `smol_str` | 0.2.2 | tidak dinyatakan |
| `socket2` | 0.5.10 | tidak dinyatakan |
| `socket2` | 0.6.5 | tidak dinyatakan |
| `spki` | 0.7.3 | tidak dinyatakan |
| `stable_deref_trait` | 1.2.1 | tidak dinyatakan |
| `strsim` | 0.11.1 | tidak dinyatakan |
| `stun` | 0.6.0 | tidak dinyatakan |
| `substring` | 1.4.5 | tidak dinyatakan |
| `subtle` | 2.6.1 | tidak dinyatakan |
| `syn` | 1.0.109 | tidak dinyatakan |
| `syn` | 2.0.119 | tidak dinyatakan |
| `syn` | 3.0.3 | tidak dinyatakan |
| `sync_wrapper` | 1.0.2 | tidak dinyatakan |
| `synstructure` | 0.12.6 | tidak dinyatakan |
| `synstructure` | 0.13.2 | tidak dinyatakan |
| `thiserror` | 1.0.69 | tidak dinyatakan |
| `thiserror` | 2.0.20 | tidak dinyatakan |
| `thiserror-impl` | 1.0.69 | tidak dinyatakan |
| `thiserror-impl` | 2.0.20 | tidak dinyatakan |
| `time` | 0.3.55 | tidak dinyatakan |
| `time-core` | 0.1.9 | tidak dinyatakan |
| `time-macros` | 0.2.32 | tidak dinyatakan |
| `tinystr` | 0.8.4 | tidak dinyatakan |
| `tokio` | 1.53.1 | tidak dinyatakan |
| `tokio-macros` | 2.7.2 | tidak dinyatakan |
| `tokio-rustls` | 0.26.4 | tidak dinyatakan |
| `tokio-tungstenite` | 0.23.1 | tidak dinyatakan |
| `tokio-util` | 0.7.19 | tidak dinyatakan |
| `tower` | 0.5.3 | tidak dinyatakan |
| `tower-layer` | 0.3.3 | tidak dinyatakan |
| `tower-service` | 0.3.3 | tidak dinyatakan |
| `tungstenite` | 0.23.0 | tidak dinyatakan |
| `turn` | 0.8.0 | tidak dinyatakan |
| `typenum` | 1.20.1 | tidak dinyatakan |
| `unicode-ident` | 1.0.24 | tidak dinyatakan |
| `unicode-xid` | 0.2.6 | tidak dinyatakan |
| `universal-hash` | 0.5.1 | tidak dinyatakan |
| `untrusted` | 0.9.0 | tidak dinyatakan |
| `ureq` | 2.12.1 | tidak dinyatakan |
| `url` | 2.5.8 | tidak dinyatakan |
| `utf-8` | 0.7.6 | tidak dinyatakan |
| `utf8_iter` | 1.0.4 | tidak dinyatakan |
| `utf8parse` | 0.2.2 | tidak dinyatakan |
| `uuid` | 1.24.1 | tidak dinyatakan |
| `version_check` | 0.9.5 | tidak dinyatakan |
| `waitgroup` | 0.1.2 | tidak dinyatakan |
| `walkdir` | 2.5.0 | tidak dinyatakan |
| `wasi` | 0.11.1+wasi-snapshot-preview1 | tidak dinyatakan |
| `wasm-bindgen` | 0.2.127 | tidak dinyatakan |
| `wasm-bindgen-macro` | 0.2.127 | tidak dinyatakan |
| `wasm-bindgen-macro-support` | 0.2.127 | tidak dinyatakan |
| `wasm-bindgen-shared` | 0.2.127 | tidak dinyatakan |
| `webpki-roots` | 0.26.11 | tidak dinyatakan |
| `webpki-roots` | 1.0.9 | tidak dinyatakan |
| `webrtc` | 0.11.0 | tidak dinyatakan |
| `webrtc-data` | 0.9.0 | tidak dinyatakan |
| `webrtc-dtls` | 0.10.0 | tidak dinyatakan |
| `webrtc-ice` | 0.11.0 | tidak dinyatakan |
| `webrtc-mdns` | 0.7.0 | tidak dinyatakan |
| `webrtc-media` | 0.8.0 | tidak dinyatakan |
| `webrtc-sctp` | 0.10.0 | tidak dinyatakan |
| `webrtc-srtp` | 0.13.0 | tidak dinyatakan |
| `webrtc-util` | 0.9.0 | tidak dinyatakan |
| `wide` | 1.6.1 | tidak dinyatakan |
| `winapi` | 0.3.9 | tidak dinyatakan |
| `winapi-i686-pc-windows-gnu` | 0.4.0 | tidak dinyatakan |
| `winapi-util` | 0.1.11 | tidak dinyatakan |
| `winapi-x86_64-pc-windows-gnu` | 0.4.0 | tidak dinyatakan |
| `windows` | 0.61.3 | tidak dinyatakan |
| `windows` | 0.62.2 | tidak dinyatakan |
| `windows_aarch64_gnullvm` | 0.52.6 | tidak dinyatakan |
| `windows_aarch64_msvc` | 0.52.6 | tidak dinyatakan |
| `windows_i686_gnu` | 0.52.6 | tidak dinyatakan |
| `windows_i686_gnullvm` | 0.52.6 | tidak dinyatakan |
| `windows_i686_msvc` | 0.52.6 | tidak dinyatakan |
| `windows_x86_64_gnu` | 0.52.6 | tidak dinyatakan |
| `windows_x86_64_gnullvm` | 0.52.6 | tidak dinyatakan |
| `windows_x86_64_msvc` | 0.52.6 | tidak dinyatakan |
| `windows-capture` | 2.0.1 | tidak dinyatakan |
| `windows-collections` | 0.2.0 | tidak dinyatakan |
| `windows-collections` | 0.3.2 | tidak dinyatakan |
| `windows-core` | 0.61.2 | tidak dinyatakan |
| `windows-core` | 0.62.2 | tidak dinyatakan |
| `windows-future` | 0.2.1 | tidak dinyatakan |
| `windows-future` | 0.3.2 | tidak dinyatakan |
| `windows-implement` | 0.60.2 | tidak dinyatakan |
| `windows-interface` | 0.59.3 | tidak dinyatakan |
| `windows-link` | 0.1.3 | tidak dinyatakan |
| `windows-link` | 0.2.1 | tidak dinyatakan |
| `windows-numerics` | 0.2.0 | tidak dinyatakan |
| `windows-numerics` | 0.3.1 | tidak dinyatakan |
| `windows-result` | 0.3.4 | tidak dinyatakan |
| `windows-result` | 0.4.1 | tidak dinyatakan |
| `windows-strings` | 0.4.2 | tidak dinyatakan |
| `windows-strings` | 0.5.1 | tidak dinyatakan |
| `windows-sys` | 0.52.0 | tidak dinyatakan |
| `windows-sys` | 0.61.2 | tidak dinyatakan |
| `windows-targets` | 0.52.6 | tidak dinyatakan |
| `windows-threading` | 0.1.0 | tidak dinyatakan |
| `windows-threading` | 0.2.1 | tidak dinyatakan |
| `writeable` | 0.6.4 | tidak dinyatakan |
| `x25519-dalek` | 2.0.1 | tidak dinyatakan |
| `x509-parser` | 0.16.0 | tidak dinyatakan |
| `yasna` | 0.5.2 | tidak dinyatakan |
| `yoke` | 0.8.3 | tidak dinyatakan |
| `yoke-derive` | 0.8.2 | tidak dinyatakan |
| `zerocopy` | 0.8.56 | tidak dinyatakan |
| `zerocopy-derive` | 0.8.56 | tidak dinyatakan |
| `zerofrom` | 0.1.8 | tidak dinyatakan |
| `zerofrom-derive` | 0.1.7 | tidak dinyatakan |
| `zeroize` | 1.9.0 | tidak dinyatakan |
| `zeroize_derive` | 1.5.0 | tidak dinyatakan |
| `zerotrie` | 0.2.5 | tidak dinyatakan |
| `zerovec` | 0.11.7 | tidak dinyatakan |
| `zerovec-derive` | 0.11.4 | tidak dinyatakan |
| `zmij` | 1.0.23 | tidak dinyatakan |

---

## 4. Paket npm — web, signaling, berita (59)

Hanya dependensi runtime; alat build (`dev`) tidak ikut terkirim ke pengguna.

| Komponen | Versi | Lisensi |
|---|---|---|
| `@emnapi/runtime` | 1.11.3 | MIT |
| `@img/sharp-darwin-arm64` | 0.33.5 | Apache-2.0 |
| `@img/sharp-darwin-x64` | 0.33.5 | Apache-2.0 |
| `@img/sharp-libvips-darwin-arm64` | 1.0.4 | LGPL-3.0-or-later |
| `@img/sharp-libvips-darwin-x64` | 1.0.4 | LGPL-3.0-or-later |
| `@img/sharp-libvips-linux-arm` | 1.0.5 | LGPL-3.0-or-later |
| `@img/sharp-libvips-linux-arm64` | 1.0.4 | LGPL-3.0-or-later |
| `@img/sharp-libvips-linux-s390x` | 1.0.4 | LGPL-3.0-or-later |
| `@img/sharp-libvips-linux-x64` | 1.0.4 | LGPL-3.0-or-later |
| `@img/sharp-libvips-linuxmusl-arm64` | 1.0.4 | LGPL-3.0-or-later |
| `@img/sharp-libvips-linuxmusl-x64` | 1.0.4 | LGPL-3.0-or-later |
| `@img/sharp-linux-arm` | 0.33.5 | Apache-2.0 |
| `@img/sharp-linux-arm64` | 0.33.5 | Apache-2.0 |
| `@img/sharp-linux-s390x` | 0.33.5 | Apache-2.0 |
| `@img/sharp-linux-x64` | 0.33.5 | Apache-2.0 |
| `@img/sharp-linuxmusl-arm64` | 0.33.5 | Apache-2.0 |
| `@img/sharp-linuxmusl-x64` | 0.33.5 | Apache-2.0 |
| `@img/sharp-wasm32` | 0.33.5 | Apache-2.0 AND LGPL-3.0-or-later AND MIT |
| `@img/sharp-win32-ia32` | 0.33.5 | Apache-2.0 AND LGPL-3.0-or-later |
| `@img/sharp-win32-x64` | 0.33.5 | Apache-2.0 AND LGPL-3.0-or-later |
| `@next/env` | 15.1.6 | MIT |
| `@next/swc-darwin-arm64` | 15.1.6 | MIT |
| `@next/swc-darwin-x64` | 15.1.6 | MIT |
| `@next/swc-linux-arm64-gnu` | 15.1.6 | MIT |
| `@next/swc-linux-arm64-musl` | 15.1.6 | MIT |
| `@next/swc-linux-x64-gnu` | 15.1.6 | MIT |
| `@next/swc-linux-x64-musl` | 15.1.6 | MIT |
| `@next/swc-win32-arm64-msvc` | 15.1.6 | MIT |
| `@next/swc-win32-x64-msvc` | 15.1.6 | MIT |
| `@swc/counter` | 0.1.3 | Apache-2.0 |
| `@swc/helpers` | 0.5.15 | Apache-2.0 |
| `busboy` | 1.6.0 | tidak dinyatakan |
| `caniuse-lite` | 1.0.30001810 | CC-BY-4.0 |
| `client-only` | 0.0.1 | MIT |
| `color` | 4.2.3 | MIT |
| `color-convert` | 2.0.1 | MIT |
| `color-name` | 1.1.4 | MIT |
| `color-string` | 1.9.1 | MIT |
| `detect-libc` | 2.1.2 | Apache-2.0 |
| `is-arrayish` | 0.3.4 | MIT |
| `jsqr` | 1.4.0 | Apache-2.0 |
| `lucide-react` | 1.37.0 | ISC |
| `nanoid` | 3.3.18 | MIT |
| `next` | 15.1.6 | MIT |
| `picocolors` | 1.1.1 | ISC |
| `postcss` | 8.4.31 | MIT |
| `react` | 19.2.8 | MIT |
| `react` | 19.0.0 | MIT |
| `react-dom` | 19.2.8 | MIT |
| `react-dom` | 19.0.0 | MIT |
| `scheduler` | 0.27.0 | MIT |
| `scheduler` | 0.25.0 | MIT |
| `semver` | 7.8.5 | ISC |
| `sharp` | 0.33.5 | Apache-2.0 |
| `simple-swizzle` | 0.2.4 | MIT |
| `source-map-js` | 1.2.1 | BSD-3-Clause |
| `streamsearch` | 1.1.0 | tidak dinyatakan |
| `styled-jsx` | 5.1.6 | MIT |
| `tslib` | 2.8.1 | 0BSD |

---

## 3. Teks lisensi lengkap

Teks penuh setiap lisensi tersedia di dalam paketnya masing-masing:

- Dart/Flutter: `~/.pub-cache/hosted/pub.dev/<nama>-<versi>/LICENSE`
- Rust: `~/.cargo/registry/src/*/<nama>-<versi>/LICENSE*`
- libopus: `host/vendor/opus/COPYING`

Di aplikasi Android, **Pengaturan → Tentang → Lisensi → Lisensi pihak ketiga
lengkap** membuka registry lisensi bawaan Flutter yang memuat teks penuh
setiap paket Dart secara langsung dari biner yang sedang berjalan.
