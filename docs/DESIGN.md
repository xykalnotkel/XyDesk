# DESIGN.md — Sumber kebenaran token desain XyDesk

> Riwayat singkat: berkas ini dirujuk `lib/core/tokens.dart:6` sejak awal,
> tapi tidak pernah ada — tiga platform menyimpan token sendiri-sendiri dan
> menyimpang. Dibuat 6 Sep 2026 dari audit. **9 Sep 2026 (unifikasi UI/UX):
> operator memutuskan WEB sebagai acuan** — aplikasi + desktop mengikuti
> nilai web, radius disatukan ke 8/12/16/20, garis pemisah dihapus di
> desktop + web, installer di-brand. Berkas ini diperbarui mengikuti.
>
> Mulai sekarang: **ubah nilai di sini dulu**, baru salin ke tiga tempat di
> bawah. Kalau ada selisih, berkas ini yang menang — kecuali selisihnya
> tercatat di bagian "Penyimpangan yang disengaja".

## Hukum visual

1. **Quiet Surface** — clean, modern, tanpa garis pemisah. Pemisah dibangun dari
   beda warna permukaan (`bg` → `raised` → `overlay`/`input`), bayangan halus,
   dan jarak — bukan dari border. Satu-satunya garis yang boleh ada adalah
   outline SEMANTIK (lihat "Garis yang disengaja" di bawah), bukan pemisah.
2. **Satu tema terang ("Paper")** di aplikasi Android. Mode gelap dihapus supaya
   hanya ada satu set kontras yang teruji. Nilai gelap ("Graphite") tetap
   dipertahankan di `tokens.dart` sebagai pasangan yang konsisten, bukan sebagai
   tema yang bisa dipilih pengguna.
3. **Aksen = ungu brand** hasil rebrand Sep 2026 ("logo X ungu kaca"). Satu sumber
   untuk semua platform.
4. **Inter di-bundle**, bukan diunduh runtime — tampilan pasti sama di semua
   perangkat, termasuk tanpa internet.
5. **Durasi interaksi utama ≤ 280 ms**, tanpa bounce.

## Tiga tempat yang harus selalu cocok

| Platform | Berkas | Bentuk |
|---|---|---|
| Aplikasi (Android) | `lib/core/tokens.dart` | kelas Dart `AppColors` / `AppPalette` |
| Web (ACUAN) | `web/src/style.css` | variabel CSS `:root` |
| Desktop shell | `desktop/app/globals.css` | variabel CSS `:root` |

Logo punya pola yang lebih baik dan layak ditiru untuk token: satu sumber
(`design/logo-asli.png`) dan semua ukuran lahir dari generator (`tool/gen_logo.py`).
Selama token masih disalin manual ke tiga tempat, uji konsistensi adalah jaringnya —
lihat `web/test/csp.test.js` untuk contoh pola uji yang membandingkan dua berkas.

## Token warna — Paper (terang)

Ini nilai kanonik = nilai web. Nama kolom web/desktop adalah nama variabel CSS-nya.

| Makna | Nilai | Flutter | Web | Desktop |
|---|---|---|---|---|
| Latar halaman | `#FFFFFF` | `bgLight` | `--bg` | `--bg` |
| Permukaan naik (kartu) | `#FFFFFF` | `raisedLight` | `--raised` | `--raised` |
| Permukaan overlay | `#F5F3FF` | `overlayLight` | `--overlay` | `--overlay` |
| Latar field input | `#F5F3FF` | `inputLight` | `--input` | `--input` |
| Teks utama | `#18181B` | `textHiLight` | `--text-hi`, `--ink` | `--text-hi`, `--ink` |
| Teks sekunder | `#52525B` | `textMidLight` | `--text-mid`, `--ink-soft` | `--text-mid` |
| Teks redup | `#9A9AA2` | `textLowLight` | `--text-low` | `--text-low` |
| **Aksen** | `#7C3AED` | `accentLight` | `--accent` | `--accent` |
| Aksen dalam (teks di latar terang) | `#5B21B6` | `accentDeep` | `--accent-deep` | `--accent-deep` |
| Aksen sekunder (lavender) | `#A78BFA` | `accentLavender` | `--accent-2` | `--accent-2` |
| Isi aksen halus | `accent` @ 10% | `accentSoft` | `--accent-soft` | `--accent-soft` |

Catatan `input == overlay`: BUKAN duplikat tertinggal. Hukum tanpa-garis butuh
beda nada antar permukaan; input putih lama (`#ffffff`) dulu cuma terbaca karena
ada border. Setelah border dihapus (Sep 2026), input memakai nada lavender-putih.

## Token warna — status

Warna status punya **dua varian** dan ini sumber kebingungan yang sudah terjadi.
`tokens.dart` menjelaskannya: warna dasar dirancang untuk Graphite (gelap); dipakai
sebagai teks di Paper kontrasnya terlalu rendah. Jadi ada varian teks khusus latar
terang. **Web dan desktop hanya punya satu varian, dan harus memakai varian terang.**

| Makna | Dasar (Graphite) | Teks di Paper | Web & Desktop |
|---|---|---|---|
| Sukses | `#4FA97A` | `#167347` | `--success: #167347` |
| Peringatan | `#C9963F` | `#855400` | `--warning: #855400` |
| Bahaya | `#D9646E` | `#A52A36` | `--danger: #a52a36` |

Sebelum 6 Sep 2026 web memakai `#15803d` / `#b45309` / `#b91c1c` dan desktop memakai
`#167347` / `#b45309` / `#b91c1c` — dua-duanya bukan warna dasar maupun varian
terang. Murni hanyut, sudah disamakan.

## Jarak

Skala kelipatan 4 (`Gap` di `tokens.dart`). Tidak punya padanan variabel CSS di
web/desktop — nilai jarak di sana masih ditulis per aturan.

| Nama | Nilai |
|---|---|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 20 |
| `h32` / `h40` / `h56` | 32 / 40 / 56 |
| `screen` (padding horizontal layar) | 20 |

## Radius

**DIPUTUSKAN 9 Sep 2026 (operator): satu skala 8/12/16/20 + pil di semua platform.**
Web pindah dari 10/14/20; kartu disatukan ke peran 16.

| Nama | Flutter (`R`) | Web | Desktop |
|---|---|---|---|
| kecil | 8 | `--radius-sm: 8px` | `--r-sm: 8px` |
| sedang | 12 | `--radius-md: 12px` | `--r-md: 12px` |
| besar (kartu, dialog) | 16 | `--radius: 16px` | `--r-lg: 16px` |
| ekstra | 20 | `--radius-lg: 20px` | `--r-xl: 20px` (didefinisikan, belum dipakai) |
| tombol keyboard virtual | 3 (sengaja hampir kotak) | `3px` + komentar `R.key` | — (tidak ada keyboard virtual) |
| pil | 999 | `999px` | `999px` / `--r-pill` |

Peran bentuk per komponen (disatukan Sep 2026): kartu/kartu berita/dialog/popover/
panel modal = 16; input field + tombol CSS + tab strip + segmen = 12; chip kecil,
badge, tab aktif = 8; chip filter/kategori = pil; tombol keyboard virtual = 3.

BELUM disatukan (butuh mata operator, jangan diam-diam): **tombol aplikasi = pil
penuh** (`StadiumBorder`) sementara tombol web/desktop = 12; **input aplikasi =
pil penuh** sementara input web/desktop = 12. Skalanya sama, perannya beda —
menyamakannya mengubah bahasa bentuk salah satu sisi.

## Durasi

| Nama | Nilai | Pakai untuk |
|---|---|---|
| `fast` | 120 ms | umpan balik sentuh |
| `tab` | 220 ms | pindah tab |
| `panel` | 260 ms | panel sisi |
| `sheet` | 240 ms | sheet bawah |
| `fade` | 400 ms | transisi opacity (bukan umpan balik sentuh) |
| `idleHide` | 3000 ms | overlay sesi memudar setelah diam |
| kurva | `easeOutCubic` | semua di atas |

Web memakai `--speed: 0.16s` — dekat dengan `fast`/`tab`, tidak identik. Desktop
tidak punya token durasi.

## Garis yang disengaja

Hukum #1 melarang garis PEMISAH. Yang di bawah ini outline SEMANTIK — boleh ada,
dan daftarnya tertutup (tambah jenis baru = ubah bagian ini dulu):

1. **Varian tombol outlined** — cermin `OutlinedButton` aplikasi
   (`side: textLow @30%`): web `.btn.ghost` + `.ghost-btn`, desktop
   `button.ghost` memakai `rgba(154,154,162,0.30)`. Hover = isi halus + teks
   dalam, border transparan.
2. **Indikator fokus** — aplikasi: outline aksen 1.5px saat fokus; web: `--ring`
   (+ `--ring-danger` untuk invalid); desktop: ring `0 0 0 3px accent-soft`.
   Mekanisme beda, makna sama.
3. **Tuts di atas video/game** — `vkb-key` (web), `gp-key` border-only (web),
   `hud-icon-btn` (web): tanpa tepi tidak terbaca sebagai tombol di atas
   gambar bergerak. Disengaja + dikomentari di kode.
4. **Viewfinder pemindai QR** — `.qr-frame` (web): bingkai sudut = fungsi alat.
5. **Penanda aksen merek** — mistar 5px di `h2` section web, centang 3px di `h3`
   kartu desktop: dekorasi aksen, bukan pemisah.
6. **Chrome peramban** — `scrollbar` web (`#d5cde8` literal, bukan token),
   trik `background-clip` desktop: fungsional, bukan bahasa desain.

Pengganti pemisah yang dihapus (pola baku): kartu = bayangan; baris daftar =
ubin overlay + gap; strip/tab = jalur input + tab putih; tabel = strip zebra
(web lisensi) atau ubin; chip = isi overlay/lembut; panel modal = bayangan.

## Penyimpangan yang disengaja

Dicatat di sini supaya tidak "dirapikan" oleh orang berikutnya yang mengira ini
kelupaan. Kalau suatu hari mau disamakan, hapus barisnya dari bagian ini dulu.

### 1. Navigasi tidak sama jumlahnya

| Platform | Item |
|---|---|
| Aplikasi (HP) | Beranda · Hubungkan · Berita · **Akun** |
| Desktop | Beranda · Hubungkan · Berita · **Profil · Pengaturan** |
| Web | Beranda · Berita (Unduh dan Hubungkan sebagai halaman, bukan nav) |

Desktop memecah Profil dan Pengaturan; aplikasi menggabungnya jadi Akun. Ini
keputusan struktur informasi, bukan token — perlu diputuskan operator.

### 2. Aksen Void (gelap) di desktop + web

Sidebar + hero login desktop dan footer/seksi gelap web memakai Void `#0D0716`
dengan radial ungu. Aplikasi tidak punya permukaan gelap sama sekali (hukum #2).
Ini bahasa bersama web + desktop, bukan drift — menghapusnya = mendesain ulang
kedua sisi, bukan menyamakan token.

## Yang sudah paritas (contoh baik)

1. **Gaya Tombol Utama (Aksen 3D-Glossy)** disamakan di semua platform pada 9 Sep 2026:
   - **Gradien**: `linear-gradient(160deg, #8b5cf6 0%, #7c3aed 45%, #5b21b6 100%)`
   - **Top Bevel Highlight**: garis semi-transparan `inset 0 1px 0 rgba(255, 255, 255, 0.22)`
   - **Bayangan Halus**: `0 3px 8px rgba(38, 18, 92, 0.16)`
   - **Flutter**: Tersedia terpusat di `PrimaryButton` (`lib/widgets/seamless.dart`) dan `filledButtonTheme`.
   - **Web & Desktop**: Menggunakan class `.btn.primary` dan `button.primary`.

2. **Ikon Navigasi Vektor (Lucide Icons)**:
   - Seluruh raster bitmap navigasi lama (`assets/img/nav/*.png`) dibersihkan dari shell aplikasi.
   - Semua platform kini memakai ikon vektor murni Lucide (`house`, `cable`, `newspaper`, `user`, `sparkles`) dengan pil indikator aktif beraksen `c.accentSoft`.

3. **Kartu artikel Berita** disamakan di tiga platform pada 6 Sep 2026 (commit
   `8da171e`): chip kategori bundar di atas sampul, rasio sampul 16:9. Sebelumnya
   kategori ditulis tiga cara berbeda — di web menempel di atas sampul, di desktop
   duduk di badan kartu, di aplikasi berupa teks kapital di atas judul.

4. **Unifikasi UI/UX Sep 2026** (operator: web = acuan): token Paper mengikuti web
   (`bg #ffffff`, `overlay`/`input #f5f3ff`, `accent-soft` 10%); radius satu skala
   8/12/16/20 + pil + tuts-3 di semua platform; ±185 garis pemisah dihapus di
   desktop + web (kartu→bayangan, baris→ubin overlay, strip→jalur input, tabel→
   zebra/ubin, chip→isi lembut); chip filter/kategori disatukan (isi overlay,
   aktif isi-lembut + teks dalam); switch desktop = trek `textLow @45%` tanpa
   outline + flat aksen saat on (cermin aplikasi); installer Windows di-brand
   (`wizard-image.bmp` + `wizard-small.bmp` dari logo asli). Sisa terbuka:
   tombol/input pil aplikasi vs 12px CSS, jumlah item navigasi.

Itu bukti paritas bisa dicapai: satu keputusan, diterapkan ke tiga tempat, dalam satu
commit. Token desain butuh perlakuan yang sama.
