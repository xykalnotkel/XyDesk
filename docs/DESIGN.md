# DESIGN.md — Sumber kebenaran token desain XyDesk

> **Berkas ini dirujuk `lib/core/tokens.dart:6` sejak awal, tapi tidak pernah ada.**
> Akibatnya tiga platform menyimpan token sendiri-sendiri di tiga berkas berbeda
> tanpa rujukan bersama, dan sudah menyimpang. Audit 6 Sep 2026
> (`docs/AUDIT-2026-09-06.md`) menemukan desktop masih memakai aksen pra-rebrand.
>
> Mulai sekarang: **ubah nilai di sini dulu**, baru salin ke tiga tempat di bawah.
> Kalau ada selisih, berkas ini yang menang — kecuali selisihnya tercatat di
> bagian "Penyimpangan yang disengaja".

## Hukum visual

1. **Quiet Surface** — clean, modern, tanpa garis pemisah. Pemisah dibangun dari
   beda warna permukaan (`bg` → `raised` → `overlay` → `input`), bukan dari border.
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
| Web | `web/src/style.css` | variabel CSS `:root` |
| Desktop shell | `desktop/app/globals.css` | variabel CSS `:root` |

Logo punya pola yang lebih baik dan layak ditiru untuk token: satu sumber
(`design/logo-asli.png`) dan semua ukuran lahir dari generator (`tool/gen_logo.py`).
Selama token masih disalin manual ke tiga tempat, uji konsistensi adalah jaringnya —
lihat `web/test/csp.test.js` untuk contoh pola uji yang membandingkan dua berkas.

## Token warna — Paper (terang)

Ini nilai kanonik. Nama kolom web/desktop adalah nama variabel CSS-nya.

| Makna | Nilai | Flutter | Web | Desktop |
|---|---|---|---|---|
| Latar halaman | `#FAFAF9` | `bgLight` | `--bg` ⚠️ | `--bg` |
| Permukaan naik (kartu) | `#FFFFFF` | `raisedLight` | `--raised` | `--raised` |
| Permukaan overlay | `#FFFFFF` | `overlayLight` | `--overlay` ⚠️ | `--overlay` |
| Latar field input | `#F2F2F0` | `inputLight` | `--input` ⚠️ | `--input` |
| Teks utama | `#18181B` | `textHiLight` | `--text-hi`, `--ink` | `--text-hi`, `--ink` |
| Teks sekunder | `#52525B` | `textMidLight` | `--text-mid` | `--text-mid` |
| Teks redup | `#9A9AA2` | `textLowLight` | `--text-low` | `--text-low` |
| **Aksen** | `#7C3AED` | `accentLight` | `--accent` | `--accent` |
| Aksen dalam (teks di latar terang) | `#5B21B6` | `accentDeep` | `--accent-deep` | `--accent-deep` |
| Aksen sekunder (lavender) | `#A78BFA` | `accentLavender` | `--accent-2` | `--accent-2` |
| Isi aksen halus | `accent` @ 12% | `accentSoft` | `--accent-soft` ⚠️ | `--accent-soft` |

⚠️ = lihat "Penyimpangan yang disengaja" di bawah.

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
| `xxl` | 24 |
| `h32` / `h40` / `h56` | 32 / 40 / 56 |
| `screen` (padding horizontal layar) | 20 |

## Radius

| Nama | Flutter (`R`) | Web | Desktop |
|---|---|---|---|
| kecil | 8 | `--radius-sm: 10px` | `--radius-sm: 10px` |
| sedang | 12 | `--radius: 14px` | `--radius: 14px` |
| besar | 16 | — | — |
| ekstra | 20 | `--radius-lg: 20px` | — |
| tombol keyboard virtual | 3 (sengaja hampir kotak) | — | — |
| pil | 999 | — | — |

**BELUM diputuskan.** Skala Flutter 8/12/16/20 dan skala CSS 10/14/20 tidak sama.
Menyamakannya mengubah bentuk setiap kartu dan tombol di web maupun desktop, jadi
ini keputusan yang harus dilihat mata operator, bukan disamakan diam-diam oleh agent.
Diangkat sebagai temuan terbuka di `HANDOFF.md`.

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

## Penyimpangan yang disengaja

Dicatat di sini supaya tidak "dirapikan" oleh orang berikutnya yang mengira ini
kelupaan. Kalau suatu hari mau disamakan, hapus barisnya dari bagian ini dulu.

### 1. Permukaan web lebih putih dan overlay-nya bernada lavender

`web/src/style.css` memakai `--bg: #ffffff`, `--overlay: #f5f3ff`,
`--input: #ffffff`, sementara aplikasi memakai `#FAFAF9` / `#FFFFFF` / `#F2F2F0`.
Berkas itu sendiri mencatat alasannya: *"Ungu inti diselaraskan dengan logo X baru
(violet kaca #7C3AED–#A78BFA) pada design pass 2026-09."* Jadi ini keputusan desain,
bukan drift — dan karena itu TIDAK disamakan pada audit 6 Sep 2026.

Konsekuensinya harus dikatakan jujur: **web dan aplikasi tidak terlihat persis sama.**
Kalau itu tidak lagi diinginkan, samakan ke nilai Paper di tabel atas dan hapus
catatan ini.

### 2. Web dan desktop masih memakai garis pemisah

Hukum #1 melarang garis pemisah, tapi web punya `--line: #e9e5f2` +
`--line-strong: #d5cde8` (dipakai ±282 kali) dan desktop punya `--line: #e7e7e4`
(±51 kali). Warna garisnya pun berbeda satu sama lain.

Menghapusnya adalah perombakan visual, bukan perbaikan token — 300+ pemakaian harus
ditinjau satu per satu supaya hierarki tidak hilang bersama garisnya. Diangkat
sebagai pekerjaan terbuka, bukan dikerjakan separuh.

### 3. Navigasi tidak sama jumlahnya

| Platform | Item |
|---|---|
| Aplikasi (HP) | Beranda · Hubungkan · Berita · **Akun** |
| Desktop | Beranda · Hubungkan · Berita · **Profil · Pengaturan** |
| Web | Beranda · Berita (Unduh dan Hubungkan sebagai halaman, bukan nav) |

Desktop memecah Profil dan Pengaturan; aplikasi menggabungnya jadi Akun. Ini
keputusan struktur informasi, bukan token — perlu diputuskan operator.

## Yang sudah paritas (contoh baik)

**Kartu artikel Berita** disamakan di tiga platform pada 6 Sep 2026 (commit
`8da171e`): chip kategori bundar di atas sampul, rasio sampul 16:9. Sebelumnya
kategori ditulis tiga cara berbeda — di web menempel di atas sampul, di desktop
duduk di badan kartu, di aplikasi berupa teks kapital di atas judul.

Itu bukti paritas bisa dicapai: satu keputusan, diterapkan ke tiga tempat, dalam satu
commit. Token desain butuh perlakuan yang sama.
