# XyDesk

Aplikasi remote desktop low-latency untuk **gaming dan kerja**.
Gaya visual **Quiet Surface** — clean, modern, tanpa satu pun garis pemisah.

[![Build](https://github.com/xykalnotkel/XyDesk/actions/workflows/build.yml/badge.svg)](https://github.com/xykalnotkel/XyDesk/actions/workflows/build.yml)

---

## Status

Ini adalah **kerangka UI yang bisa dijalankan** — seluruh antarmuka sudah hidup
dan bisa dipakai, tetapi lapisan WebRTC belum tersambung. Layar sesi memakai
placeholder sebagai ganti `RTCVideoView`.

| Bagian | Status |
|---|---|
| Design system & tema | Selesai |
| Home, Connect, Akun, Tentang | Selesai |
| Layar sesi + loading bertahap | Selesai |
| Panel gaming dua sisi (7 kategori) | Selesai |
| Keyboard virtual (modifier sticky) | Selesai |
| Glyph HUD (mouse, gulir, arah, switch) | Selesai |
| CI/CD GitHub Actions | Selesai |
| WebRTC, signaling, host app | Belum |

---

## Menjalankan

```bash
flutter pub get
flutter run
```

Butuh Flutter **3.44+** / Dart 3.5+.

```bash
flutter test              # 27 test
flutter analyze           # harus bersih
dart format lib test      # sebelum push
```

---

## Struktur

```
lib/
├── main.dart                     # edge-to-edge + ProviderScope
├── app.dart                      # shell + bottom-nav seamless
├── core/
│   ├── tokens.dart               # warna, jarak, radius, durasi
│   └── theme.dart                # ThemeData — semua garis dimatikan di sini
├── widgets/
│   ├── seamless.dart             # SeamlessScaffold, SurfaceCard, FadeEdge
│   └── hud_glyphs.dart           # 20 glyph CustomPainter
└── features/
    ├── home/                     # daftar perangkat
    ├── connect/                  # ID + kata sandi + blok dukungan
    ├── account/                  # akun & halaman Tentang
    └── session/
        ├── session_page.dart     # sesi, loading, overlay auto-hide
        ├── session_panels.dart   # bilah kiri + panel kategori kanan
        └── virtual_keyboard.dart # keyboard penuh, radius 3dp
```

---

## Keputusan Desain yang Perlu Diketahui

Ini bukan preferensi acak — masing-masing ada alasannya.

**Nol garis pemisah.** Semua sumber garis Material dimatikan di `theme.dart`:
`surfaceTintColor` transparan, `scrolledUnderElevation: 0`, dan `DividerTheme`
transparan. Pemisahan visual memakai jarak minimal 24dp dan gradasi `FadeEdge`.
CI memverifikasi ini otomatis — kalau ada yang menambahkan `Divider()`, build
gagal.

**Item nav aktif berwarna putih, bukan aksen.** Kalau ikon aktif ikut biru,
satu layar punya dua titik perhatian. Cukup pil `accentSoft` di belakangnya.

**Tombol keyboard tidak berubah warna saat ditekan** — hanya sedikit lebih
terang. Kilatan biru berulang melelahkan saat mengetik cepat. Hanya modifier
sticky yang memakai aksen, karena statusnya memang perlu terlihat.

**Radius tombol keyboard 3dp.** Radius besar membuatnya terlihat seperti
mainan; 3dp terasa presisi seperti keyboard mekanis.

**HUD border-only.** Isi sepenuhnya transparan, hanya garis 1,5px putih 34%.
Piksel game di dalam tombol tetap terlihat. Saat ditekan hanya diisi 14%.

**Glyph HUD memakai CustomPainter, bukan teks.** Karakter seperti `↑↓` dan `⇄`
dirender berbeda di tiap font dan OS. Dengan painter, ketebalan garis bisa
diubah 1,5px → 3px untuk mode kontras tinggi tanpa mengubah bentuk.

**Rotasi landscape terjadi sebelum layar loading muncul.** Kalau dibalik, ada
kedipan orientasi yang membuat aplikasi terasa murah.

**Loading connect menampilkan waktu tiap tahap.** Kegagalan koneksi remote
desktop punya belasan penyebab. Dengan waktu per tahap, user dan tim dukungan
langsung tahu macetnya di penemuan host, autentikasi, atau NAT.

---

## Build Otomatis

Push ke GitHub, dan Actions membangun **APK universal** dan **Windows portable**.
Tidak perlu Android Studio atau Visual Studio di komputer kamu.

| Target | Artefak | Keterangan |
|---|---|---|
| Android | `XyDesk.apk` | Universal — satu berkas untuk semua HP Android 8.0+ |
| Windows | `XyDesk-Windows-x64.zip` | Portable — ekstrak lalu jalankan `xydesk.exe` |

Unduh dari tab **Actions** → pilih run → bagian **Artifacts**.

```bash
git tag v1.0.0 && git push origin v1.0.0   # buat rilis
```

Detail lengkap, termasuk cara menandatangani build dan perkiraan biaya runner:
[`docs/CI.md`](docs/CI.md).

---

## Langkah Berikutnya

1. Tambahkan `flutter_webrtc`, sambungkan `RTCVideoView` ke `SessionPage`.
2. Bangun signaling server (Go + WebSocket) dan host app (Rust + Tauri).
3. Terapkan SRP-6a untuk autentikasi tanpa mengirim kata sandi.
4. Editor control mapping dengan penyimpanan profil JSON.

> **Catatan jujur:** bagian tersulit bukan UI, melainkan **latency dan NAT
> traversal**. Buat PoC `capture → encode → WebRTC → decode` lebih dulu dan
> ukur angkanya. Kalau tidak tembus di bawah 40 ms pada jaringan target,
> posisi "cocok untuk game" harus dievaluasi ulang sebelum UI dipoles.

Dokumen desain, keamanan, dan izin ada di folder `remote-desktop-docs/`.
