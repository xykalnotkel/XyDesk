-- Seed berita XyDesk (konten asli, bukan dummy — ini yang tampil di Web/Android/Desktop).

INSERT OR IGNORE INTO posts (slug, title, excerpt, content, cover, category, author, published) VALUES
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
);
