# Cara Menulis Berita XyDesk

> **Satu kalimat yang mengatur semuanya:** berita bukan catatan kerjaan kita —
> berita adalah kabar untuk orang yang memakai XyDesk.
>
> Kalau satu kalimat cuma bermakna bagi orang yang pegang kodenya,
> kalimat itu **tidak boleh** masuk berita.

Dokumen ini wajib dibaca sebelum menekan tombol terbit di
`news.xystudio.my.id`. Alurnya ada di [`news/README.md`](../news/README.md);
dokumen ini mengatur **isinya**.

---

## 1. Aturan Emas

| ✅ Boleh | ❌ Jangan |
|---|---|
| "Sesi jarak jauh sekarang terasa lebih ringan di jaringan lambat." | "Optimasi pipeline encode H264 dan refactor `session.rs`." |
| "Masalah login yang bikin sebagian dari kamu tertahan di layar masuk, sudah beres." | "Fix bug null pointer pada `auth_service.dart:214`." |
| "Kami menambahkan 19 pengaman baru di sistem masuk." | "Menambahkan unit test pada `cloudflare/test/auth.test.js`." |
| "Buat yang pakai dua monitor, sekarang bisa pindah layar dari dalam sesi." | "Implementasi `DISPLAY_SELECT` tag 0x07." |

Ringkasnya:

- **Tulis dampaknya, bukan kerjanya.** Pembaca tidak pernah melihat repo kita.
- **Changelog tidak pernah masuk berita.** Changelog hidup di `CHANGELOG.md`
  dan di catatan GitHub Release. Berita punya satu job: bikin orang paham
  *kenapa ini penting buat dia*.
- **Nama berkas, nama modul, nama fungsi, nomor issue — tidak ada di berita.**
- **Angka versi tidak pernah jadi judul.** Boleh disebut sekali di badan
  berita kalau memang perlu, bukan di judul.

---

## 2. Nada: Gaul, Formal, Manusiawi

Bayangin lu lagi ngejelasin ke teman yang pintar tapi bukan programmer:
hangat, jelas, nggak menggurui.

**Yang dipakai:**

- Kata ganti orang kedua: **"kamu"**. Bukan "Anda" (kaku), bukan "lu"
  (terlalu tongkrongan untuk pengumuman resmi).
- Kalimat pendek. Satu kalimat satu ide.
- Kata kerja aktif: "kami tambahkan", "sekarang kamu bisa", "XyDesk akan".
- Bicara apa adanya. Kalau ada yang belum beres, bilang belum beres.

**Yang tidak dipakai:**

- Huruf kapital semua, tanda seru beruntun (`!!!`).
- Kata marketing kosong: "revolusioner", "terbaik di kelasnya",
  "solusi terdepan", "game-changer".
- Bahasa laporan: "telah dilakukan", "dalam rangka", "bersamaan dengan".
- Emoji lebih dari satu per artikel.
- Teknis internal, meski kelihatan keren.

**Nama yang konsisten (wajib):**

| Sebutan | Untuk apa |
|---|---|
| **XyDesk** | nama aplikasinya |
| **XySpace** | nama tim/studio yang menulis |
| **Tim XySpace** | penulis artikel (isi kolom `author`) |

Kata "XySpace" dipakai untuk timnya, bukan produknya. Jangan ketukar.

---

## 3. Rumus Artikel Rilis

Semua berita rilis mengikuti pola yang sama. Tiga bagian, urut, tidak lebih.

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

### Badan berita — tiga bagian

1. **Apa yang kerasa berubah.** Buka dengan dampak yang paling gampang
   dirasakan. Bukan urutan pengerjaan.
2. **Yang bisa kamu pakai sekarang.** Sebut 2–4 hal konkret. Satu paragraf
   per hal, atau satu kalimat kalau memang pendek.
3. **Yang sedang kami siapkan.** Satu paragraf penutup. Jujur — jangan
   menjanjikan tanggal.

Panjang total 150–300 kata. Lebih dari itu, orang berhenti baca.

---

## 4. Contoh: Salah vs Benar

### ❌ Salah (ini changelog yang disalin)

> **Rilis 6.2.3**
>
> Changelog:
> - `feat`: tambah endpoint preset kontrol di Worker
> - `fix`: gofmt pada `signaling/auth.go` dan `signaling/protocol.go`
> - `fix`: CORS default `*` menjadi kosong
> - `test`: tambah `input_codec_test.dart` (17 test)
> - upgrade `pubspec.lock`: 12 dependensi

Kenapa salah: pembaca tidak tahu `pubspec.lock` itu apa, tidak peduli
`gofmt`, dan tidak butuh daftar commit. Yang dia mau tahu: **apakah
aplikasinya jadi lebih baik malam ini, dan apa yang berubah buat dia.**

### ✅ Benar

> **Pengaturan kontrol kamu sekarang ikut ke mana pun kamu login**
>
> Kamu yang suka mengatur ulang tombol di sesi, sekarang tidak perlu
> mengulangnya dari nol di HP lain. Susunan kontrol tersimpan di akun
> kamu, jadi begitu login di perangkat lain, semuanya sudah menunggu.
>
> Atur sekali, pakai di mana saja. Kalau kamu punya dua HP — satu buat
> kerja, satu buat main — keduanya bisa memakai susunan yang sama, atau
> kamu simpan beberapa susunan berbeda dan pilih sesuai kebutuhan.
>
> Mulai sekarang juga kami memperbaiki kestabilan suara dua arah, supaya
> ngobrol lewat XyDesk tidak perlu lagi aplikasi tambahan.

Bedanya: nol kata teknis, dan pembaca langsung tahu apa untungnya buat dia.

---

## 5. Template Siap Pakai

Salin, isi, kirim. Jangan diedit strukturnya.

```bash
curl -X POST "https://news.xystudio.my.id/api/admin/publish" \
  -H "Content-Type: application/json" \
  -H "x-admin-token: <ADMIN_TOKEN>" \
  -d '{
    "title": "<MANFAAT UTAMA, 40-70 karakter>",
    "excerpt": "<1-2 kalimat, maks 150 karakter, berisi dampak>",
    "content": "<PARAGRAF 1: apa yang kerasa berubah>\n\n<PARAGRAF 2: yang bisa kamu pakai sekarang>\n\n<PARAGRAF 3: yang sedang kami siapkan>",
    "cover": "https://app.xystudio.my.id/news/covers/<file>.jpg",
    "category": "rilis",
    "author": "Tim XySpace"
  }'
```

Sampul: `1424×752`, taruh di `web/public/news/covers/`, jangan pakai URL luar.

---

## 6. Kategori

| Kategori | Dipakai untuk |
|---|---|
| `rilis` | Ada versi aplikasi baru yang sampai ke pengguna |
| `teknik` | Penjelasan cara kerja, tapi tetap tanpa jargon internal |
| `umum` | Pengumuman, gangguan, atau kabar yang bukan rilis |

Kalau ragu antara `rilis` dan `umum`, pilih `rilis` — yang penting beritanya
ada.

---

## 7. Kapan Wajib Terbit

- ✅ Setiap kali versi di `pubspec.yaml` naik. **Tidak ada rilis tanpa berita.**
- ✅ Ada fitur yang bisa dipakai pengguna, sekecil apa pun.
- ✅ Ada gangguan atau pemeliharaan—justru paling penting saat ini.
- ✅ Ada keputusan produk yang mengubah kebiasaan pengguna.
- ❌ Jangan terbit hanya untuk perbaikan internal yang tidak mengubah apa
  pun yang dirasakan pengguna.

Kalau ragu, terbitkan yang pendek. Umpan berita yang sepi jauh lebih
merusak kepercayaan daripada berita yang singkat.

### Saat ada gangguan

Singkat, jujur, tanpa menyalahkan siapa pun:

```text
Judul   : "Layanan XyDesk sedang mengalami gangguan"
Isi     : Apa yang tidak bisa dipakai, sejak kapan, apa yang sedang
          dikerjakan, dan kapan Kabar berikutnya akan datang.
Kategori: umum
```

Sebut waktu kabaran berikutnya, lalu tepati.

---

## 8. Checklist Sebelum Terbit

Salin ke PR kalau perlu.

```text
[ ] Judul berisi manfaat — bukan nomor versi
[ ] Tidak ada satu pun: nama berkas, nama fungsi, nomor issue, nama paket
[ ] Tidak menyalin isi CHANGELOG.md
[ ] Penulis: "Tim XySpace"
[ ] Sebutan merek benar: XyDesk = aplikasi, XySpace = tim
[ ] Excerpt ≤ 150 karakter dan enak dibaca sendiri
[ ] Badan 150–300 kata, tiga bagian
[ ] Sudah dibaca keras-keras: terdengar seperti orang, bukan seperti bot
[ ] Sampul 1424×752 ada di web/public/news/covers/
[ ] Kategori sudah benar
[ ] Setelah terbit: buka /n/<slug>, cek kartu + OG saat dibagikan
```

---

## 9. Yang Terjadi Setelah Terbit

Worker mengurus sisanya sendiri (push OneSignal + email ke pelanggan), jadi
**anggap berita ini sudah terbaca begitu tombol dikirim**. Tidak ada draft,
tidak ada tombol tarik kembali.

Karena itu urutan yang benar:

1. Rilisnya naik dulu (workflow Release hijau).
2. Baru beritanya terbit.
3. Baru diumumkan ke mana-mana.

Jangan dibalik: berita yang menjanjikan sesuatu yang belum sampai ke
pengguna adalah janji yang keburu terdengar.
