# Audit Konsistensi UI/UX XyDesk

Tanggal: 2026-08-17
Auditor: XyOne (XySpace Tch)
Basis: commit `510d231`
Metode: pembacaan kode, penghitungan pemakaian token, dan perhitungan rasio
kontras WCAG terhadap warna latar yang sebenarnya dipakai aplikasi.

---

## 0. Ringkasan

Sistem desain lo ada, tertulis, dan bagus. `lib/core/tokens.dart` mendefinisikan
palet dua mode, skala jarak kelipatan 4, skala radius, dan skala durasi dengan
alasan yang ditulis di komentar. Itu sudah di atas mayoritas proyek Flutter.

Masalahnya bukan sistemnya. Masalahnya kepatuhan. Ada 87 warna hardcoded di
luar `tokens.dart`, dan sebagian besar terkonsentrasi di layar-layar yang
dibangun belakangan. Pola yang gua lihat: layar lama disiplin, layar baru
buru-buru.

| Tingkat | Temuan |
|---|---|
| Kritis | `update_page.dart` rusak di dark mode, kontras 2.93:1 |
| Tinggi | Splash memakai palet ungu yang tidak ada di sistem desain |
| Tinggi | Aksesibilitas nyaris tidak ada: 9 `Semantics` untuk 103 widget interaktif |
| Sedang | Skala radius bocor jadi 14 nilai berbeda |
| Sedang | Skala durasi bocor jadi 12 nilai berbeda |
| Rendah | `EdgeInsets` angka mentah tersebar di 8 berkas |

Yang sudah benar dan gua catat di bagian 6 supaya tidak ikut dirombak.

### Pembaruan setelah audit

Temuan kritis layar update sudah ditangani. Seluruh warna mentah di
`update_page.dart` dipindah ke token tema, panel memakai `raised`/`input`, dan
border kartu terang dihapus. `AppPalette` kini punya `successText`,
`warningText`, dan `dangerText` dengan nilai khusus mode terang agar status
teks tetap kontras. Verifikasi visual perangkat tetap menjadi gerbang terakhir.

---

## 1. KRITIS: `update_page.dart` rusak di mode gelap

**Di mana:** `lib/features/notifications/update_page.dart`, 15 warna hardcoded.

**Akar masalahnya.** Berkas ini setengah bermigrasi. Sembilan tempat sudah
memakai `context.c` (baris 208, 210, 258, 272, 292, dan seterusnya), tapi 15
tempat lain memakai warna mentah yang dipilih untuk latar terang:

```dart
color: latest ? const Color(0xFF178B57) : colors.primary,  // hijau gelap
color: Color(0xFF49627C),                                   // biru abu gelap
border: Border.all(color: const Color(0xFFE7EBF0)),         // border terang
color: const Color(0xFFF2F5F8),                             // panel terang
```

Warna-warna ini konstan. Mereka tidak berubah saat tema berubah. Jadi di dark
mode, `#F2F5F8` yang seharusnya panel abu muda menjadi blok putih menyala di
atas latar `#131315`, dan `#E7EBF0` menjadi garis putih tebal.

**Perhitungan kontras terhadap latar gelap `#131315`:**

| Warna | Perannya | vs bgDark | vs bgLight | Status di dark |
|---|---|---|---|---|
| `#49627C` | teks sekunder | **2.93:1** | 6.05:1 | **GAGAL**, di bawah 3:1 |
| `#B23B35` | teks bahaya | 3.15:1 | 5.63:1 | Gagal untuk teks kecil |
| `#A76200` | teks peringatan | 3.88:1 | 4.58:1 | Gagal untuk teks kecil |
| `#178B57` | teks sukses | 4.30:1 | 4.13:1 | Nyaris, gagal 4.5:1 |
| `#F2F5F8` | latar panel | 16.96:1 | 1.05:1 | Blok putih menyala |
| `#E7EBF0` | border kartu | 15.50:1 | 1.15:1 | Garis putih tebal |

`#49627C` pada 2.93:1 gagal bahkan untuk teks besar. WCAG AA menuntut 4.5:1
untuk teks normal dan 3:1 untuk teks besar. Ini bukan preferensi selera; di
layar HP di bawah sinar matahari, teks itu praktis hilang.

**Yang bikin ini lebih menyebalkan:** token semantik yang benar SUDAH ADA di
`tokens.dart` dan angkanya lebih bagus di dua mode sekaligus:

| Token | Nilai | vs bgDark | vs bgLight |
|---|---|---|---|
| `success` | `#4FA97A` | 6.44:1 | 2.76:1 |
| `danger` | `#D9646E` | 5.30:1 | 3.35:1 |
| `warning` | `#C9963F` | 7.00:1 | 2.54:1 |

Jadi solusinya bukan bikin warna baru. Cukup pakai yang sudah lo tulis sendiri.

**Solusi konkret.**

1. Ganti `#178B57` jadi `c.success`, `#B23B35` jadi `c.danger`, `#A76200` jadi
   `c.warning`.
2. Ganti `#49627C` jadi `c.textMid`.
3. Ganti `#F2F5F8` dan `#EAF5F0` jadi `c.raised` atau `c.accentSoft`.
4. Ganti `#E7EBF0` dan `#E8EBEF` jadi `c.overlay`, atau lebih baik lagi hapus
   border-nya. Sistem desain lo namanya "Quiet Surface" dan CI lo sendiri
   melarang `Divider`; border kartu adalah `Divider` yang menyamar.
5. Catatan: token `success` dan `warning` justru lemah di mode terang (2.76:1
   dan 2.54:1). Untuk teks, pakai varian yang lebih gelap di light mode. Cara
   paling bersih: tambahkan `successText`, `warningText`, `dangerText` ke
   `AppPalette` dengan nilai berbeda per mode, sama seperti `accent` sudah
   dibedakan.

**Verifikasi.** Buka layar update di dark mode. Kalau ada kotak putih, belum
kelar.

---

## 2. TINGGI: Splash memakai palet yang tidak ada di sistem desain

**Di mana:** `lib/features/splash/splash_page.dart`, 12 warna hardcoded.

Splash memakai keluarga ungu-biru yang tidak muncul di mana pun dalam
`tokens.dart`:

| Warna splash | Peran |
|---|---|
| `#6842E8` | glow ungu |
| `#7E5CF6` | gradien sapuan |
| `#9A7BFF` | aksen terang |
| `#3B7CFF` | glow biru |
| `#B8A4FF` | ujung gradien teks |
| `#090A10` / `#19152A` / `#0E0F18` | latar gradien |

Bandingkan dengan aksen resmi: `accentDark` = `#5B7FE8`, biru netral tanpa
komponen ungu yang kuat.

**Dampaknya pada persepsi produk.** Splash adalah hal PERTAMA yang dilihat
pengguna. Kalau splash ungu lalu aplikasi biru, ada patahan identitas di detik
pertama. Merek terasa tidak yakin pada dirinya sendiri.

Gua paham argumennya: splash boleh lebih dramatis, itu momen sinematik. Gua
setuju splash boleh punya perlakuan khusus. Tapi perlakuan khusus itu harus
DIDEKLARASIKAN, bukan diselundupkan sebagai angka mentah di tengah widget tree.

**Solusi konkret.** Bikin kelas token terpisah yang jujur soal niatnya:

```dart
/// Palet khusus splash. Sengaja di luar AppPalette karena splash tampil
/// sebelum tema dipilih dan memakai perlakuan sinematik satu kali.
class SplashPalette {
  const SplashPalette._();
  static const void0 = Color(0xFF090A10);
  static const nebula = Color(0xFF19152A);
  static const glowViolet = Color(0xFF6842E8);
  static const glowAzure = Color(0xFF3B7CFF);
  // ...
}
```

Dengan begitu keputusannya terlihat, bisa direview, dan bisa diselaraskan
kalau lo memutuskan mau menarik ungu itu ke seluruh aplikasi.

Pertanyaan desain yang lebih penting, dan ini murni pendapat gua: aksen ungu
itu sebenarnya lebih berkarakter daripada `#5B7FE8`. Biru `#5B7FE8` aman tapi
generik, mirip aksen bawaan banyak aplikasi. Kalau lo mau XyDesk punya wajah
sendiri, pertimbangkan menarik keluarga ungu-biru itu jadi aksen utama, bukan
membuang splash-nya.

---

## 3. TINGGI: Aksesibilitas hampir tidak digarap

**Angkanya:**

| Metrik | Jumlah |
|---|---|
| Widget interaktif (`GestureDetector`, `InkWell`, `onTap`) | 103 |
| `Semantics(` | 9 |
| `semanticLabel` | 1 |
| `tooltip:` | 13 |

Cakupan label untuk elemen interaktif kira-kira 10 persen. TalkBack akan
membacakan sebagian besar kontrol lo sebagai "tombol" tanpa keterangan apa pun.

**Kenapa ini penting khusus untuk XyDesk.** Ini aplikasi remote desktop.
Sebagian penggunanya memakai remote desktop JUSTRU karena keterbatasan fisik:
mengendalikan PC dari perangkat yang lebih mudah dijangkau. Populasi pengguna
lo lebih mungkin memakai screen reader dibanding aplikasi rata-rata.

**Yang sudah benar:** `lib/core/responsive.dart:73` melakukan
`mq.textScaler.clamp(...)`. Lo menghormati pengaturan ukuran font sistem dengan
batas aman supaya layout tidak pecah. Itu keputusan matang yang sering
dilewatkan.

**Solusi konkret, urut dari yang paling murah:**

1. Setiap `IconButton` tanpa teks wajib punya `tooltip`. Ini sekaligus mengisi
   label semantik. Ada 13 `tooltip` untuk jauh lebih banyak icon button.
2. Bungkus kartu perangkat di `home_page` dan `device_detail_page` dengan
   `Semantics(label: 'Perangkat X, status online, ketuk untuk konek')`.
3. Tombol di `session_page` (keyboard virtual, panel kontrol) butuh label
   eksplisit; glyph HUD tidak punya teks sama sekali.
4. Tambahkan gerbang CI seperti yang sudah lo lakukan untuk `Divider`: tolak
   `IconButton(` yang tidak diikuti `tooltip:` dalam 5 baris.

---

## 4. SEDANG: Skala radius dan durasi bocor

### 4.1 Radius

`tokens.dart` mendefinisikan 6 nilai: `sm` 8, `md` 12, `lg` 16, `xl` 20,
`key` 3, `pill` 999. Kenyataan di kode, `BorderRadius.circular` dipanggil
dengan **14 nilai berbeda**:

```
2, 5, 6, 7, 8, 9, 10, 13, 14, 16, 18, 20, 30, 999
```

Nilai seperti 5, 7, 9, 13, 18, dan 30 tidak ada dalam sistem. Mata manusia
memang tidak bisa membedakan radius 13 dari 14 pada satu kartu, tapi bisa
merasakan ketika sepuluh kartu di satu layar punya radius yang tidak konsisten.
Rasanya "kurang rapi" tanpa bisa ditunjuk penyebabnya. Itulah biaya sebenarnya.

Penyumbang terbesar: `update_page.dart` (9), `devlog.dart` (5),
`device_detail_page.dart` (3), `control_editor_page.dart` (3).

**Solusi.** Petakan semua nilai liar ke tangga terdekat: 5/6/7 jadi `R.sm`,
9/10/13/14 jadi `R.md`, 18 jadi `R.lg`, 20 tetap `R.xl`, 30 jadi `R.pill` atau
`R.xl` tergantung maksudnya. Nilai 2 di keyboard virtual kemungkinan besar
memang disengaja; kalau ya, tambahkan sebagai token bernama.

### 4.2 Durasi

`D` mendefinisikan `fast` 120, `tab` 220, `panel` 260, `sheet` 240, `fade` 400.
Di kode ada **12 nilai** milidetik berbeda: 45, 55, 120, 220, 240, 260, 400,
480, 650, 1100, 1400, 2450.

Yang besar (650, 1100, 1400, 2450) hampir pasti koreografi splash, dan itu
wajar untuk animasi bertahap. Tapi mereka layak diberi nama di kelas splash
tadi, supaya timing koreografi bisa disetel di satu tempat, bukan diburu satu
per satu di widget tree.

Yang kecil (45, 55) mencurigakan: itu di bawah tiga frame pada 60 Hz. Animasi
sependek itu praktis tidak terlihat sebagai animasi, hanya sebagai kedipan.
Kalau maksudnya umpan balik sentuh instan, lebih baik nol sekalian.

Catatan: `D.curve` = `Curves.easeOutCubic` dan komentar bilang "semua ≤ 280ms,
tanpa bounce". Aturan itu dilanggar oleh durasi 400 ke atas di kelas yang sama
(`D.fade` = 400). Perbarui komentarnya supaya dokumen tidak berbohong.

---

## 5. RENDAH: `EdgeInsets` angka mentah

Delapan berkas memakai `EdgeInsets` dengan angka literal alih-alih `Gap.*`.
Terbanyak: `session_panels.dart` (13), `devlog.dart` (13),
`update_page.dart` (8).

Ini paling rendah prioritasnya karena dampak visualnya paling kecil dan
`devlog.dart` adalah alat internal developer yang wajar keluar dari sistem.
Tapi `session_panels.dart` adalah layar yang dilihat pengguna paling lama saat
sesi berjalan, jadi berkas itu layak dirapikan.

---

## 6. Yang Sudah Benar, Jangan Dirombak

- **Nol `withOpacity`.** Semua 94 pemanggilan memakai `withValues`. Ini patuh
  penuh pada standar 2026 di ATURAN.md pasal 3. Rapi.
- **`ThemeExtension` dengan `lerp` yang benar.** `AppPalette.lerp`
  mengimplementasikan interpolasi untuk semua field, jadi transisi tema
  beranimasi mulus alih-alih patah. Banyak yang malas di sini dan langsung
  `return this`.
- **`textScaler.clamp`** di `responsive.dart`. Menghormati aksesibilitas sistem
  sambil melindungi layout.
- **Lokalisasi serius.** 890 entri di `strings.dart`. Bukan proyek yang
  menaruh string Indonesia langsung di widget.
- **Alasan desain ditulis di komentar token.** "Radius lebih kecil dari versi
  neon agar terasa presisi", "keyboard virtual sengaja hampir kotak (3dp)".
  Ini yang membedakan sistem desain dari daftar konstanta.
- **Konsistensi ikon.** Komitmen pada Lucide dengan alasan eksplisit (Material
  Icons terlalu tebal) dan dipatuhi di seluruh kode.
- **Aturan desain ditegakkan CI.** Gerbang anti-`Divider` dan
  anti-`scrolledUnderElevation` itu pendekatan yang benar. Perluas pola ini ke
  temuan di dokumen ini.

---

## 7. Urutan Kerja yang Gua Sarankan

| Prioritas | Pekerjaan | Perkiraan |
|---|---|---|
| 1 | Migrasi 15 warna hardcode `update_page.dart` ke token | 1 jam |
| 2 | Tambah `successText`/`warningText`/`dangerText` per mode | 1 jam |
| 3 | Deklarasikan `SplashPalette`, putuskan arah aksen merek | 2 jam |
| 4 | `tooltip` untuk semua `IconButton`, `Semantics` untuk kartu perangkat | 3 jam |
| 5 | Normalisasi 14 nilai radius ke tangga token | 2 jam |
| 6 | Gerbang CI: tolak `Color(0x` baru di `lib/features/` | 1 jam |
| 7 | Rapikan `EdgeInsets` di `session_panels.dart` | 1 jam |

Nomor 6 yang mencegah dokumen ini perlu ditulis ulang enam bulan lagi.

---

## 8. Bukti Verifikasi

| Yang diperiksa | Metode | Hasil |
|---|---|---|
| Warna hardcode | `git grep "Color(0x"` di luar `tokens.dart` | 87 |
| `withOpacity` | `git grep` | 0 |
| `withValues` | `git grep` | 94 |
| Rasio kontras | Perhitungan luminansi relatif WCAG 2.1 | Tabel bagian 1 |
| Cakupan a11y | Hitung `Semantics` vs widget interaktif | 9 dari 103 |
| Sebaran radius | `git grep` nilai `BorderRadius.circular` | 14 nilai unik |
| Sebaran durasi | `git grep` nilai `Duration(milliseconds:` | 12 nilai unik |

Yang TIDAK diverifikasi: tampilan visual sebenarnya di perangkat. Gua tidak
menjalankan aplikasi. Semua temuan di atas berbasis pembacaan kode dan
perhitungan angka, dan setiap klaim menyebut berkas serta baris supaya lo bisa
buktikan sendiri.

---

Disusun oleh XyOne untuk Kall, XySpace Tch.
