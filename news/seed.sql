-- Seed berita XyDesk (konten asli, bukan dummy — ini yang tampil di Web/Android/Desktop).
--
-- Memakai UPSERT (ON CONFLICT(slug) DO UPDATE), bukan INSERT OR IGNORE.
-- Alasannya: dengan OR IGNORE, artikel yang sudah pernah masuk D1 tidak
-- pernah berubah lagi — perbaikan judul atau isi di berkas ini diam-diam
-- tidak sampai ke produksi. Sekarang berkas ini yang jadi acuan isi artikel,
-- dan aman dijalankan berulang kali. Like dan komentar tidak tersentuh
-- karena keduanya merujuk posts.id yang tetap sama.

INSERT INTO posts (slug, title, excerpt, content, cover, category, author, published) VALUES
(
  'xydesk-24-control-api-desktop-shell',
  'XyDesk 2.4 — Control API lokal dan shell desktop baru',
  'Host Windows kini punya panel baru berbasis Electron + Next.js, dengan engine Rust tetap di belakang. Status sesi, statistik video, dan pengaturan password kini bisa dilihat langsung dari desktop — tanpa menebak dari log.',
  'Selama ini GUI host cuma launcher: menampilkan ID dan password, menjaga engine tetap hidup. Semua yang terjadi di dalam engine — sesi aktif, frame terkirim, encoder yang dipakai — tidak terlihat.

Mulai versi 2.4, engine punya control API lokal di 127.0.0.1 dengan token acak per-lahir. Shell desktop baru (Electron + Next.js) membaca status itu dan menampilkannya di panel: durasi sesi, FPS kirim, badge NVENC, sampai log engine langsung.

Yang penting: keputusan arsitektur tidak berubah. Capture DXGI dan encode tetap di Rust. Electron hanya cangkang — desktopCapturer Chromium jauh di atas target latency 40 ms, jadi media tidak boleh lewat sana.

Aksi yang tersedia dari panel: password acak baru, password kustom, dan akhiri sesi. Stop-session semantiknya sama dengan bye dari client — koneksi ditutup dan peer wajib pairing ulang.',
  'https://app.xydesk.my.id/news/covers/desktop-shell.jpg',
  'rilis',
  'Haekal Saputra',
  1
),
(
  'nvenc-encode-hardware-jalur-produksi',
  'NVENC aktif: encode hardware masuk jalur produksi',
  'Encoder H264 hardware NVIDIA kini dipakai otomatis saat GPU tersedia, dengan fallback openh264 bila tidak ada. Angka benchmark membuktikan kenapa ini wajib: openh264 CPU tidak tembus target encode di bawah 10 ms.',
  'Benchmark internal sudah jujur dari awal: openh264 (software) butuh sekitar 30 ms untuk 640x360. Untuk target roadmap — encode di bawah 10 ms di 1080p60 — angka itu tidak mungkin. Hardware encode (NVENC/AMF/QuickSync) adalah prasyarat, bukan opsi.

Implementasi NVENC di host kini terkabel ke jalur capture: frame pertama menentukan resolusi, NVENC diinisialisasi bila dimensi genap dan driver NVIDIA tersedia, dan konversi RGBA ke NV12 (BT.601 full-range) dilakukan sebelum encode. Kalau NVENC gagal — tidak ada GPU, driver lama — jalur fallback openh264 tetap berjalan tanpa crash.

Panel host menampilkan status encoder langsung: badge NVENC menyala kalau hardware aktif. Yang belum berubah: angka glass-to-glass di jaringan nyata masih harus dibuktikan di lab. Targetnya tetap 40 ms di LAN, dan kami tidak akan klaim "cocok untuk game" sebelum fotonya ada.',
  'https://app.xydesk.my.id/news/covers/nvenc.jpg',
  'teknik',
  'Haekal Saputra',
  1
),
(
  'mengukur-latency-cara-jujur',
  'Mengukur latency seperti orang jujur',
  'Protokol pengukuran XyDesk: timestamp frame di host, dibandingkan di client, lalu foto kedua layar berjejer. Bukan angka dari datasheet, bukan perasaan "terasa cepat".',
  'Klaim latency remote desktop biasanya dihias: diukur di kondisi ideal, tanpa menyebut resolusi, atau pakai angka encode saja. Untuk XyDesk, aturannya satu: bukti dulu, baru poles.

Protokol kami (docs/LATENCY.md): host menampilkan jam milidetik di layar, client memotret layar host dan layar HP berjejer, lalu selisih jam di kedua frame dibaca langsung. Sepuluh pasang foto, ambil median. Kalau ada encode hardware, decoder hardware, dan jaringan LAN yang sehat, angka di bawah 40 ms harusnya tercapai — tapi sampai fotonya ada, itu tetap dugaan.

Status hari ini: loop capture-encode-RTP-terima sudah terbukti di test loopback otomatis, benchmark encode sudah punya angka (30 ms openh264 di 640x360), dan angka end-to-end masih kosong. Begitu lab Windows jalan, hasilnya akan dipublikasikan di sini — apapun hasilnya.',
  'https://app.xydesk.my.id/news/covers/latency.jpg',
  'teknik',
  'Haekal Saputra',
  1
),
(
  'xydesk-25-monokrom-dan-lisensi-terbuka',
  'XyDesk 2.5 — monokrom, berita di mana-mana, lisensi terbuka',
  'Tampilan baru dominan hitam-putih dengan aksen ungu, berita yang sama di Android/Desktop/Web, logo X tanpa glow, dan kode sumber berlisensi Apache 2.0.',
  'Versi 2.5 adalah rilis "beres-beres": tampilan, konsistensi, dan keterbukaan.\n\nTampilan. Semua platform kini memakai bahasa visual yang sama — dominan hitam-putih dengan ungu hanya sebagai aksen kecil. Logo X yang selama ini dipakai di sampul berita menjadi logo resmi, tanpa glow dan tanpa bayangan. Splash Android mengikuti tema terang, ikon navigasi mengikuti warna tema.\n\nBerita. Satu umpan berita yang sama tampil di Android, Desktop, dan Web — lengkap dengan like, komentar, dan bagikan. Di web, setiap berita punya meta OpenGraph sendiri sehingga tautan yang dibagikan ke WhatsApp atau X tampil dengan judul, ringkasan, dan sampul yang benar. Perbaikan penting: sebelumnya berita di web gagal dimuat ("Failed to fetch") karena aturan Content-Security-Policy belum mengizinkan domain berita — sekarang sudah diizinkan dan diverifikasi live.\n\nLisensi. Kode sumber XyDesk kini berlisensi Apache 2.0. Daftar lisensi perangkat lunak pihak ketiga (Flutter, Electron, Lucide, Inter, dan lain-lain) bisa dibaca di halaman Legal di semua platform.\n\nVersi: Android 2.5.0 (build 19), Web 2.5.0, Desktop 2.5.0. Setiap rilis berikutnya akan selalu punya catatan seperti ini di Berita.',
  'https://app.xydesk.my.id/news/covers/v25.jpg',
  'rilis',
  'Haekal Saputra',
  1
)
ON CONFLICT(slug) DO UPDATE SET
  title = excluded.title,
  excerpt = excluded.excerpt,
  content = excluded.content,
  cover = excluded.cover,
  category = excluded.category,
  author = excluded.author,
  published = excluded.published;

-- Changelog rilis 6.2.0. Slug SENGAJA deterministik: footer web dan layar
-- Tentang menautkan nomor versi ke `changelog-v<major>-<minor>-<patch>`.
INSERT INTO posts (slug, title, excerpt, content, cover, category, author, published) VALUES
(
  'changelog-v6-2-0',
  'XyDesk 6.2.0 — rilis kejujuran: unduhan dimatikan, 482 lisensi dibuka',
  'Tidak ada fitur media baru di rilis ini. Yang berubah adalah apa yang XyDesk katakan tentang dirinya sendiri: status rilis yang sebenarnya, nomor versi yang punya aturan, daftar lisensi yang lengkap, dan badge resmi supaya tidak ada yang bisa mengaku tim.',
  'Rilis ini tidak menambah satu pun fitur media. Kalau kamu menunggu audio atau multi-monitor, tunggu rilis berikutnya. Yang kami kerjakan kali ini adalah sesuatu yang lebih mendasar: membuat XyDesk berhenti mengatakan hal yang belum benar tentang dirinya sendiri.

TOMBOL UNDUH KAMI MATIKAN

Sampai hari ini situs XyDesk menyediakan tombol Download untuk Windows dan Android. Masalahnya sederhana: produk ini belum pernah masuk beta test. Layar sesi, HUD kontrol, mouse dan keyboard virtual belum pernah diverifikasi mengendalikan PC sungguhan. Audio WASAPI belum pernah didengar orang. Push notifikasi belum pernah dibuktikan sampai ke perangkat.

Menyediakan tombol unduh untuk sesuatu seperti itu bukan kepercayaan diri, itu janji yang belum bisa ditepati. Jadi tombolnya mati, dan halaman Unduh sekarang menampilkan hal yang jujur: versi berapa, tahap apa, dan enam syarat yang harus lulus sebelum tombolnya menyala lagi.

Syarat itu bukan perasaan. Semuanya bisa dicentang atau tidak: uji dengar audio di PC nyata, capture multi-monitor terverifikasi di perangkat keras, HUD terbukti mengendalikan host, latency ujung-ke-ujung terukur di jaringan nyata, push notifikasi terkirim dan terbuka, dan sesi 30 menit tanpa putus.

482 KOMPONEN BERLISENSI, SEMUANYA DIBUKA

Halaman Lisensi lama menyebut sembilan komponen di web dan delapan belas di aplikasi. Angka sebenarnya, setelah seluruh lockfile dipindai: 482. Sembilan puluh paket Dart, 324 crate Rust, 58 paket npm, dan 10 aset serta layanan pihak ketiga.

Selisih itu bukan kelalaian kecil. Lisensi open source adalah kewajiban hukum, dan kewajiban yang tidak kamu daftar tetap berlaku. Sekarang daftarnya dibangkitkan mesin dari pubspec.lock, Cargo.lock, dan package-lock.json — jadi ia ikut berubah otomatis setiap kali dependensi berubah, bukan diketik ulang tangan dan basi tiga rilis kemudian.

Di aplikasi Android, menu Tentang mendapat satu tambahan: tombol yang membuka registry lisensi bawaan Flutter. Registry itu membaca berkas LICENSE dari biner yang sedang berjalan. Ia mustahil basi, karena sumbernya adalah aplikasi itu sendiri.

BADGE RESMI, DAN KENAPA IA HARUS MUSTAHIL DIPALSUKAN

Mulai rilis ini, nama penulis berita dan komentar dari tim tampil dengan logo XyDesk dan label Resmi.

Badge yang bisa diminta sendiri tidak ada gunanya — justru berbahaya, karena ia mengajari pembaca untuk percaya pada lencana. Jadi aturannya: badge hanya diberikan server, dan hanya kalau request membawa token admin. Mengirim official: true di body komentar tidak berpengaruh apa pun. Ada enam pengujian otomatis yang memastikan itu tetap benar setiap kali kode berubah.

Lapis kedua: nama tim dikunci. Komentar publik yang memakai nama anggota tim ditolak, bukan sekadar tampil tanpa badge. Alasannya, pembaca yang sedang menggulir membaca nama, bukan ketiadaan lencana.

SATU NOMOR VERSI, SATU SUMBER

Dalam lima jam pada 31 Agustus, XyDesk melompat dari 2.5.0 ke 6.1.0. Tidak ada satu pun perubahan yang merusak kompatibilitas. Sementara itu footer situs masih menulis v2.5.0, karena angka itu diketik tangan di kode dan tidak pernah ikut berubah.

Sekarang ada aturannya, tertulis di docs/VERSIONING.md, dan aturan itu mengikat: nomor versi hidup di satu tempat yaitu pubspec.yaml. Situs membacanya saat build. Aplikasi membacanya dari paket. MAJOR hanya naik untuk lima alasan yang didaftar tertutup — protokol patah, data tidak bisa dimigrasi, fitur dicabut, syarat platform naik, model lisensi berubah. Redesign visual bukan MAJOR. Rebranding bukan MAJOR.

Angka 6.x diteruskan, bukan direset, karena tag 6.1.0 sudah beredar dan menurunkannya akan membuat installer menolak update. Tapi ia berhenti bergerak liar.

YANG JUGA DIPERBAIKI

Artikel yang diterbitkan lewat API admin selama ini kehilangan seluruh paragrafnya — fungsi pembersih meratakan semua whitespace jadi satu spasi, sehingga tulisan panjang menjadi satu blok. Hanya artikel bawaan yang punya paragraf. Sekarang jeda paragraf dipertahankan.

Menekan Connect tidak lagi mampir ke halaman perantara; ia langsung masuk layar sesi dengan status Menyambung. Splash screen dirombak dengan rel progres nyata dan chip tahap rilis. Panel Riwayat diberi ruang. Logo direvisi dan sekarang dibangkitkan dari kode untuk 20-an ukuran sekaligus, termasuk perbaikan lapisan ikon adaptif Android yang selama ini kekecilan dan di-upscale peluncur.

YANG MASIH BELUM

Layar sesi, HUD, mouse dan keyboard virtual belum terbukti mengendalikan host sungguhan. Audio dan multi-monitor belum diuji di perangkat keras. Push notifikasi belum dibuktikan. Latency di jaringan nyata belum terukur.

Empat hal itu adalah pekerjaan berikutnya, dan tidak satu pun bisa diselesaikan dari editor kode. Semuanya butuh PC Windows sungguhan dan HP di tangan. Sampai itu terjadi, tombol unduh tetap mati.',
  'https://app.xydesk.my.id/news/covers/changelog-620.jpg',
  'rilis',
  'Haekal Saputra',
  1
)
ON CONFLICT(slug) DO UPDATE SET
  title = excluded.title,
  excerpt = excluded.excerpt,
  content = excluded.content,
  cover = excluded.cover,
  category = excluded.category,
  author = excluded.author,
  published = excluded.published;

-- Changelog rilis 6.2.1.
INSERT INTO posts (slug, title, excerpt, content, cover, category, author, published) VALUES
(
  'changelog-v6-2-1',
  'XyDesk 6.2.1',
  'Tombol bagikan di halaman Berita kini lengkap dengan logo resmi tiap platform, keterangan di Pengaturan ditulis ulang supaya lebih gampang dibaca, dan daftar lisensi bertambah jadi 490 komponen.',
  'Versi 6.2.1 sudah tersedia. Isinya perapian tampilan dan penyegaran tulisan di dalam aplikasi.

TOMBOL BAGIKAN

Artikel di halaman Berita bisa dibagikan lewat WhatsApp, Telegram, X, Facebook, dan LinkedIn, masing-masing dengan logo resminya. Pilihan yang muncul di aplikasi HP sekarang sama dengan yang ada di web. Tautan artikel juga tetap bisa langsung disalin.

TULISAN DI DALAM APLIKASI

Keterangan di halaman Akun, Pengaturan, dan Lisensi ditulis ulang dengan kalimat yang lebih mudah dibaca. Tiap pengaturan sekarang menjelaskan pengaruhnya ke sesi kamu, bukan nama teknisnya.

HALAMAN LISENSI

Daftar komponen pihak ketiga yang dipakai XyDesk kini berisi 490 entri, lengkap dengan nama lisensi dan tautan sumbernya. Jumlahnya mengikuti isi daftar secara otomatis, jadi tidak akan tertinggal saat ada komponen baru.

UNDUHAN

Tombol unduh masih ditutup. XyDesk belum masuk masa uji coba terbuka. Halaman Unduh menampilkan syarat apa saja yang harus beres sebelum dibuka, dan kabar pembukaannya akan diumumkan di halaman Berita.

CATATAN VERSI

Aplikasi Android, host Windows, aplikasi desktop, dan web sama-sama di versi 6.2.1. Tidak ada perubahan pada jalur video maupun suara, jadi kualitas dan kecepatan sesi sama seperti 6.2.0.',
  'https://app.xydesk.my.id/news/covers/changelog-621.jpg',
  'rilis',
  'Haekal Saputra',
  1
)
ON CONFLICT(slug) DO UPDATE SET
  title = excluded.title,
  excerpt = excluded.excerpt,
  content = excluded.content,
  cover = excluded.cover,
  category = excluded.category,
  author = excluded.author,
  published = excluded.published;

INSERT INTO posts (slug, title, excerpt, content, cover, category, author, published) VALUES
(
  'changelog-v6-2-2',
  'XyDesk 6.2.2',
  'Logo kembali ke bentuk tiga dimensi, panel melayang di layar sesi dihapus, angka kualitas sesi kini dibaca langsung dari koneksi, dan tombol suka di berita sudah benar.',
  'Versi 6.2.2 sudah tersedia. Isinya logo baru, layar sesi yang lebih lega, dan beberapa perbaikan yang sudah lama mengganggu.

LOGO

Logo XyDesk kembali ke bentuk tiga dimensi. Ikon aplikasi di Android, ikon di web, favicon, dan gambar pembuka semuanya dibuat ulang dari berkas yang sama, jadi bentuknya konsisten di semua tempat.

LAYAR SESI

Panel yang melayang di tengah atas dan di tengah bawah sudah dihapus. Keduanya menutupi bagian layar PC yang paling sering dilihat. Sekarang semua tombol ada di satu rail tipis di tepi kanan, dan rail itu bisa dilipat jadi tab kecil kalau kamu mau layar penuh tanpa gangguan.

Panel pengaturan sesi juga dirapikan. Bagian atasnya menampilkan nama PC dan status sambungan, dan tabnya jadi empat kolom sama lebar, tidak perlu digeser-geser lagi.

ANGKA YANG BENAR

Panel Gambar dan panel Sesi sekarang menampilkan ukuran gambar, kehalusan, pemakaian data, ping, paket hilang, dan codec yang dipakai. Semua angka itu dibaca langsung dari koneksi dan disegarkan tiap detik. Kalau sesi belum jalan, yang tampil tanda strip.

Kalau PC kamu punya lebih dari satu monitor, pilihan layarnya sekarang ada di dalam panel, lengkap dengan resolusi masing-masing.

TOMBOL SUKA

Tombol suka di halaman berita sebelumnya tidak pernah kelihatan aktif walaupun sudah ditekan, dan tandanya hilang lagi setiap artikel dibuka ulang. Sekarang hatinya terisi, angkanya langsung berubah, dan statusnya tetap tersimpan.

NOTIFIKASI

Notifikasi pembaruan tidak terkirim sejak lama. Penyebabnya perangkat sudah memberi izin di Android tetapi belum terdaftar sebagai penerima, jadi kiriman ditolak sebelum sampai. Mulai versi ini pendaftarannya jalan otomatis begitu izin diberikan. Kalau kamu sengaja mematikan notifikasi lewat Pengaturan, pilihanmu tetap dihormati.

LEGAL

Syarat dan Ketentuan sekarang punya 16 bagian, Kebijakan Privasi 15 bagian. Isinya menjelaskan data apa saja yang disimpan, berapa lama, siapa saja pihak ketiga yang terlibat, dan hak kamu menurut UU Nomor 27 Tahun 2022. Bisa dibaca di aplikasi lewat Akun, Tentang, Legal, atau di halaman Legal di situs.

LEBIH RINGAN

Daftar lisensi yang panjang tidak lagi ikut terunduh saat kamu membuka halaman depan, hanya saat halaman Legal dibuka. Muat pertama situs jadi sekitar 50 kB lebih ringan.

UNDUHAN

Tombol unduh masih ditutup. XyDesk belum masuk masa uji coba terbuka.',
  'https://app.xydesk.my.id/news/covers/changelog-622.jpg',
  'rilis',
  'Haekal Saputra',
  1
)
ON CONFLICT(slug) DO UPDATE SET
  title = excluded.title,
  excerpt = excluded.excerpt,
  content = excluded.content,
  cover = excluded.cover,
  category = excluded.category,
  author = excluded.author,
  published = excluded.published;

-- changelog-v6-6-0: artikel changelog rilis (ditautkan footer web lewat slug deterministik).
INSERT INTO posts (slug, title, excerpt, content, cover, category, author, published) VALUES
(
  'changelog-v6-6-0',
  'Aplikasi Android yang macet di logo akhirnya bisa dibuka',
  'Aplikasi Android yang berhenti di logo kini bisa dibuka lagi. Koneksi jarak jauh dari browser juga tidak lagi diam saat gagal.',
  'Kalau kamu memakai XyDesk di HP Android dan aplikasinya berhenti di logo — tidak
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
jalan seperti biasa.',
  'https://app.xydesk.my.id/news/covers/changelog-660.jpg',
  'rilis',
  'Haekal Saputra',
  1
)
ON CONFLICT(slug) DO UPDATE SET
  title = excluded.title,
  excerpt = excluded.excerpt,
  content = excluded.content,
  cover = excluded.cover,
  category = excluded.category,
  author = excluded.author,
  published = excluded.published;

-- changelog-v6-6-1: artikel changelog rilis (ditautkan footer web lewat slug deterministik).
INSERT INTO posts (slug, title, excerpt, content, cover, category, author, published) VALUES
(
  'changelog-v6-6-1',
  'Layar hitam padahal koneksi tersambung — sekarang gambar muncul walau PC diam',
  'Sesi jarak jauh yang log-nya bilang tersambung tapi layarnya kosong kini menampilkan gambar, walau layar PC yang dikendalikan tidak bergerak sama sekali. Dan aplikasi PC berhenti berputar tanpa kabar saat identitasnya ditolak server.',
  'Kalau kamu pernah menyambungkan XyDesk dari HP atau browser, semuanya tampak
berhasil — status bilang tersambung — tapi yang tampil cuma layar hitam, rilis
ini untuk kamu. Penyebabnya sudah ketemu, dan kali ini bukan dugaan.

### Gambar muncul walau layar PC diam

**Apa yang berubah:** begitu sesi tersambung, gambar langsung muncul — bahkan
kalau layar PC yang dikendalikan sedang tidak bergerak sama sekali (misalnya
kamu meninggalkan desktop terbuka tanpa video yang diputar).

**Kenapa dulu hitam:** ada tiga lapis sebab yang saling mengunci. Pertama,
gambar pembuka — satu-satunya yang membawa "kunci" agar video bisa dimulai —
terkirim sebelum saluran benar-benar siap, jadi terbuang. Kedua, mesin diminta
mengirim kunci baru, tapi permintaan itu hanya dilayani ketika layar sedang
berubah. Ketiga, di Windows layar yang diam memang tidak menghasilkan gambar
baru sama sekali. Ketiganya bertemu jadi lingkaran setan: tidak ada gambar,
tidak ada kunci, decoder di HP tidak pernah bisa mulai, dan layar tetap hitam
walau semua log bilang "tersambung".

**Perbaikannya dua lapis:** kunci pembuka sekarang disimpan dan dikirim ulang
selama beberapa detik pertama sambil menunggu gambar hidup, dan permintaan
kirim-ulang dilayani walau layar PC benar-benar diam.

### Aplikasi PC tidak lagi berputar tanpa kabar

**Apa yang berubah:** kalau identitas aplikasi PC ditolak server, kamu melihat
alasannya apa adanya — misalnya "terlalu banyak percobaan, tunggu beberapa
menit" — lengkap dengan sisa waktu tunggunya. Aplikasi menunggu selama yang
diminta, berhenti total kalau jawabannya permanen, dan tombol mulai ulang
selalu tersedia untuk menghapus blokade.

**Kenapa kami mengubahnya:** dulu aplikasi menyamakan "identitas ditolak"
dengan "mesin crash", jadi ia mencoba lagi setiap beberapa detik tanpa henti —
padahal setiap percobaan membuat server semakin ketat mengunci. Yang kamu
lihat hanya "Engine belum siap" tanpa penjelasan, sementara kuncinya makin
lama. Sekarang kegagalan identitas diperlakukan sebagai kegagalan identitas:
ada alasannya, ada tunggunya, ada ujungnya.

Semua ini ada di versi 6.6.1 (build 34) untuk Android, web, dan PC.',
  'https://app.xydesk.my.id/news/covers/changelog-661.jpg',
  'rilis',
  'Haekal Saputra',
  1
)
ON CONFLICT(slug) DO UPDATE SET
  title = excluded.title,
  excerpt = excluded.excerpt,
  content = excluded.content,
  cover = excluded.cover,
  category = excluded.category,
  author = excluded.author,
  published = excluded.published;

-- changelog-v6-7-0: artikel changelog rilis (ditautkan footer web lewat slug deterministik).
INSERT INTO posts (slug, title, excerpt, content, cover, category, author, published) VALUES
(
  'changelog-v6-7-0',
  'Layar hitam di laptop dua GPU tuntas — dan suara PC akhirnya terdengar',
  'Keluhan yang paling sering masuk ditutup dari akarnya: layar hitam di laptop dengan dua kartu grafis, dan suara PC yang tidak pernah sampai ke HP. Plus login Google di aplikasi PC, izin mikrofon yang kini benar-benar ditanya, dan kontrol yang lebih responsif.',
  'Ini rilis besar. Dua keluhan yang paling sering masuk — layar hitam di laptop
yang punya dua kartu grafis, dan suara PC yang tidak pernah terdengar di HP —
ditutup dari akarnya, bukan diakali. Sisanya: login di aplikasi PC, izin yang
akhirnya ditanya, rem pairing yang jujur, kontrol yang lebih responsif, dan
rapi-rapi tampilan.

### Layar hitam di laptop dua GPU tuntas

**Apa yang berubah:** laptop dengan kartu grafis ganda (bawaan prosesor plus
kartu tambahan, misalnya Intel + NVIDIA) kini menampilkan gambar seperti
PC biasa. Tidak ada lagi sesi "tersambung tapi hitam" di mesin hybrid.

**Kenapa dulu hitam:** jalur penangkap layar yang lama mengambil gambar lewat
sistem komposisi Windows, yang terikat pada kartu grafis tempat aplikasi
berjalan. Di laptop dua GPU, aplikasi dan layar sering dilayani kartu yang
berbeda — hasilnya gambar kosong. Sekarang mesin menangkap tampilan langsung
dari kartu grafis yang menyalakan monitor. Dan karena tidak ada satu pun
jalur yang benar di semua mesin, kami membuat rantai: kalau jalur utama gagal,
otomatis turun ke jalur kedua, lalu ketiga. Penangkapan juga baru dimulai
setelah koneksi benar-benar terbentuk — tidak ada kerja sia-sia sebelum ada
yang menonton. Efek samping yang menyenangkan: bingkai kuning yang kadang
muncul di tepi layar (penanda dari jalur lama) ikut hilang.

### Suara dari PC akhirnya terdengar

**Apa yang berubah:** suara PC terdengar di HP dan browser, di perangkat audio
apa pun.

**Kenapa dulu mati:** Windows hanya menerima perekaman suara bersama dalam
satu format asli perangkat — dan tiap perangkat bisa beda: ada yang 16-bit,
24-bit, format pecahan, 44.100 atau 48.000 sampel per detik, stereo atau
lebih. Mesin kami dulu memaksa satu format untuk semua; begitu perangkat
menolak, seluruh sesi audio mati diam-diam tanpa pesan. Sekarang mesin
mengikuti format asli perangkat lalu mengonversinya sendiri — berapa pun
bitnya, berapa pun kanal dan laju contohnya. Suara yang menolak format
seragam akhirnya lewat.

### Izin mikrofon dan kamera kini benar-benar ditanya

**Apa yang berubah:** di Android, permintaan izin mikrofon muncul saat kamu
menyalakan mik di dalam sesi, dan permintaan izin kamera muncul saat pemindai
QR dibuka. Kalau izin pernah ditolak permanen, ada penjelasan dan tombol
langsung ke pengaturan aplikasi — bukan layar gelap tanpa sebab.

**Kenapa kami mengubahnya:** izin yang cuma didaftarkan di manifest tidak
pernah memunculkan dialog; Android hanya bertanya kalau aplikasinya benar-benar
meminta di saat fitur dipakai. Dulu tidak ada satu pun permintaan itu, jadi
wajar dialognya tidak pernah terlihat.

### Login Google dan email di aplikasi PC

**Apa yang berubah:** aplikasi PC kini punya pintu masuk yang sama dengan web:
masuk lewat akun Google atau lewat kode yang dikirim ke email.

**Kenapa:** identitas di aplikasi PC tadinya setengah jalan — sesi ada, tapi
tidak terikat ke akun. Sekarang perangkat PC-mu tercatat di akun yang sama,
dari aplikasi mana pun kamu masuk.

### Ditolak server? Sekarang ada alasan dan hitung mundurnya

**Apa yang berubah:** kalau pairing dikunci sementara karena terlalu banyak
percobaan gagal, web dan HP menampilkan pesannya: "Server mengunci pairing
sementara — coba lagi dalam N detik."

**Kenapa kami mengubahnya:** server sebenarnya sudah mengirim kode kunci itu,
tapi kedua klien menunggu kode lain yang tidak pernah dikirim — jadi koneksi
kedua yang ditolak cuma menggantung tanpa pesan. Kabelnya disambungkan ke kode
yang benar.

### Kontrol lebih responsif saat jaringan tersendat

**Apa yang berubah:** ketika jaringan tersendat sebentar dan masukan menumpuk,
kursor tidak lagi "berenang" menyusuri posisi-posisi lama sebelum sampai ke
posisi terakhirmu. Klik, tombol, dan gulir tidak ada yang hilang.

**Kenapa:** posisi kursor adalah keadaan — hanya posisi terakhir yang bermakna,
posisi basi di antrean boleh dibuang. Tapi klik dan ketikan adalah kejadian —
membuang satu saja berarti kehilangan aksi. Antrean kini dibersihkan dengan
aturan itu: keadaan basi dibuang, kejadian utuh.

### Layar penuh di web: tombol yang bisa keluar-masuk

**Apa yang berubah:** tombol layar penuh di sesi web kini juga berfungsi untuk
keluar, statusnya ikut berubah kalau kamu keluar lewat Esc, dan di iPhone/iPad
ia memakai jalur layar penuh khusus video milik Safari.

### Spesifikasi perangkat yang jujur

**Apa yang berubah:** detail perangkat di HP menampilkan spesifikasi PC yang
sebenarnya — prosesor, kartu grafis, memori, sistem operasi — yang dibaca
langsung dari mesinnya.

**Kenapa:** sebelumnya bagian itu diisi teks perkiraan. Spesifikasi yang
dikarang lebih buruk daripada tidak ada: ia membuat laporan masalah tidak bisa
dipercaya.

### Tampilan aplikasi PC dirapikan

Sudut jendela mengikuti gaya Windows 11, daftar perangkat tampil di bawah ID
dan password, pengubahan password cukup lewat popover di tempat, dan seluruh
logo — di semua platform, termasuk ikon adaptive Android — dikembalikan ke
versi aslinya yang terang. Sempat ada cacat yang membuat logo ter-flatten jadi
hitam; aturannya sekarang tegas: logo tidak pernah dihitamkan.

Semua ini ada di versi 6.7.0 (build 35) untuk Android, web, dan PC.',
  'https://app.xydesk.my.id/news/covers/changelog-670.jpg',
  'rilis',
  'Haekal Saputra',
  1
)
ON CONFLICT(slug) DO UPDATE SET
  title = excluded.title,
  excerpt = excluded.excerpt,
  content = excluded.content,
  cover = excluded.cover,
  category = excluded.category,
  author = excluded.author,
  published = excluded.published;

-- Alias slug untuk artikel changelog terdahulu agar tautan footer/About tidak 404
INSERT OR IGNORE INTO post_aliases (alias, slug) VALUES
  ('changelog-v6-5-4', 'rilis-654'),
  ('changelog-v6-5-3', 'rilis-653'),
  ('changelog-v6-5-2', 'p-8f5aa26aa3bc'),
  ('changelog-v6-4-0', 'p-66a4edde0222'),
  ('changelog-v6-1-0', 'p-d5b4512f7d17'),
  ('changelog-v6-0-0', 'p-d5b4512f7d17');
