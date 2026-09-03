# Cara Menulis Berita XyDesk

> **Satu kalimat yang mengatur semuanya:** berita adalah kabar untuk orang
> yang memakai XyDesk — ditulis **lengkap, detail, dan jujur**: apa yang
> berubah, **kenapa** diubah, dan **buktinya** (screenshot asli).
>
> Detail boleh dan wajib. Yang tetap dilarang: jargon internal yang cuma
> bermakna bagi orang yang pegang kodenya.

Dokumen ini wajib dibaca sebelum menekan tombol terbit di
`news.xystudio.my.id`. Alurnya ada di [`news/README.md`](../news/README.md);
dokumen ini mengatur **isinya**.

---

## 1. Aturan Emas

| ✅ Boleh | ❌ Jangan |
|---|---|
| "Sesi jarak jauh sekarang lebih ringan di jaringan lambat — sebelumnya video sering patah saat sinyal turun, sekarang kualitas menyesuaikan otomatis." | "Optimasi pipeline encode H264 dan refactor `session.rs`." |
| "Masalah login yang bikin sebagian dari kamu tertahan di layar masuk, sudah beres. Penyebabnya: sesi lama tidak terhapus bersih saat ganti akun." | "Fix bug null pointer pada `auth_service.dart:214`." |
| "Buat yang pakai dua monitor: sekarang bisa pindah layar dari dalam sesi. Ini permintaan yang paling sering masuk." | "Implementasi `DISPLAY_SELECT` tag 0x07." |

Ringkasnya:

- **Tulis dampaknya DAN alasannya.** Setiap perubahan dijelaskan dua sisi:
  *apa yang berubah buat kamu* dan *kenapa kami mengubahnya*. Pembaca berhak
  tahu alasan, bukan cuma hasil.
- **Berita rilis wajib memuat changelog versi pengguna** — daftar LENGKAP
  semua perubahan yang bisa dirasakan pengguna di rilis itu, diterjemahkan
  ke bahasa manusia. Bukan salinan mentah `CHANGELOG.md` (itu tetap untuk
  tim & GitHub Release), tapi juga bukan rangkuman yang menyembunyikan
  perubahan. Kalau ada 9 perubahan yang kerasa, sembilan-sembilannya masuk.
- **Nama berkas, nama modul, nama fungsi, nomor issue — tetap tidak ada di
  berita.** Detail ≠ jargon.
- **Angka versi tidak jadi judul**, tapi **wajib disebut di badan berita**
  (sekali, di bagian changelog) supaya pembaca tahu persis rilis mana yang
  dibahas.

---

## 2. Nada: Gaul, Formal, Manusiawi

Bayangin lu lagi ngejelasin ke teman yang pintar tapi bukan programmer:
hangat, jelas, nggak menggurui — tapi TUNTAS. Jangan pelit informasi.

**Yang dipakai:**

- Kata ganti orang kedua: **"kamu"**. Bukan "Anda" (kaku), bukan "lu"
  (terlalu tongkrongan untuk pengumuman resmi).
- Kalimat pendek. Satu kalimat satu ide.
- Kata kerja aktif: "kami tambahkan", "sekarang kamu bisa", "XyDesk akan".
- Bicara apa adanya. Kalau ada yang belum beres, bilang belum beres.
  Kalau sebuah fitur baru diuji terbatas, tulis begitu.

**Yang tidak dipakai:**

- Huruf kapital semua, tanda seru beruntun (`!!!`).
- Kata marketing kosong: "revolusioner", "terbaik di kelasnya",
  "solusi terdepan", "game-changer".
- Bahasa laporan: "telah dilakukan", "dalam rangka", "bersamaan dengan".
- Emoji lebih dari satu per artikel.
- Jargon internal (nama file/fungsi/modul), meski kelihatan keren.

**Nama yang konsisten (wajib):**

| Sebutan | Untuk apa |
|---|---|
| **XyDesk** | nama aplikasinya |
| **XySpace** | nama tim/studio yang menulis |
| **Haekal Saputra** | penulis artikel (isi kolom `author`) — label resmi `XySpace` tampil sebagai badge |

Kata "XySpace" dipakai untuk timnya, bukan produknya. Jangan ketukar.

---

## 3. Gambar: banner saja TIDAK cukup

Aturan lama "satu sampul per artikel" sudah tidak berlaku. Mulai sekarang:

1. **Sampul (banner) tetap wajib** — `1424×752`, di
   `web/public/news/covers/`, jangan URL luar.
2. **Setiap perubahan yang terlihat mata WAJIB disertai screenshot ASLI**
   di badan berita, tepat di bawah paragraf yang menjelaskannya:
   - Screenshot diambil dari **build yang benar-benar dirilis** — bukan
     mockup, bukan desain Figma, bukan gambar hasil edit/AI, bukan build
     lokal yang beda dari yang diterima pengguna.
   - Untuk perubahan tampilan, format terbaik: **sebelum vs sesudah**
     (dua gambar berurutan, keterangan jelas mana yang lama mana yang baru).
   - Untuk fitur baru: screenshot fitur itu sedang dipakai, bukan layar
     kosong.
   - Perubahan yang tidak terlihat (performa, keamanan, perbaikan di
     belakang layar) tidak butuh screenshot — jangan dipaksakan pakai
     gambar hiasan/stok.
3. Simpan screenshot di `web/public/news/shots/` dengan nama jelas:
   `<versi>-<apa>.jpg` (contoh: `6.3.0-panel-koneksi-baru.jpg`,
   `6.3.0-login-sebelum.jpg`, `6.3.0-login-sesudah.jpg`).
   Ter-deploy otomatis ke `app.xystudio.my.id/news/shots/<file>.jpg`.
4. Sintaks gambar di badan berita — satu baris sendiri, di antara paragraf:

   ```text
   ![Panel koneksi yang baru — daftar perangkat kini muncul duluan](https://app.xystudio.my.id/news/shots/6.3.0-panel-koneksi-baru.jpg)
   ```

   Teks di dalam `[...]` adalah keterangan gambar dan wajib diisi —
   jelaskan apa yang sedang dilihat pembaca.

> **Status dukungan (kini, per 3 Sep 2026):** sintaks `![...](...)` di atas
> SUDAH dirender jadi gambar di aplikasi Android (Flutter), web, dan desktop
> shell — hanya URL dari domain sendiri (`app.xystudio.my.id`) yang
> dirender, baris lain tetap paragraf biasa. Halaman berbagi `/n/<slug>`
> hanya memuat metadata (judul, ringkasan, sampul), jadi tidak menampilkan
> teks mentah. Berita rilis sudah bisa memakai blok gambar.

---

## 4. Rumus Artikel Rilis

Semua berita rilis mengikuti pola yang sama. Empat bagian, urut.

### Judul — manfaatnya, bukan versinya

```text
✅ "Remote dari HP ke PC sekarang kerasa lebih enteng"
✅ "Buat pengguna dua monitor: pindah layar langsung dari dalam sesi"
❌ "Rilis 6.2.3"
❌ "Update: perbaikan bug dan peningkatan performa"
```

Panjang judul ideal 40–70 karakter. Bisa dibaca sekali lihat.

### Ringkasan (excerpt) — 1–2 kalimat, maksimal 150 karakter

Dipakai di kartu berita, di pranala saat dibagikan, dan di notifikasi
push. Ini kalimat yang paling banyak dibaca orang, jadi tulis paling akhir
setelah badan berita selesai.

### Badan berita — empat bagian

1. **Pembuka: apa yang kerasa berubah.** 1–2 paragraf, dampak paling besar
   duluan.
2. **Rincian per perubahan.** Untuk SETIAP perubahan penting, tulis
   blok kecil dengan pola tetap:
   - *Apa yang berubah* — dijelaskan dari sisi pengguna.
   - *Kenapa kami mengubahnya* — alasan jujurnya: keluhan pengguna, bug
     yang ditemukan, hasil pengukuran, atau keputusan produk. Kalau
     alasannya "kami salah desain sebelumnya", tulis begitu.
   - *Screenshot asli* tepat di bawahnya (untuk perubahan visual —
     lihat bagian 3).
3. **Changelog rilis ini** — daftar lengkap dalam bahasa pengguna.
   Sebut nomor versinya sekali di sini. Setiap butir satu kalimat:
   perubahannya + efeknya. Butir kecil (perbaikan tulisan, geser posisi
   tombol) tetap masuk — cukup satu baris. Ini bagian yang membuat
   pembaca percaya kami tidak menyembunyikan apa pun.
4. **Yang sedang kami siapkan.** Satu paragraf penutup. Jujur — jangan
   menjanjikan tanggal.

Panjang total: **bebas, selama setiap kalimatnya berisi.** Berita rilis yang
benar biasanya 300–700 kata. Yang dilarang bukan panjang, tapi basa-basi.

---

## 5. Contoh: Salah vs Benar

### ❌ Salah (changelog mentah yang disalin)

> **Rilis 6.2.3**
>
> Changelog:
> - `feat`: tambah endpoint preset kontrol di Worker
> - `fix`: gofmt pada `signaling/auth.go` dan `signaling/protocol.go`
> - `fix`: CORS default `*` menjadi kosong
> - `test`: tambah `input_codec_test.dart` (17 test)

Kenapa salah: pembaca tidak tahu dan tidak peduli itu semua. Tidak ada
alasan, tidak ada dampak, tidak ada bukti.

### ❌ Juga salah (versi lama yang terlalu tipis)

> Kamu yang suka mengatur ulang tombol, sekarang tidak perlu mengulang
> dari nol di HP lain. Atur sekali, pakai di mana saja.

Kenapa salah sekarang: enak dibaca, tapi menyembunyikan sisa isi rilis,
tidak menjelaskan kenapa, dan tidak ada bukti visual. Pembaca yang teliti
akan merasa dikasih brosur, bukan kabar.

### ✅ Benar

> **Pengaturan kontrol kamu sekarang ikut ke mana pun kamu login**
>
> Kamu yang suka mengatur ulang tombol di sesi, sekarang tidak perlu
> mengulangnya dari nol di HP lain. Susunan kontrol tersimpan di akun kamu.
>
> **Kenapa kami mengubah ini:** dari komentar kalian di berita sebelumnya,
> keluhan paling sering adalah mengatur ulang tombol tiap ganti perangkat.
> Dulu susunan disimpan di HP masing-masing — itu keputusan awal kami yang
> ternyata merepotkan, jadi kami pindahkan ke akun.
>
> ![Layar pengaturan kontrol — tombol simpan susunan yang baru](https://app.xystudio.my.id/news/shots/6.3.0-preset-kontrol.jpg)
>
> **Semua perubahan di versi 6.3.0:**
> - Susunan kontrol tersimpan di akun, ikut ke semua perangkatmu.
> - Suara dua arah lebih stabil di jaringan naik-turun — sebelumnya suara
>   bisa putus beberapa detik saat sinyal drop.
> - Layar masuk tidak lagi menahan kamu setelah ganti akun.
> - Teks di halaman perangkat dirapikan; beberapa istilah disamakan.
>
> **Yang sedang kami siapkan:** panggilan suara langsung dari sesi, tanpa
> aplikasi tambahan. Belum ada tanggal — kami kabari begitu siap dicoba.

Bedanya: tetap nol jargon, tapi lengkap — apa, kenapa, bukti, dan daftar
jujur semua perubahan.

---

## 6. Template Siap Pakai

Salin, isi, kirim. Jangan diedit strukturnya.

```bash
curl -X POST "https://news.xystudio.my.id/api/admin/publish" \
  -H "Content-Type: application/json" \
  -H "x-admin-token: <ADMIN_TOKEN>" \
  -d '{
    "title": "<MANFAAT UTAMA, 40-70 karakter>",
    "excerpt": "<1-2 kalimat, maks 150 karakter, berisi dampak>",
    "content": "<PEMBUKA: apa yang kerasa berubah>\n\n<PER PERUBAHAN: apa + kenapa + ![keterangan](url screenshot) bila visual>\n\n<CHANGELOG: Semua perubahan di versi X.Y.Z: daftar lengkap bahasa pengguna>\n\n<PENUTUP: yang sedang kami siapkan>",
    "cover": "https://app.xystudio.my.id/news/covers/<file>.jpg",
    "category": "rilis",
    "author": "Haekal Saputra"
  }'
```

Sampul: `1424×752` di `web/public/news/covers/`.
Screenshot: di `web/public/news/shots/`, nama `<versi>-<apa>.jpg`.
Jangan pakai URL luar untuk keduanya.

---

## 7. Kategori

| Kategori | Dipakai untuk |
|---|---|
| `rilis` | Ada versi aplikasi baru yang sampai ke pengguna |
| `teknik` | Penjelasan cara kerja, tapi tetap tanpa jargon internal |
| `umum` | Pengumuman, gangguan, atau kabar yang bukan rilis |

Kalau ragu antara `rilis` dan `umum`, pilih `rilis` — yang penting beritanya
ada.

---

## 8. Kapan Wajib Terbit

- ✅ Setiap kali versi di `pubspec.yaml` naik. **Tidak ada rilis tanpa berita.**
- ✅ Ada fitur yang bisa dipakai pengguna, sekecil apa pun.
- ✅ Ada gangguan atau pemeliharaan — justru paling penting saat ini.
- ✅ Ada keputusan produk yang mengubah kebiasaan pengguna.
- ❌ Jangan terbit hanya untuk perbaikan internal yang tidak mengubah apa
  pun yang dirasakan pengguna.

Kalau ragu, terbitkan yang pendek. Umpan berita yang sepi jauh lebih
merusak kepercayaan daripada berita yang singkat.

### Siapa yang menulis — tiap agent, lalu disatukan saat rilis

Tiap agent menulis **bahan berita untuk kerjanya sendiri** (bukan role
berita yang mengarang semua): blok "apa yang berubah + kenapa" dalam
bahasa pengguna + screenshot asli sesuai §3–§6, ditulis saat sesinya
ditutup (bukan menyusul). Saat rilis, role yang menangani rilis
**menyatukan bahan semua agent menjadi SATU artikel rilis** — satu
artikel per rilis, bukan banyak artikel kecil.

### Saat ada gangguan

Singkat, jujur, tanpa menyalahkan siapa pun:

```text
Judul   : "Layanan XyDesk sedang mengalami gangguan"
Isi     : Apa yang tidak bisa dipakai, sejak kapan, apa yang sedang
          dikerjakan, dan kapan kabar berikutnya akan datang.
Kategori: umum
```

Sebut waktu kabaran berikutnya, lalu tepati.

---

## 9. Checklist Sebelum Terbit

Salin ke PR kalau perlu.

```text
[ ] Judul berisi manfaat — bukan nomor versi
[ ] Setiap perubahan penting punya blok: apa yang berubah + kenapa
[ ] Bagian "Semua perubahan di versi X.Y.Z" ada, LENGKAP, bahasa pengguna
[ ] Nomor versi disebut sekali di bagian changelog (bukan di judul)
[ ] Tidak ada satu pun: nama berkas, nama fungsi, nomor issue, nama paket
[ ] Tidak menyalin baris mentah dari CHANGELOG.md
[ ] Setiap perubahan visual punya screenshot ASLI dari build rilis
[ ] Screenshot sebelum/sesudah untuk perubahan tampilan besar
[ ] Semua gambar di web/public/news/ (covers/ dan shots/), bukan URL luar
[ ] Setiap gambar punya keterangan yang menjelaskan isinya
[ ] Tidak ada mockup, gambar stok, atau gambar hasil AI sebagai "screenshot"
[ ] Penulis: "Haekal Saputra"
[ ] Sebutan merek benar: XyDesk = aplikasi, XySpace = tim
[ ] Excerpt ≤ 150 karakter dan enak dibaca sendiri
[ ] Sudah dibaca keras-keras: terdengar seperti orang, bukan seperti bot
[ ] Sampul 1424×752 ada di web/public/news/covers/
[ ] Kategori sudah benar
[ ] Setelah terbit: buka /n/<slug>, cek kartu + OG + semua gambar tampil
```

---

## 10. Yang Terjadi Setelah Terbit

Worker mengurus sisanya sendiri (push OneSignal + email ke pelanggan), jadi
**anggap berita ini sudah terbaca begitu tombol dikirim**. Tidak ada draft,
tidak ada tombol tarik kembali.

Karena itu urutan yang benar:

1. Rilisnya naik dulu (workflow Release hijau).
2. Screenshot diambil dari build rilis itu, di-commit ke
   `web/public/news/shots/`, dan deploy web selesai (gambar bisa dibuka).
3. Baru beritanya terbit.
4. Baru diumumkan ke mana-mana.

Jangan dibalik: berita yang menjanjikan sesuatu yang belum sampai ke
pengguna — atau menautkan gambar yang belum ter-deploy — adalah janji yang
keburu terdengar.
