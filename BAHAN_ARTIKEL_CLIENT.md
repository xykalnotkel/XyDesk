# Bahan Artikel Rilis - Client Flutter (Laras - XySpace Team)

**Tanggal:** 3 Sep 2026  
**Peran:** Client Flutter  
**Versi:** (akan ditentukan saat rilis)

---

## Fitur yang Sudah Selesai

### 1. **Hitungan Waktu Sesi Tamu**

**Apa yang berubah:**  
Buat kamu yang pakai XyDesk sebagai tamu (tanpa login), sekarang ada penghitung waktu yang jelas di tab "Sesi". Kamu bisa lihat berapa lama sesi berjalan dan berapa sisa waktu sebelum sesi berakhir — total 2 jam. Saat sisa waktu tinggal 5 menit, kartu akan berubah warna oranye dengan peringatan untuk segera menyimpan pekerjaan. Saat habis, kartu merah dan sesi tidak bisa dilanjutkan.

**Kenapa kami mengubah ini:**  
Sebelumnya, tamu tidak tahu berapa lama sesi mereka berjalan — tiba-tiba putus tanpa peringatan. Ini bikin frustrasi, apalagi kalau kamu sedang di tengah kerjaan penting. Sekarang kamu punya kendali penuh atas waktu.

**Screenshot:**  
![Card countdown sesi tamu - Total 2 jam, Sisa 1 jam 45 menit](https://app.xydesk.my.id/news/shots/<versi>-countdown-sesi-tamu.jpg)

---

### 2. **Aturan Kontrol yang Tersimpan di Akun**

**Apa yang berubah:**  
Sekarang kamu bisa buat, simpan, dan kelola beberapa profil pengaturan kontrol — masing-masing dengan mapping keyboard, joystick, mouse, dan touch sendiri. Ada dua profil default: "Gaming" (WASD + mouse untuk FPS) dan "Desktop" (Ctrl+C/V/X/Z untuk produktivitas). Profil tersimpan di akun kamu, jadi ikut ke semua perangkat yang kamu pakai.

**Kenapa kami mengubah ini:**  
Keluhan paling sering: pengaturan kontrol tidak ikut saat ganti perangkat. Kamu harus mengatur ulang dari nol setiap kali login di HP lain. Kami pindahkan penyimpanan ke akun, bukan perangkat. Satu kali atur, pakai di mana saja.

**Screenshot:**  
![Halaman Control Mapping - daftar profil dengan badge DEFAULT](https://app.xydesk.my.id/news/shots/<versi>-control-mapping-list.jpg)  
![Detail profil Gaming - mapping WASD + mouse](https://app.xydesk.my.id/news/shots/<versi>-control-mapping-gaming.jpg)

---

### 3. **Keyboard Virtual yang Lebih Nyaman Dipencet**

**Apa yang berubah:**  
Tombol keyboard virtual sekarang lebih besar (44px), dengan animasi tekan yang lebih halus dan responsif. Saat kamu pencet, tombol mengecil sedikit (scale 92%), warna ungu aksen muncul, dan bayangan hilang — persis seperti tombol fisik yang ditekan. Getaran haptic tetap ada untuk feedback taktil.

**Kenapa kami mengubah ini:**  
Keyboard virtual sebelumnya terlalu kecil untuk jari, terutama saat mode landscape. Tombol sering terlewat atau salah pencet. Kami besarkan touch target, perhalus animasi, dan perkuat visual feedback. Sekarang enak dipencet seperti keyboard HP sungguhan.

**Screenshot:**  
![Keyboard virtual split mode - tombol lebih besar dengan aksen ungu saat ditekan](https://app.xydesk.my.id/news/shots/<versi>-keyboard-virtual-responsif.jpg)

---

### 4. **Foto Profil dari Akun Google**

**Apa yang berubah:**  
Saat kamu login dengan Google, foto profil Google kamu sekarang otomatis muncul di topbar dan halaman Akun. Sebelumnya, semua user pakai avatar preset DiceBear atau inisial nama. Sekarang foto asli kamu yang tampil — lebih personal dan mudah dikenali.

**Kenapa kami mengubah ini:**  
Banyak user bertanya kenapa foto Google mereka tidak muncul di aplikasi. Kami sengaja memakai DiceBear di awal supaya avatar konsisten tanpa bergantung jaringan, tapi ternyata user lebih suka foto asli. Sekarang prioritasnya: foto Google → preset DiceBear → URL custom → inisial.

**Screenshot:**  
![Topbar dengan foto profil Google asli](https://app.xydesk.my.id/news/shots/<versi>-profile-google-topbar.jpg)  
![Header halaman Akun dengan foto profil](https://app.xydesk.my.id/news/shots/<versi>-profile-google-account.jpg)

---

### 5. **Nama Tamu yang Terdengar Manusiawi**

**Apa yang berubah:**  
Saat kamu masuk sebagai tamu, sekarang dapat nama manusia Indonesia yang natural — contoh: "Aditya Pratama", "Kirana Wijaya", "Budi Santoso". Bukan lagi "tamu-xxxx" yang terlihat artificial. Nama ini tersimpan selama sesi tamu berlangsung.

**Kenapa kami mengubah ini:**  
Nama "tamu-a3f8" terlihat seperti nomor seri, bukan manusia. Kami ingin sesi tamu terasa lebih personal, apalagi kalau kamu berkomentar di berita atau berinteraksi dengan fitur lain. 64 nama depan × 31 nama belakang = 1.984 kombinasi nama yang terdengar natural.

**Screenshot:**  
![Header akun tamu dengan nama "Aditya Pratama"](https://app.xydesk.my.id/news/shots/<versi>-guest-identity-nama-manusia.jpg)

---

### 6. **Tombol Langganan di Topbar**

**Apa yang berubah:**  
Tombol baru di bar atas (di samping notifikasi) membuka halaman Langganan. Sekarang akses ke info keanggotaan dan riwayat sewa PC lebih cepat — tidak perlu masuk ke halaman Akun dulu.

**Kenapa kami mengubah ini:**  
Langganan adalah fitur yang sering diakses, tapi sebelumnya tersembunyi di dalam halaman Akun. Kami angkat ke topbar supaya satu ketukan langsung sampai. Ikonnya transparan dan cocok di tema terang maupun gelap.

**Screenshot:**  
![Topbar dengan tombol avatar di sebelah notifikasi](https://app.xydesk.my.id/news/shots/<versi>-tombol-langganan-topbar.jpg)

---

### 7. **Data Lokal yang Tidak Bocor Antar Akun**

**Apa yang berubah:**  
Daftar perangkat, riwayat sesi, dan perangkat terakhir yang dihubungkan sekarang disimpan terpisah per akun. Saat kamu logout dari akun A dan login ke akun B, daftar perangkat A tidak muncul di B.

**Kenapa kami mengubah ini:**  
Ini masalah keamanan. Sebelumnya, semua data disimpan di kunci global. Saat ganti akun, data akun lama masih terlihat — ini bisa bocor ke orang lain yang pakai perangkat yang sama. Sekarang setiap akun punya ruang sendiri. Tamu juga punya ruang sendiri (kunci 'guest').

**Screenshot:**  
(Perubahan di belakang layar, tidak terlihat di UI — tidak butuh screenshot)

---

### 8. **Catatan Rilis Lengkap di Halaman Pembaruan**

**Apa yang berubah:**  
Halaman "Pusat Update" sekarang menampilkan catatan rilis lengkap dari GitHub Release — bukan hanya ringkasan versi. Kamu bisa baca semua perubahan detail setiap kali ada update.

**Kenapa kami mengubah ini:**  
Sebelumnya, halaman pembaruan hanya menampilkan "Versi 6.3.0 - perbaikan bug dan peningkatan performa" yang terlalu umum. User berhak tahu apa saja yang berubah, bukan cuma rangkuman. Sekarang kamu bisa baca changelog lengkap langsung di aplikasi.

**Screenshot:**  
![Halaman Pusat Update dengan catatan rilis lengkap](https://app.xydesk.my.id/news/shots/<versi>-changelog-lengkap.jpg)

---

## Changelog Lengkap (Bahasa Pengguna)

**Semua perubahan di versi <X.Y.Z>:**

- Hitungan waktu sesi tamu: total 2 jam dengan countdown di tab Sesi, peringatan saat sisa 5 menit.
- Profil kontrol tersimpan di akun: buat, edit, hapus, dan set default profil mapping (Gaming, Desktop, custom).
- Keyboard virtual lebih responsif: tombol 44px, animasi tekan halus, feedback visual jelas.
- Foto profil Google muncul otomatis di topbar dan halaman Akun.
- Tamu mendapat nama manusia Indonesia yang natural (contoh: "Aditya Pratama").
- Tombol Langganan di topbar untuk akses cepat ke info keanggotaan.
- Data lokal (perangkat, riwayat) tidak bocor antar akun — setiap akun punya ruang sendiri.
- Catatan rilis lengkap di halaman Pembaruan, bukan hanya ringkasan versi.

---

## Yang Sedang Kami Siapkan

- Clipboard sync dari PC: ambil teks dari papan klip host langsung di sesi (protokol sudah siap di sisi host, tinggal implementasi di client).
- Verifikasi fitur di perangkat Android nyata: rebrand, avatar DiceBear, ikon nav, dan IME keyboard masih butuh testing di build rilis.
- Screenshot layar sesi Android untuk artikel berita (butuh perangkat nyata + host yang berjalan).

---

## Catatan untuk CI/Release (Cakra)

- **Screenshot:** Placeholder di atas (`<versi>-*.jpg`) harus diganti dengan screenshot asli dari build rilis saat semua fitur diverifikasi di perangkat Android nyata.
- **Versi:** `<X.Y.Z>` harus diisi saat rilis (sesuai `pubspec.yaml`).
- **Penyatuan:** Bahan ini untuk disatukan dengan bahan dari agent lain (Desktop Shell, Web, Backend) menjadi SATU artikel rilis sesuai aturan NEWS_STYLE §8.
- **Tidak ada perubahan yang butuh screenshot sebelum/sesudah** — semua fitur baru, bukan modifikasi tampilan besar.

---

## Checklist

- [x] Setiap fitur punya blok: apa yang berubah + kenapa
- [x] Bahasa pengguna (tidak jargon internal)
- [x] Tidak ada nama file/fungsi/modul
- [x] Nomor versi disebut di changelog (bukan judul)
- [x] Penulis: Haekal Saputra
- [x] Excerpt (akan dibuat saat penyatuan): "<1-2 kalimat, maks 150 karakter>"
- [ ] Screenshot asli dari build rilis (butuh verifikasi di perangkat Android)
- [ ] Versi final ditentukan
- [ ] Disatukan dengan bahan dari agent lain
