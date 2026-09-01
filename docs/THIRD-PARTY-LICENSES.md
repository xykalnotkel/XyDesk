# Lisensi Pihak Ketiga — XyDesk

> **Berkas ini dihasilkan otomatis. Jangan diedit tangan.**
> Perbarui dengan `node tool/gen-licenses.mjs` setelah mengubah dependensi.
> CI memverifikasinya lewat `node tool/gen-licenses.mjs --check`.

XyDesk sendiri adalah perangkat lunak **proprietary** (lihat `LICENSE`).
Dokumen ini mendaftar **seluruh** komponen pihak ketiga yang ikut terkirim
bersama aplikasi, beserta lisensinya — diambil langsung dari lockfile dan
teks lisensi paket yang benar-benar terpasang, bukan dari daftar ketik
tangan yang bisa ketinggalan zaman.

**Total komponen: 490**
(Dart/Flutter 97 · Rust 324 · npm 58 · aset & layanan 11)

## Ringkasan lisensi

| Lisensi | Jumlah komponen |
|---|---|
| MIT OR Apache-2.0 | 196 |
| BSD-3-Clause | 84 |
| MIT | 73 |
| Apache-2.0 OR MIT | 30 |
| Unicode-3.0 | 18 |
| Apache-2.0 | 17 |
| MIT/Apache-2.0 | 17 |
| LGPL-3.0-or-later | 8 |
| ISC | 6 |
| Unlicense OR MIT | 4 |
| Zlib OR Apache-2.0 OR MIT | 3 |
| BSD-2-Clause | 3 |
| Apache-2.0 OR ISC OR MIT | 3 |
| Unlicense/MIT | 2 |
| CDLA-Permissive-2.0 | 2 |
| BSD-2-Clause OR Apache-2.0 OR MIT | 2 |
| Apache-2.0 AND LGPL-3.0-or-later | 2 |
| tidak dinyatakan | 2 |
| 0BSD OR MIT OR Apache-2.0 | 1 |
| MIT OR Apache-2.0 OR BSD-1-Clause | 1 |
| MIT AND BSD-3-Clause | 1 |
| MIT OR Zlib OR Apache-2.0 | 1 |
| MIT OR Apache-2.0 OR LGPL-2.1-or-later | 1 |
| Apache-2.0 AND ISC | 1 |
| (MIT OR Apache-2.0) AND Unicode-3.0 | 1 |
| Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | 1 |
| Apache-2.0 AND LGPL-3.0-or-later AND MIT | 1 |
| CC-BY-4.0 | 1 |
| 0BSD | 1 |
| OFL-1.1 | 1 |
| CC0-1.0 | 1 |
| NVIDIA Software License Agreement | 1 |
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

## 2. Paket Dart / Flutter (97)

Termasuk dependensi transitif yang ikut ter-bundle di APK.

| Komponen | Versi | Lisensi |
|---|---|---|
| `args` | 2.7.0 | BSD-3-Clause |
| `async` | 2.11.0 | BSD-3-Clause |
| `characters` | 1.4.1 | BSD-3-Clause |
| `clock` | 1.1.2 | Apache-2.0 |
| `code_assets` | 1.2.1 | BSD-3-Clause |
| `collection` | 1.19.1 | BSD-3-Clause |
| `crypto` | 3.0.7 | BSD-3-Clause |
| `dart_webrtc` | 1.8.1 | MIT |
| `ffi` | 2.2.0 | BSD-3-Clause |
| `ffi_leak_tracker` | 0.1.2 | BSD-3-Clause |
| `file` | 7.0.1 | BSD-3-Clause |
| `flutter_lints` | 4.0.0 | BSD-3-Clause |
| `flutter_riverpod` | 2.6.1 | MIT |
| `flutter_secure_storage` | 11.0.0 | BSD-3-Clause |
| `flutter_secure_storage_darwin` | 0.4.0 | BSD-3-Clause |
| `flutter_secure_storage_linux` | 3.0.2 | BSD-3-Clause |
| `flutter_secure_storage_platform_interface` | 2.0.3 | BSD-3-Clause |
| `flutter_secure_storage_web` | 2.1.1 | BSD-3-Clause |
| `flutter_secure_storage_windows` | 4.2.2 | BSD-3-Clause |
| `flutter_svg` | 2.3.0 | MIT |
| `flutter_webrtc` | 1.6.0 | MIT |
| `go_router` | 14.8.1 | BSD-3-Clause |
| `google_identity_services_web` | 0.3.3+1 | BSD-3-Clause |
| `google_sign_in` | 7.2.0 | BSD-3-Clause |
| `google_sign_in_android` | 7.2.16 | BSD-3-Clause |
| `google_sign_in_ios` | 6.3.0 | BSD-3-Clause |
| `google_sign_in_platform_interface` | 3.1.0 | BSD-3-Clause |
| `google_sign_in_web` | 1.1.3 | BSD-3-Clause |
| `hooks` | 2.0.2 | BSD-3-Clause |
| `http` | 1.6.0 | BSD-3-Clause |
| `http_parser` | 4.1.2 | BSD-3-Clause |
| `intl` | 0.20.2 | BSD-3-Clause |
| `jni` | 1.0.3 | BSD-3-Clause |
| `jni_flutter` | 1.0.2 | BSD-3-Clause |
| `jni_util` | 1.0.0 | BSD-3-Clause |
| `js` | 0.7.2 | BSD-3-Clause |
| `lints` | 4.0.0 | BSD-3-Clause |
| `logger` | 2.7.0 | MIT |
| `logging` | 1.3.0 | BSD-3-Clause |
| `lucide_icons_flutter` | 3.1.15 | MIT |
| `material_color_utilities` | 0.13.0 | Apache-2.0 |
| `meta` | 1.18.0 | BSD-3-Clause |
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
| `adler2` | 2.0.1 | 0BSD OR MIT OR Apache-2.0 |
| `aead` | 0.5.2 | MIT OR Apache-2.0 |
| `aes` | 0.8.4 | MIT OR Apache-2.0 |
| `aes-gcm` | 0.10.3 | Apache-2.0 OR MIT |
| `aho-corasick` | 1.1.5 | Unlicense OR MIT |
| `anstream` | 1.0.0 | MIT OR Apache-2.0 |
| `anstyle` | 1.0.14 | MIT OR Apache-2.0 |
| `anstyle-parse` | 1.0.0 | MIT OR Apache-2.0 |
| `anstyle-query` | 1.1.5 | MIT OR Apache-2.0 |
| `anstyle-wincon` | 3.0.11 | MIT OR Apache-2.0 |
| `anyhow` | 1.0.104 | MIT OR Apache-2.0 |
| `arc-swap` | 1.9.2 | MIT OR Apache-2.0 |
| `asn1-rs` | 0.5.2 | MIT/Apache-2.0 |
| `asn1-rs` | 0.6.2 | MIT OR Apache-2.0 |
| `asn1-rs-derive` | 0.4.0 | MIT/Apache-2.0 |
| `asn1-rs-derive` | 0.5.1 | MIT OR Apache-2.0 |
| `asn1-rs-impl` | 0.1.0 | MIT/Apache-2.0 |
| `asn1-rs-impl` | 0.2.0 | MIT/Apache-2.0 |
| `async-trait` | 0.1.92 | MIT OR Apache-2.0 |
| `atomic-waker` | 1.1.2 | Apache-2.0 OR MIT |
| `autocfg` | 1.5.1 | Apache-2.0 OR MIT |
| `axum` | 0.8.9 | MIT |
| `axum-core` | 0.5.6 | MIT |
| `base16ct` | 0.2.0 | Apache-2.0 OR MIT |
| `base64` | 0.21.7 | MIT OR Apache-2.0 |
| `base64` | 0.22.1 | MIT OR Apache-2.0 |
| `base64ct` | 1.8.3 | Apache-2.0 OR MIT |
| `bincode` | 1.3.3 | MIT |
| `bitflags` | 1.3.2 | MIT/Apache-2.0 |
| `bitflags` | 2.13.1 | MIT OR Apache-2.0 |
| `block-buffer` | 0.10.4 | MIT OR Apache-2.0 |
| `block-padding` | 0.3.3 | MIT OR Apache-2.0 |
| `bumpalo` | 3.20.3 | MIT OR Apache-2.0 |
| `bytemuck` | 1.25.2 | Zlib OR Apache-2.0 OR MIT |
| `byteorder` | 1.5.0 | Unlicense OR MIT |
| `bytes` | 1.12.1 | MIT |
| `cbc` | 0.1.2 | MIT OR Apache-2.0 |
| `cc` | 1.4.3 | MIT OR Apache-2.0 |
| `ccm` | 0.5.0 | Apache-2.0 OR MIT |
| `cfg-if` | 1.0.4 | MIT OR Apache-2.0 |
| `cipher` | 0.4.4 | MIT OR Apache-2.0 |
| `clap` | 4.6.6 | MIT OR Apache-2.0 |
| `clap_builder` | 4.6.6 | MIT OR Apache-2.0 |
| `clap_derive` | 4.6.4 | MIT OR Apache-2.0 |
| `clap_lex` | 1.1.0 | MIT OR Apache-2.0 |
| `colorchoice` | 1.0.5 | MIT OR Apache-2.0 |
| `const-oid` | 0.9.6 | Apache-2.0 OR MIT |
| `core-foundation` | 0.9.4 | MIT OR Apache-2.0 |
| `core-foundation-sys` | 0.8.7 | MIT OR Apache-2.0 |
| `cpufeatures` | 0.2.17 | MIT OR Apache-2.0 |
| `crc` | 3.4.0 | MIT OR Apache-2.0 |
| `crc-catalog` | 2.5.0 | MIT OR Apache-2.0 |
| `crc32fast` | 1.5.0 | MIT OR Apache-2.0 |
| `crossbeam-deque` | 0.8.7 | MIT OR Apache-2.0 |
| `crossbeam-epoch` | 0.9.20 | MIT OR Apache-2.0 |
| `crossbeam-utils` | 0.8.22 | MIT OR Apache-2.0 |
| `crypto-bigint` | 0.5.5 | Apache-2.0 OR MIT |
| `crypto-common` | 0.1.7 | MIT OR Apache-2.0 |
| `ctr` | 0.9.2 | MIT OR Apache-2.0 |
| `curve25519-dalek` | 4.1.3 | BSD-3-Clause |
| `curve25519-dalek-derive` | 0.1.1 | MIT/Apache-2.0 |
| `data-encoding` | 2.11.1 | MIT |
| `der` | 0.7.10 | Apache-2.0 OR MIT |
| `der-parser` | 8.2.0 | MIT/Apache-2.0 |
| `der-parser` | 9.0.0 | MIT/Apache-2.0 |
| `deranged` | 0.5.8 | MIT OR Apache-2.0 |
| `digest` | 0.10.7 | MIT OR Apache-2.0 |
| `displaydoc` | 0.2.7 | MIT OR Apache-2.0 |
| `ecdsa` | 0.16.9 | Apache-2.0 OR MIT |
| `either` | 1.17.0 | MIT OR Apache-2.0 |
| `elliptic-curve` | 0.13.8 | Apache-2.0 OR MIT |
| `errno` | 0.3.14 | MIT OR Apache-2.0 |
| `ff` | 0.13.1 | MIT/Apache-2.0 |
| `fiat-crypto` | 0.2.9 | MIT OR Apache-2.0 OR BSD-1-Clause |
| `find-msvc-tools` | 0.1.11 | MIT OR Apache-2.0 |
| `flate2` | 1.1.9 | MIT OR Apache-2.0 |
| `form_urlencoded` | 1.2.2 | MIT OR Apache-2.0 |
| `futures` | 0.3.34 | MIT OR Apache-2.0 |
| `futures-channel` | 0.3.34 | MIT OR Apache-2.0 |
| `futures-core` | 0.3.34 | MIT OR Apache-2.0 |
| `futures-executor` | 0.3.34 | MIT OR Apache-2.0 |
| `futures-io` | 0.3.34 | MIT OR Apache-2.0 |
| `futures-macro` | 0.3.34 | MIT OR Apache-2.0 |
| `futures-sink` | 0.3.34 | MIT OR Apache-2.0 |
| `futures-task` | 0.3.34 | MIT OR Apache-2.0 |
| `futures-util` | 0.3.34 | MIT OR Apache-2.0 |
| `generic-array` | 0.14.7 | MIT |
| `getrandom` | 0.2.17 | MIT OR Apache-2.0 |
| `getrandom` | 0.4.3 | MIT OR Apache-2.0 |
| `ghash` | 0.5.1 | Apache-2.0 OR MIT |
| `group` | 0.13.0 | MIT/Apache-2.0 |
| `heck` | 0.5.0 | MIT OR Apache-2.0 |
| `hex` | 0.4.3 | MIT OR Apache-2.0 |
| `hkdf` | 0.12.4 | MIT OR Apache-2.0 |
| `hmac` | 0.12.1 | MIT OR Apache-2.0 |
| `http` | 1.5.0 | MIT OR Apache-2.0 |
| `http-body` | 1.1.0 | MIT |
| `http-body-util` | 0.1.5 | MIT |
| `httparse` | 1.10.1 | MIT OR Apache-2.0 |
| `httpdate` | 1.0.3 | MIT OR Apache-2.0 |
| `hyper` | 1.11.1 | MIT |
| `hyper-util` | 0.1.20 | MIT |
| `icu_collections` | 2.3.0 | Unicode-3.0 |
| `icu_locale_core` | 2.3.0 | Unicode-3.0 |
| `icu_normalizer` | 2.3.0 | Unicode-3.0 |
| `icu_normalizer_data` | 2.3.0 | Unicode-3.0 |
| `icu_properties` | 2.3.0 | Unicode-3.0 |
| `icu_properties_data` | 2.3.0 | Unicode-3.0 |
| `icu_provider` | 2.3.0 | Unicode-3.0 |
| `idna` | 1.1.0 | MIT OR Apache-2.0 |
| `idna_adapter` | 1.2.2 | Apache-2.0 OR MIT |
| `inout` | 0.1.4 | MIT OR Apache-2.0 |
| `interceptor` | 0.12.0 | MIT OR Apache-2.0 |
| `ipnet` | 2.12.1 | MIT OR Apache-2.0 |
| `is_terminal_polyfill` | 1.70.2 | MIT OR Apache-2.0 |
| `itoa` | 1.0.18 | MIT OR Apache-2.0 |
| `jobserver` | 0.1.35 | MIT OR Apache-2.0 |
| `js-sys` | 0.3.104 | MIT OR Apache-2.0 |
| `lazy_static` | 1.5.0 | MIT OR Apache-2.0 |
| `libc` | 0.2.189 | MIT OR Apache-2.0 |
| `litemap` | 0.8.3 | Unicode-3.0 |
| `lock_api` | 0.4.14 | MIT OR Apache-2.0 |
| `log` | 0.4.33 | MIT OR Apache-2.0 |
| `matchit` | 0.8.4 | MIT AND BSD-3-Clause |
| `md-5` | 0.10.6 | MIT OR Apache-2.0 |
| `memchr` | 2.8.3 | Unlicense OR MIT |
| `memoffset` | 0.7.1 | MIT |
| `mime` | 0.3.17 | MIT OR Apache-2.0 |
| `minimal-lexical` | 0.2.1 | MIT/Apache-2.0 |
| `miniz_oxide` | 0.8.9 | MIT OR Zlib OR Apache-2.0 |
| `mio` | 1.2.2 | MIT |
| `nasm-rs` | 0.3.2 | MIT OR Apache-2.0 |
| `nix` | 0.26.4 | MIT |
| `nom` | 7.1.3 | MIT |
| `num-bigint` | 0.4.8 | MIT OR Apache-2.0 |
| `num-conv` | 0.2.2 | MIT OR Apache-2.0 |
| `num-integer` | 0.1.47 | MIT OR Apache-2.0 |
| `num-traits` | 0.2.19 | MIT OR Apache-2.0 |
| `oid-registry` | 0.7.1 | MIT OR Apache-2.0 |
| `once_cell` | 1.21.4 | MIT OR Apache-2.0 |
| `once_cell_polyfill` | 1.70.2 | MIT OR Apache-2.0 |
| `opaque-debug` | 0.3.1 | MIT OR Apache-2.0 |
| `openh264` | 0.9.8 | BSD-2-Clause |
| `openh264-sys2` | 0.9.8 | BSD-2-Clause |
| `openssl-probe` | 0.1.6 | MIT/Apache-2.0 |
| `p256` | 0.13.2 | Apache-2.0 OR MIT |
| `p384` | 0.13.1 | Apache-2.0 OR MIT |
| `parking_lot` | 0.12.5 | MIT OR Apache-2.0 |
| `parking_lot_core` | 0.9.12 | MIT OR Apache-2.0 |
| `pem` | 3.0.6 | MIT |
| `pem-rfc7468` | 0.7.0 | Apache-2.0 OR MIT |
| `percent-encoding` | 2.3.2 | MIT OR Apache-2.0 |
| `pin-project-lite` | 0.2.17 | Apache-2.0 OR MIT |
| `pin-utils` | 0.1.0 | MIT OR Apache-2.0 |
| `pkcs8` | 0.10.2 | Apache-2.0 OR MIT |
| `polyval` | 0.6.2 | Apache-2.0 OR MIT |
| `portable-atomic` | 1.15.0 | Apache-2.0 OR MIT |
| `potential_utf` | 0.1.6 | Unicode-3.0 |
| `powerfmt` | 0.2.0 | MIT OR Apache-2.0 |
| `ppv-lite86` | 0.2.21 | MIT OR Apache-2.0 |
| `primeorder` | 0.13.6 | Apache-2.0 OR MIT |
| `proc-macro2` | 1.0.107 | MIT OR Apache-2.0 |
| `quote` | 1.0.47 | MIT OR Apache-2.0 |
| `r-efi` | 6.0.0 | MIT OR Apache-2.0 OR LGPL-2.1-or-later |
| `rand` | 0.8.7 | MIT OR Apache-2.0 |
| `rand_chacha` | 0.3.1 | MIT OR Apache-2.0 |
| `rand_core` | 0.6.4 | MIT OR Apache-2.0 |
| `rayon` | 1.12.0 | MIT OR Apache-2.0 |
| `rayon-core` | 1.13.0 | MIT OR Apache-2.0 |
| `rcgen` | 0.13.2 | MIT OR Apache-2.0 |
| `redox_syscall` | 0.5.18 | MIT |
| `regex` | 1.13.1 | MIT OR Apache-2.0 |
| `regex-automata` | 0.4.18 | MIT OR Apache-2.0 |
| `regex-syntax` | 0.8.11 | MIT OR Apache-2.0 |
| `rfc6979` | 0.4.0 | Apache-2.0 OR MIT |
| `ring` | 0.17.14 | Apache-2.0 AND ISC |
| `rtcp` | 0.11.0 | MIT OR Apache-2.0 |
| `rtp` | 0.11.0 | MIT OR Apache-2.0 |
| `rustc_version` | 0.4.1 | MIT OR Apache-2.0 |
| `rusticata-macros` | 4.1.0 | MIT/Apache-2.0 |
| `rustls` | 0.23.43 | Apache-2.0 OR ISC OR MIT |
| `rustls-native-certs` | 0.7.3 | Apache-2.0 OR ISC OR MIT |
| `rustls-pemfile` | 2.2.0 | Apache-2.0 OR ISC OR MIT |
| `rustls-pki-types` | 1.15.1 | MIT OR Apache-2.0 |
| `rustls-webpki` | 0.103.14 | ISC |
| `rustversion` | 1.0.23 | MIT OR Apache-2.0 |
| `safe_arch` | 1.2.0 | Zlib OR Apache-2.0 OR MIT |
| `same-file` | 1.0.6 | Unlicense/MIT |
| `schannel` | 0.1.29 | MIT |
| `scopeguard` | 1.2.0 | MIT OR Apache-2.0 |
| `sdp` | 0.6.2 | MIT OR Apache-2.0 |
| `sec1` | 0.7.3 | Apache-2.0 OR MIT |
| `security-framework` | 2.11.1 | MIT OR Apache-2.0 |
| `security-framework-sys` | 2.17.0 | MIT OR Apache-2.0 |
| `semver` | 1.0.28 | MIT OR Apache-2.0 |
| `serde` | 1.0.229 | MIT OR Apache-2.0 |
| `serde_core` | 1.0.229 | MIT OR Apache-2.0 |
| `serde_derive` | 1.0.229 | MIT OR Apache-2.0 |
| `serde_json` | 1.0.151 | MIT OR Apache-2.0 |
| `serde_path_to_error` | 0.1.20 | MIT OR Apache-2.0 |
| `sha1` | 0.10.7 | MIT OR Apache-2.0 |
| `sha2` | 0.10.9 | MIT OR Apache-2.0 |
| `shlex` | 2.0.1 | MIT OR Apache-2.0 |
| `signal-hook-registry` | 1.4.8 | MIT OR Apache-2.0 |
| `signature` | 2.2.0 | Apache-2.0 OR MIT |
| `simd-adler32` | 0.3.10 | MIT |
| `slab` | 0.4.12 | MIT |
| `smallvec` | 1.15.2 | MIT OR Apache-2.0 |
| `smol_str` | 0.2.2 | MIT OR Apache-2.0 |
| `socket2` | 0.5.10 | MIT OR Apache-2.0 |
| `socket2` | 0.6.5 | MIT OR Apache-2.0 |
| `spki` | 0.7.3 | Apache-2.0 OR MIT |
| `stable_deref_trait` | 1.2.1 | MIT OR Apache-2.0 |
| `strsim` | 0.11.1 | MIT |
| `stun` | 0.6.0 | MIT OR Apache-2.0 |
| `substring` | 1.4.5 | MIT OR Apache-2.0 |
| `subtle` | 2.6.1 | BSD-3-Clause |
| `syn` | 1.0.109 | MIT OR Apache-2.0 |
| `syn` | 2.0.119 | MIT OR Apache-2.0 |
| `syn` | 3.0.3 | MIT OR Apache-2.0 |
| `sync_wrapper` | 1.0.2 | Apache-2.0 |
| `synstructure` | 0.12.6 | MIT |
| `synstructure` | 0.13.2 | MIT |
| `thiserror` | 1.0.69 | MIT OR Apache-2.0 |
| `thiserror` | 2.0.20 | MIT OR Apache-2.0 |
| `thiserror-impl` | 1.0.69 | MIT OR Apache-2.0 |
| `thiserror-impl` | 2.0.20 | MIT OR Apache-2.0 |
| `time` | 0.3.55 | MIT OR Apache-2.0 |
| `time-core` | 0.1.9 | MIT OR Apache-2.0 |
| `time-macros` | 0.2.32 | MIT OR Apache-2.0 |
| `tinystr` | 0.8.4 | Unicode-3.0 |
| `tokio` | 1.53.1 | MIT |
| `tokio-macros` | 2.7.2 | MIT |
| `tokio-rustls` | 0.26.4 | MIT OR Apache-2.0 |
| `tokio-tungstenite` | 0.23.1 | MIT |
| `tokio-util` | 0.7.19 | MIT |
| `tower` | 0.5.3 | MIT |
| `tower-layer` | 0.3.3 | MIT |
| `tower-service` | 0.3.3 | MIT |
| `tungstenite` | 0.23.0 | MIT OR Apache-2.0 |
| `turn` | 0.8.0 | MIT OR Apache-2.0 |
| `typenum` | 1.20.1 | MIT OR Apache-2.0 |
| `unicode-ident` | 1.0.24 | (MIT OR Apache-2.0) AND Unicode-3.0 |
| `unicode-xid` | 0.2.6 | MIT OR Apache-2.0 |
| `universal-hash` | 0.5.1 | MIT OR Apache-2.0 |
| `untrusted` | 0.9.0 | ISC |
| `ureq` | 2.12.1 | MIT OR Apache-2.0 |
| `url` | 2.5.8 | MIT OR Apache-2.0 |
| `utf-8` | 0.7.6 | MIT OR Apache-2.0 |
| `utf8_iter` | 1.0.4 | Apache-2.0 OR MIT |
| `utf8parse` | 0.2.2 | Apache-2.0 OR MIT |
| `uuid` | 1.24.1 | Apache-2.0 OR MIT |
| `version_check` | 0.9.5 | MIT/Apache-2.0 |
| `waitgroup` | 0.1.2 | Apache-2.0 |
| `walkdir` | 2.5.0 | Unlicense/MIT |
| `wasi` | 0.11.1+wasi-snapshot-preview1 | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT |
| `wasm-bindgen` | 0.2.127 | MIT OR Apache-2.0 |
| `wasm-bindgen-macro` | 0.2.127 | MIT OR Apache-2.0 |
| `wasm-bindgen-macro-support` | 0.2.127 | MIT OR Apache-2.0 |
| `wasm-bindgen-shared` | 0.2.127 | MIT OR Apache-2.0 |
| `webpki-roots` | 0.26.11 | CDLA-Permissive-2.0 |
| `webpki-roots` | 1.0.9 | CDLA-Permissive-2.0 |
| `webrtc` | 0.11.0 | MIT OR Apache-2.0 |
| `webrtc-data` | 0.9.0 | MIT OR Apache-2.0 |
| `webrtc-dtls` | 0.10.0 | MIT OR Apache-2.0 |
| `webrtc-ice` | 0.11.0 | MIT OR Apache-2.0 |
| `webrtc-mdns` | 0.7.0 | MIT OR Apache-2.0 |
| `webrtc-media` | 0.8.0 | MIT OR Apache-2.0 |
| `webrtc-sctp` | 0.10.0 | MIT OR Apache-2.0 |
| `webrtc-srtp` | 0.13.0 | MIT OR Apache-2.0 |
| `webrtc-util` | 0.9.0 | MIT OR Apache-2.0 |
| `wide` | 1.6.1 | Zlib OR Apache-2.0 OR MIT |
| `winapi` | 0.3.9 | MIT/Apache-2.0 |
| `winapi-i686-pc-windows-gnu` | 0.4.0 | MIT/Apache-2.0 |
| `winapi-util` | 0.1.11 | Unlicense OR MIT |
| `winapi-x86_64-pc-windows-gnu` | 0.4.0 | MIT/Apache-2.0 |
| `windows` | 0.61.3 | MIT OR Apache-2.0 |
| `windows` | 0.62.2 | MIT OR Apache-2.0 |
| `windows_aarch64_gnullvm` | 0.52.6 | MIT OR Apache-2.0 |
| `windows_aarch64_msvc` | 0.52.6 | MIT OR Apache-2.0 |
| `windows_i686_gnu` | 0.52.6 | MIT OR Apache-2.0 |
| `windows_i686_gnullvm` | 0.52.6 | MIT OR Apache-2.0 |
| `windows_i686_msvc` | 0.52.6 | MIT OR Apache-2.0 |
| `windows_x86_64_gnu` | 0.52.6 | MIT OR Apache-2.0 |
| `windows_x86_64_gnullvm` | 0.52.6 | MIT OR Apache-2.0 |
| `windows_x86_64_msvc` | 0.52.6 | MIT OR Apache-2.0 |
| `windows-capture` | 2.0.1 | MIT |
| `windows-collections` | 0.2.0 | MIT OR Apache-2.0 |
| `windows-collections` | 0.3.2 | MIT OR Apache-2.0 |
| `windows-core` | 0.61.2 | MIT OR Apache-2.0 |
| `windows-core` | 0.62.2 | MIT OR Apache-2.0 |
| `windows-future` | 0.2.1 | MIT OR Apache-2.0 |
| `windows-future` | 0.3.2 | MIT OR Apache-2.0 |
| `windows-implement` | 0.60.2 | MIT OR Apache-2.0 |
| `windows-interface` | 0.59.3 | MIT OR Apache-2.0 |
| `windows-link` | 0.1.3 | MIT OR Apache-2.0 |
| `windows-link` | 0.2.1 | MIT OR Apache-2.0 |
| `windows-numerics` | 0.2.0 | MIT OR Apache-2.0 |
| `windows-numerics` | 0.3.1 | MIT OR Apache-2.0 |
| `windows-result` | 0.3.4 | MIT OR Apache-2.0 |
| `windows-result` | 0.4.1 | MIT OR Apache-2.0 |
| `windows-strings` | 0.4.2 | MIT OR Apache-2.0 |
| `windows-strings` | 0.5.1 | MIT OR Apache-2.0 |
| `windows-sys` | 0.52.0 | MIT OR Apache-2.0 |
| `windows-sys` | 0.61.2 | MIT OR Apache-2.0 |
| `windows-targets` | 0.52.6 | MIT OR Apache-2.0 |
| `windows-threading` | 0.1.0 | MIT OR Apache-2.0 |
| `windows-threading` | 0.2.1 | MIT OR Apache-2.0 |
| `writeable` | 0.6.4 | Unicode-3.0 |
| `x25519-dalek` | 2.0.1 | BSD-3-Clause |
| `x509-parser` | 0.16.0 | MIT OR Apache-2.0 |
| `yasna` | 0.5.2 | MIT OR Apache-2.0 |
| `yoke` | 0.8.3 | Unicode-3.0 |
| `yoke-derive` | 0.8.2 | Unicode-3.0 |
| `zerocopy` | 0.8.56 | BSD-2-Clause OR Apache-2.0 OR MIT |
| `zerocopy-derive` | 0.8.56 | BSD-2-Clause OR Apache-2.0 OR MIT |
| `zerofrom` | 0.1.8 | Unicode-3.0 |
| `zerofrom-derive` | 0.1.7 | Unicode-3.0 |
| `zeroize` | 1.9.0 | Apache-2.0 OR MIT |
| `zeroize_derive` | 1.5.0 | Apache-2.0 OR MIT |
| `zerotrie` | 0.2.5 | Unicode-3.0 |
| `zerovec` | 0.11.7 | Unicode-3.0 |
| `zerovec-derive` | 0.11.4 | Unicode-3.0 |
| `zmij` | 1.0.23 | MIT |

---

## 4. Paket npm — web, signaling, berita (58)

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
