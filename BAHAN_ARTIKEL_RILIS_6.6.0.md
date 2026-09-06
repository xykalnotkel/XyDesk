# Bahan Artikel Rilis 6.6.0 — SIAP TERBIT

**Tanggal:** 6 Sep 2026
**Peran:** Operator (CI/Release)
**Versi:** 6.6.0 (build 33) — sudah terbit sebagai tag `v6.6.0`
**Gaya:** mengikuti `docs/NEWS_STYLE.md` §4 (empat bagian, urut)

> ⚠️ **Status: naskah siap, TAPI belum terbit.** Dua hal menghalangi dan
> keduanya di luar jangkauan agent:
> 1. **`ADMIN_TOKEN` worker berita tidak tersedia.** Ia secret Cloudflare
>    Worker (bukan GitHub Secret), dan tidak ada di berkas kredensial. Jalur
>    kedua (Google ID token) butuh login founder — yang ada hanya Client ID +
>    Client Secret, tanpa refresh token.
> 2. **Sampul `changelog-660.jpg` belum ada.** Wajib 1424×752 di
>    `web/public/news/covers/`. Aset brand punya jalur kanonik
>    (`design/logo-asli.png` → `tool/gen_logo.py`) dan agent pernah melanggar
>    aturan repo dengan merender manual, jadi pembuatan sampul diserahkan ke
>    operator.
>
> Screenshot asli untuk perubahan visual **tidak disertakan** — tidak ada
> perangkat untuk mengambilnya. Perlu dicatat jujur: artikel `rilis-654` juga
> terbit tanpa satu pun gambar di badan berita, jadi ini bukan penyimpangan
> baru, tapi `docs/NEWS_STYLE.md` §3 tetap menuntutnya.

---

## Perintah terbit (jalur benar — pakai endpoint admin)

```bash
curl -X POST "https://news.xydesk.my.id/api/admin/publish" \
  -H "Content-Type: application/json" \
  -H "x-admin-token: <ADMIN_TOKEN>" \
  -d @- <<'JSON'
{
  "title": "Aplikasi Android yang macet di logo akhirnya bisa dibuka",
  "excerpt": "Aplikasi Android yang berhenti di logo kini bisa dibuka lagi. Koneksi jarak jauh dari browser juga tidak lagi diam saat gagal.",
  "cover": "https://app.xydesk.my.id/news/covers/changelog-660.jpg",
  "category": "rilis",
  "author": "Haekal Saputra",
  "slug": "changelog-v6-6-0",
  "content": "<ISI DI BAWAH, dengan \\n sebagai pemisah paragraf>"
}
JSON
```

**Field `slug` WAJIB diisi.** Worker mengacak slug jadi `p-<hash>` bila kosong,
dan hanya pola `changelog-vX-Y-Z` yang boleh dipilih sendiri. Kalau terlewat,
tautan versi di footer web dan layar "Tentang" jatuh ke 404 — itu sudah terjadi
pada rilis 6.4.0, 6.1, dan 6.0, dan terulang di 6.5.2–6.5.4 yang artikelnya
terbit sebagai `rilis-65x`.

---

## Judul

```
Aplikasi Android yang macet di logo akhirnya bisa dibuka
```

55 karakter. Manfaatnya di depan, bukan nomornya — sesuai §4.

## Ringkasan (excerpt)

```
Aplikasi Android yang berhenti di logo kini bisa dibuka lagi. Koneksi jarak jauh dari browser juga tidak lagi diam saat gagal.
```

126 karakter (batas 150).

## Badan berita

Kalau kamu memakai XyDesk di HP Android dan aplikasinya berhenti di logo — tidak
crash, tidak ada pesan galat, tidak ada tombol yang bisa ditekan — rilis ini
untuk kamu. Kami sudah menemukan penyebabnya, dan kali ini penyebabnya benar.

Selain itu, XyDesk versi web yang diakses lewat browser sempat tidak berfungsi
sama sekali sejak kami pindah alamat. Halaman-nya terbuka, tampilannya normal,
tombolnya bisa diklik — tapi tidak ada yang tersambung. Itu juga sudah beres.

### Aplikasi Android bisa dibuka lagi

**Apa yang berubah:** aplikasi yang tadinya diam di logo sekarang masuk ke
layar utama.

**Kenapa kami mengubahnya:** urutan kerjanya salah. Aplikasi menyiapkan saluran
komunikasi ke sistem Android untuk fitur Picture-in-Picture **sebelum** mesin
Flutter-nya sendiri siap. Sistem menolak, aplikasi berhenti di titik itu, dan
karena kegagalannya terjadi sebelum gambar pertama sempat digambar, yang kamu
lihat adalah logo bawaan Android — bertahan selamanya tanpa pesan apa pun.

Kami perlu jujur soal ini: keluhan yang sama sudah dua kali kami nyatakan
beres, di 6.5.2 dan 6.5.3. Keduanya memperbaiki fungsi yang salah. Yang rusak
ada di pintu masuk yang memanggil fungsi itu, jadi perbaikannya tidak pernah
tersentuh. Sekarang pintu masuknya yang dibenahi, dan ada penjaga otomatis yang
akan menolak perubahan apa pun yang mengembalikan urutan itu ke bentuk lama.

Yang belum bisa kami buktikan dari sini: apakah HP kamu benar-benar sudah bisa
dibuka. Perbaikan ini sudah lolos seluruh pemeriksaan otomatis kami, tapi
pemeriksaan itu tidak menjalankan aplikasi sungguhan — mereka tidak pernah
membuka pintu masuknya. Jadi kalau setelah memperbarui aplikasinya masih macet,
kabari kami. Itu informasi yang paling berharga buat kami sekarang.

### XyDesk versi web tidak lagi diblokir browsernya sendiri

**Apa yang berubah:** pairing dan tab Berita di `app.xydesk.my.id` berfungsi
lagi.

**Kenapa kami mengubahnya:** waktu kami memindahkan seluruh layanan ke alamat
baru bulan ini, satu berkas pengaturan keamanan terlewat. Berkas itu masih
memberi tahu browser bahwa aplikasi hanya boleh berbicara ke alamat **lama** —
yang sudah kami matikan. Browser menaatinya dan memblokir semua permintaan ke
alamat baru.

Ini jenis kerusakan yang paling menjengkelkan: build-nya hijau, deploy-nya
hijau, halamannya menjawab normal. Dari luar tidak ada yang salah. Sekarang
pengaturan itu diperiksa otomatis setiap kali ada perubahan — dibandingkan
dengan alamat yang benar-benar dipanggil kode, bukan dengan daftar yang ditulis
tangan.

### Layar "Hubungkan" tidak bisa terkunci selamanya

**Apa yang berubah:** kalau komputer yang mau kamu hubungkan tidak menjawab,
tombol Konek akan aktif lagi setelah 20 detik dan layarnya memberi tahu apa
yang terjadi.

**Kenapa kami mengubahnya:** tombol Konek dimatikan selama proses menyambung,
dan tidak ada batas waktunya. Jadi kalau prosesnya tidak pernah selesai, tombol
itu tidak pernah kembali. Satu-satunya jalan keluar adalah memuat ulang
halaman. Aplikasi di HP sudah punya batas waktu seperti ini; versi web tidak.
Angkanya kami samakan persis, supaya dua-duanya menyerah di saat yang sama.

### Kegagalan sekarang disebut kegagalan

**Apa yang berubah:** kalau menyambung gagal, kamu melihat pesan "gagal"
beserta sebabnya — bukan "sesi berakhir".

**Kenapa kami mengubahnya:** versi web tidak punya cara mengatakan gagal.
Semua kegagalan — server tidak terjangkau, koneksi ditolak, jaringan yang tidak
bisa ditembus — ditampilkan sebagai "sesi berakhir", yang terdengar seperti
akhir yang normal. Kamu tidak tahu ada yang salah, apalagi apa yang harus
diperbaiki. Status "tersambung" juga sempat dilaporkan sebelum sambungannya
benar-benar jadi, jadi indikatornya bisa berbohong. Keduanya dibenahi.

### Jaringan ketat dapat jalur cadangan lebih cepat

**Apa yang berubah:** kalau jaringan kamu memblokir sambungan langsung (kantor,
kampus, atau operator seluler tertentu), XyDesk mencari jalur cadangan lebih
cepat dan tidak lagi menyerah dalam diam.

**Kenapa kami mengubahnya:** jalur cadangan itu ditanyakan ke beberapa penyedia
satu per satu, tanpa batas waktu. Satu penyedia yang lambat menahan sisanya,
dan kalau totalnya kelamaan, aplikasi menyerah lalu jalan tanpa cadangan sama
sekali — tanpa pesan. Sekarang semua penyedia ditanya bersamaan dengan batas
waktu masing-masing, dan yang gagal dicatat supaya kelihatan.

Perlu dicatat: jalur cadangan ini **belum aktif** di server kami, karena kami
belum memilih penyedianya. Penyedia yang paling mudah dipakai meminta kartu
kredit, dan kami punya aturan untuk tidak memakai apa pun yang berbayar.
Perbaikannya sudah masuk supaya begitu penyedianya ada, semuanya langsung
bekerja — dan supaya kegagalannya tidak diam lagi.

### Kartu artikel Berita sama di tiga platform

**Apa yang berubah:** artikel Berita terlihat sama, entah kamu membukanya di HP,
di browser, atau di aplikasi Windows.

**Kenapa kami mengubahnya:** kategorinya ditulis dengan tiga cara berbeda — di
web menempel di atas sampul, di desktop duduk di badan kartu, di HP berupa teks
kapital di atas judul. Satu artikel yang sama terbaca sebagai tiga hal
berbeda. Sekarang satu bentuk: chip bundar di atas sampul.

### Warna aplikasi Windows akhirnya ikut

**Apa yang berubah:** warna ungu di aplikasi Windows sama dengan di HP dan web.

**Kenapa kami mengubahnya:** waktu identitas visual diganti ke markah X ungu,
aplikasi Windows terlewat dan tetap memakai ungu lama. Tombol aktif dan penanda
navigasi di sana warnanya berbeda dari dua platform lain. Warna penanda status
(jalan, peringatan, gagal) di web dan desktop juga sempat memakai warna yang
bukan bagian dari palet mana pun — murni hanyut, bukan keputusan.

### Changelog 6.6.0

Versi ini **6.6.0**, build 33. Daftar lengkapnya:

- Aplikasi Android yang berhenti di logo kini bisa dibuka; penyebabnya
  persiapan saluran Picture-in-Picture yang mendahului mesin aplikasi.
- Pengaturan keamanan versi web diperbarui ke alamat baru, jadi pairing dan
  Berita tidak lagi diblokir browser.
- Layar Hubungkan di web punya batas waktu 20 detik; tombol Konek tidak bisa
  lagi terkunci permanen.
- Kegagalan koneksi di web kini dilaporkan sebagai kegagalan beserta sebabnya,
  bukan sebagai "sesi berakhir".
- Status "tersambung" di HP hanya dilaporkan setelah sambungannya benar-benar
  jadi, dengan batas waktu 10 detik.
- Jalur cadangan untuk jaringan ketat ditanyakan ke semua penyedia bersamaan
  dengan batas waktu masing-masing; penyedia yang gagal kini tercatat.
- Kartu artikel Berita disamakan di HP, web, dan desktop.
- Warna aksen aplikasi Windows disamakan dengan HP dan web; warna status di web
  dan desktop dikembalikan ke palet resmi.
- Peta situs dan alamat sampul artikel yang masih menunjuk domain lama
  diperbaiki.
- Dokumen pedoman tampilan akhirnya dibuat — selama ini dirujuk dari kode tapi
  tidak pernah ada, dan itu sebab warnanya bisa menyimpang tanpa ketahuan.

### Yang sedang kami siapkan

Kami masih belum bisa mengukur berapa lama jeda antara gerakan di komputer dan
gambar yang kamu lihat di HP. Tanpa angka itu, semua klaim "lebih cepat" cuma
perasaan — jadi itu yang mau kami bereskan lebih dulu, dan butuh mesin Windows
sungguhan untuk mengukurnya.

Kami juga belum memasang penjaga untuk kasus yang lebih halus: tersambung, tapi
gambar tidak pernah muncul. Dan tampilan tiga platform belum sepenuhnya sama —
web sengaja dibuat lebih terang lewat penataan ulang bulan ini, dan kami belum
memutuskan apakah itu dipertahankan atau diseragamkan.

Satu hal yang tidak berubah: XyDesk masih berstatus **pra-beta**. Tombol unduh
di situs sengaja tetap mati sampai suara, multi-monitor, dan kontrol dari HP
kami verifikasi di komputer sungguhan. Pembaruan dari dalam aplikasi tetap
jalan seperti biasa.

---

## Checklist §9 sebelum terbit

- [ ] Sampul `web/public/news/covers/changelog-660.jpg` ada, 1424×752
- [ ] Screenshot asli untuk perubahan visual (kartu Berita, warna desktop,
      pesan gagal di web) — **belum ada**
- [ ] Field `slug` = `changelog-v6-6-0` terkirim
- [ ] Setelah terbit: `curl -o /dev/null -w '%{http_code}'
      https://news.xydesk.my.id/api/news/changelog-v6-6-0` → **200**
- [ ] Footer web `app.xydesk.my.id` → tautan versinya tidak 404
