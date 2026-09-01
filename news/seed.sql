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
  'https://app.xystudio.my.id/news/covers/desktop-shell.jpg',
  'rilis',
  'Tim XyDesk',
  1
),
(
  'nvenc-encode-hardware-jalur-produksi',
  'NVENC aktif: encode hardware masuk jalur produksi',
  'Encoder H264 hardware NVIDIA kini dipakai otomatis saat GPU tersedia, dengan fallback openh264 bila tidak ada. Angka benchmark membuktikan kenapa ini wajib: openh264 CPU tidak tembus target encode di bawah 10 ms.',
  'Benchmark internal sudah jujur dari awal: openh264 (software) butuh sekitar 30 ms untuk 640x360. Untuk target roadmap — encode di bawah 10 ms di 1080p60 — angka itu tidak mungkin. Hardware encode (NVENC/AMF/QuickSync) adalah prasyarat, bukan opsi.

Implementasi NVENC di host kini terkabel ke jalur capture: frame pertama menentukan resolusi, NVENC diinisialisasi bila dimensi genap dan driver NVIDIA tersedia, dan konversi RGBA ke NV12 (BT.601 full-range) dilakukan sebelum encode. Kalau NVENC gagal — tidak ada GPU, driver lama — jalur fallback openh264 tetap berjalan tanpa crash.

Panel host menampilkan status encoder langsung: badge NVENC menyala kalau hardware aktif. Yang belum berubah: angka glass-to-glass di jaringan nyata masih harus dibuktikan di lab. Targetnya tetap 40 ms di LAN, dan kami tidak akan klaim "cocok untuk game" sebelum fotonya ada.',
  'https://app.xystudio.my.id/news/covers/nvenc.jpg',
  'teknik',
  'Tim XyDesk',
  1
),
(
  'mengukur-latency-cara-jujur',
  'Mengukur latency seperti orang jujur',
  'Protokol pengukuran XyDesk: timestamp frame di host, dibandingkan di client, lalu foto kedua layar berjejer. Bukan angka dari datasheet, bukan perasaan "terasa cepat".',
  'Klaim latency remote desktop biasanya dihias: diukur di kondisi ideal, tanpa menyebut resolusi, atau pakai angka encode saja. Untuk XyDesk, aturannya satu: bukti dulu, baru poles.

Protokol kami (docs/LATENCY.md): host menampilkan jam milidetik di layar, client memotret layar host dan layar HP berjejer, lalu selisih jam di kedua frame dibaca langsung. Sepuluh pasang foto, ambil median. Kalau ada encode hardware, decoder hardware, dan jaringan LAN yang sehat, angka di bawah 40 ms harusnya tercapai — tapi sampai fotonya ada, itu tetap dugaan.

Status hari ini: loop capture-encode-RTP-terima sudah terbukti di test loopback otomatis, benchmark encode sudah punya angka (30 ms openh264 di 640x360), dan angka end-to-end masih kosong. Begitu lab Windows jalan, hasilnya akan dipublikasikan di sini — apapun hasilnya.',
  'https://app.xystudio.my.id/news/covers/latency.jpg',
  'teknik',
  'Tim XyDesk',
  1
),
(
  'xydesk-25-monokrom-dan-lisensi-terbuka',
  'XyDesk 2.5 — monokrom, berita di mana-mana, lisensi terbuka',
  'Tampilan baru dominan hitam-putih dengan aksen ungu, berita yang sama di Android/Desktop/Web, logo X tanpa glow, dan kode sumber berlisensi Apache 2.0.',
  'Versi 2.5 adalah rilis "beres-beres": tampilan, konsistensi, dan keterbukaan.\n\nTampilan. Semua platform kini memakai bahasa visual yang sama — dominan hitam-putih dengan ungu hanya sebagai aksen kecil. Logo X yang selama ini dipakai di sampul berita menjadi logo resmi, tanpa glow dan tanpa bayangan. Splash Android mengikuti tema terang, ikon navigasi mengikuti warna tema.\n\nBerita. Satu umpan berita yang sama tampil di Android, Desktop, dan Web — lengkap dengan like, komentar, dan bagikan. Di web, setiap berita punya meta OpenGraph sendiri sehingga tautan yang dibagikan ke WhatsApp atau X tampil dengan judul, ringkasan, dan sampul yang benar. Perbaikan penting: sebelumnya berita di web gagal dimuat ("Failed to fetch") karena aturan Content-Security-Policy belum mengizinkan domain berita — sekarang sudah diizinkan dan diverifikasi live.\n\nLisensi. Kode sumber XyDesk kini berlisensi Apache 2.0. Daftar lisensi perangkat lunak pihak ketiga (Flutter, Electron, Lucide, Inter, dan lain-lain) bisa dibaca di halaman Legal di semua platform.\n\nVersi: Android 2.5.0 (build 19), Web 2.5.0, Desktop 2.5.0. Setiap rilis berikutnya akan selalu punya catatan seperti ini di Berita.',
  'https://app.xystudio.my.id/news/covers/v25.jpg',
  'rilis',
  'Tim XyDesk',
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
  'https://app.xystudio.my.id/news/covers/changelog-620.jpg',
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
  'https://app.xystudio.my.id/news/covers/changelog-621.jpg',
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
