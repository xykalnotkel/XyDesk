import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_version.dart';
import '../../core/l10n_bridge.dart';
import '../../core/tokens.dart';
import '../../core/license_stats.dart';

enum LegalDoc { terms, privacy, licenses }

/// Halaman dokumen legal.
///
/// Isi ditulis langsung di aplikasi (bukan WebView) supaya tetap bisa
/// dibaca tanpa internet dan tampilannya konsisten dengan tema.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.doc});

  final LegalDoc doc;

  static void open(BuildContext context, LegalDoc doc) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LegalPage(doc: doc)));
  }

  String _title(BuildContext c) => switch (doc) {
    LegalDoc.terms => c.tr('legal_terms'),
    LegalDoc.privacy => c.tr('legal_privacy'),
    LegalDoc.licenses => c.tr('legal_licenses'),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(_title(context)),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.textMid),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.md,
          Gap.screen,
          Gap.h40,
        ),
        children: [
          Text(
            'Berlaku sejak 7 Agustus 2026 · Versi 1.0',
            style: TextStyle(fontSize: 11, color: c.textLow),
          ),
          const SizedBox(height: Gap.xl),
          ...switch (doc) {
            LegalDoc.terms => _terms(context),
            LegalDoc.privacy => _privacy(context),
            LegalDoc.licenses => _licenses(context),
          },
        ],
      ),
    );
  }

  List<Widget> _terms(BuildContext c) => [
    _para(
      c,
      'Berlaku sejak 1 September 2026. XyDesk dibuat oleh XySpace Tech, '
      'Indonesia. Dokumen ini adalah perjanjian antara kamu sebagai pemakai '
      'dan kami sebagai penyedia layanan.',
    ),
    _sec(c, '1. Penerimaan'),
    _para(
      c,
      'Dengan memasang atau memakai XyDesk, kamu setuju terikat pada '
      'ketentuan ini. Bila tidak setuju, jangan memakai aplikasi ini.',
    ),
    _sec(c, '2. Status layanan saat ini'),
    _para(
      c,
      'XyDesk masih dalam tahap pra-beta. Beberapa fitur belum jalan, '
      'unduhan publik masih ditutup, dan sesi bisa putus atau berubah '
      'perilakunya tanpa pemberitahuan. Jangan memakai XyDesk sebagai '
      'satu-satunya jalan masuk ke komputer yang kamu butuhkan untuk '
      'pekerjaan penting.',
    ),
    _sec(c, '3. Siapa yang boleh memakai'),
    _para(
      c,
      'Kamu harus berumur minimal 13 tahun. Kalau umurmu di bawah 18 tahun, '
      'pemakaian harus dengan sepengetahuan orang tua atau wali. Kalau kamu '
      'memakai XyDesk atas nama perusahaan, kamu menyatakan punya wewenang '
      'untuk menyetujui ketentuan ini.',
    ),
    _sec(c, '4. Penggunaan yang diizinkan'),
    _para(
      c,
      'XyDesk hanya boleh dipakai untuk mengakses komputer milikmu sendiri, '
      'atau komputer yang pemiliknya sudah memberi izin secara sadar dan '
      'sukarela.',
    ),
    _bullets(c, [
      'Dilarang memakai XyDesk untuk mengakses perangkat tanpa izin.',
      'Dilarang memakai XyDesk dalam penipuan, termasuk berpura-pura '
          'sebagai petugas bank, layanan pelanggan, atau instansi resmi.',
      'Dilarang merekayasa balik, membongkar, atau menyalahgunakan '
          'infrastruktur layanan.',
      'Dilarang memakai XyDesk untuk menyebarkan program berbahaya, '
          'menambang kripto di komputer orang lain, atau mengirim spam.',
      'Dilarang menjual ulang akses XyDesk atau menyewakannya sebagai '
          'layananmu sendiri tanpa perjanjian tertulis dengan kami.',
    ]),
    _warnBox(
      c,
      'Peringatan penipuan: layanan resmi TIDAK PERNAH meminta kamu '
      'memasang aplikasi remote desktop lalu menyebutkan ID dan kata '
      'sandi. Jika ada yang meminta demikian, itu penipuan.',
    ),
    _sec(c, '5. Akun dan keamanan'),
    _para(
      c,
      'Kamu bertanggung jawab menjaga kerahasiaan kredensial akun, kode '
      'masuk sekali pakai, dan password pairing perangkat. Beritahu kami '
      'segera bila mencurigai ada akses tanpa izin. Aktivitas yang terjadi '
      'lewat akunmu dianggap dilakukan olehmu.',
    ),
    _sec(c, '6. Hak atas perangkat lunak'),
    _para(
      c,
      'XyDesk diberikan sebagai lisensi pakai, bukan dijual. Kami memberi '
      'kamu izin yang tidak eksklusif, tidak bisa dipindahtangankan, dan '
      'bisa dicabut, untuk memasang serta memakai aplikasi ini di perangkat '
      'yang kamu kuasai. Semua hak yang tidak disebut di sini tetap milik '
      'XySpace Tech.',
    ),
    _sec(c, '7. Data dan konten kamu'),
    _para(
      c,
      'Isi layar, berkas, dan ketikan selama sesi tetap milikmu. Kami tidak '
      'mengambil hak apa pun atasnya. Untuk komentar di halaman Berita, kamu '
      'memberi kami izin menampilkannya di aplikasi dan situs XyDesk, dan '
      'kami boleh menghapus komentar yang melanggar ketentuan ini.',
    ),
    _sec(c, '8. Layanan pihak ketiga'),
    _para(
      c,
      'XyDesk memakai layanan pihak lain untuk masuk akun, penyimpanan data, '
      'jaringan, dan notifikasi. Rinciannya ada di Kebijakan Privasi. '
      'Gangguan pada layanan itu bisa ikut mengganggu XyDesk, dan bagian '
      'tersebut berada di luar kendali kami.',
    ),
    _sec(c, '9. Biaya'),
    _para(
      c,
      'Saat ini XyDesk gratis dan belum ada pembayaran apa pun di dalam '
      'aplikasi. Kalau nanti ada paket berbayar, harganya akan diumumkan '
      'lebih dulu dan fitur yang sudah kamu pakai gratis tidak akan '
      'tiba-tiba dikunci tanpa pemberitahuan.',
    ),
    _sec(c, '10. Penangguhan dan penghentian'),
    _para(
      c,
      'Kami bisa menangguhkan atau menutup akun yang dipakai untuk melanggar '
      'ketentuan ini, membahayakan pengguna lain, atau merusak layanan. '
      'Kalau memungkinkan, kami akan memberi tahu dulu. Kamu juga bisa '
      'berhenti kapan saja dengan menghapus akun lewat halaman Akun.',
    ),
    _sec(c, '11. Ketersediaan layanan'),
    _para(
      c,
      'Layanan disediakan sebagaimana adanya. Kami berusaha menjaga '
      'ketersediaan, tetapi tidak menjanjikan bebas gangguan, terutama pada '
      'jalur relay yang bergantung pada jaringan pihak ketiga.',
    ),
    _sec(c, '12. Batasan tanggung jawab'),
    _para(
      c,
      'Sejauh diizinkan hukum, kami tidak bertanggung jawab atas kerugian '
      'tidak langsung, kehilangan data, atau kehilangan keuntungan yang '
      'timbul dari pemakaian aplikasi. Selama XyDesk masih gratis, total '
      'tanggung jawab kami dibatasi pada penggantian layanan itu sendiri.',
    ),
    _sec(c, '13. Ganti rugi'),
    _para(
      c,
      'Kalau pemakaianmu melanggar ketentuan ini dan menimbulkan tuntutan '
      'dari pihak lain, kamu setuju menanggung akibatnya, termasuk biaya '
      'yang wajar untuk menanganinya.',
    ),
    _sec(c, '14. Hukum yang berlaku'),
    _para(
      c,
      'Ketentuan ini tunduk pada hukum Republik Indonesia. Kalau ada '
      'perselisihan, kita selesaikan dulu secara musyawarah lewat kontak di '
      'bawah. Bila tidak selesai dalam 30 hari, perkara diselesaikan di '
      'pengadilan yang berwenang di Indonesia.',
    ),
    _sec(c, '15. Perubahan'),
    _para(
      c,
      'Ketentuan dapat berubah. Perubahan penting akan diberitahukan di '
      'dalam aplikasi minimal 14 hari sebelum berlaku, dan versi lama tetap '
      'bisa dibaca lewat halaman Berita.',
    ),
    _sec(c, '16. Kontak'),
    _para(c, 'Pertanyaan soal ketentuan ini: legal@xydesk.app'),
  ];

  List<Widget> _privacy(BuildContext c) => [
    _para(
      c,
      'Berlaku sejak 1 September 2026. Pengendali data: XySpace Tech, '
      'Indonesia. Dokumen ini menjelaskan data apa yang kami pegang, kenapa, '
      'dan berapa lama.',
    ),
    _sec(c, '1. Ringkasan'),
    _para(
      c,
      'XyDesk dirancang supaya kami tidak bisa melihat isi layarmu. Media '
      'dan input dienkripsi ujung ke ujung dengan DTLS-SRTP; server kami '
      'hanya mempertemukan dua perangkat dan, kalau jaringanmu tidak bisa '
      'langsung, meneruskan paket yang sudah terenkripsi.',
    ),
    _sec(c, '2. Data yang kami simpan'),
    _bullets(c, [
      'Alamat email, kalau kamu membuat akun.',
      'Nama dan foto profil dari Google, kalau kamu masuk lewat Google.',
      'ID perangkat, nama perangkat, dan sistem operasinya.',
      'Metadata sesi: waktu mulai dan selesai, durasi, jalur langsung atau '
          'relay, rata-rata bitrate, dan rata-rata ping.',
      'Token notifikasi dari OneSignal, kalau kamu mengizinkan notifikasi.',
      'Sidik jari acak perangkat untuk suka dan komentar di halaman Berita. '
          'Angka acak ini tidak terhubung ke identitasmu.',
      'Log server standar: alamat IP, waktu akses, dan jenis permintaan.',
      'Catatan diagnostik, hanya kalau kamu mengirimkannya sendiri.',
    ]),
    _sec(c, '3. Yang tidak pernah kami simpan'),
    _bullets(c, [
      'Isi layar atau tangkapan layar.',
      'Ketikan keyboard maupun gerakan mouse.',
      'Audio dari mikrofon atau dari PC.',
      'Berkas yang kamu transfer dan isi papan klip.',
      'Password pairing perangkat. Yang tersimpan hanya di PC kamu sendiri.',
    ]),
    _sec(c, '4. Kenapa data itu kami pakai'),
    _bullets(c, [
      'Email dan akun: supaya kamu bisa masuk dan perangkatmu dikenali.',
      'Metadata sesi: mencari sebab sesi putus dan memperbaiki kualitas.',
      'Token notifikasi: memberi tahu ada pembaruan aplikasi.',
      'Log server: menahan penyalahgunaan dan serangan.',
    ]),
    _para(
      c,
      'Kami tidak menjual data. Tidak ada iklan pihak ketiga di dalam '
      'aplikasi, dan tidak ada pelacak iklan yang kami pasang.',
    ),
    _sec(c, '5. Dasar pemrosesan'),
    _para(
      c,
      'Kami memproses data berdasarkan persetujuanmu saat membuat akun atau '
      'mengizinkan sebuah fitur, dan berdasarkan kebutuhan menjalankan '
      'layanan yang kamu minta. Persetujuan bisa kamu tarik kapan saja '
      'dengan mematikan fitur terkait atau menghapus akun.',
    ),
    _sec(c, '6. Layanan pihak ketiga'),
    _bullets(c, [
      'Supabase: penyimpanan akun dan basis data. Server di luar Indonesia.',
      'Cloudflare: jaringan, situs, halaman berita, dan server signaling.',
      'OneSignal: pengiriman notifikasi ke perangkat.',
      'Google Sign-In: pilihan masuk dengan akun Google.',
      'GitHub: tempat berkas pemasangan aplikasi diunduh.',
    ]),
    _para(
      c,
      'Masing-masing punya kebijakan privasinya sendiri. Karena penyedia ini '
      'beroperasi lintas negara, datamu bisa diproses di luar Indonesia.',
    ),
    _sec(c, '7. Izin perangkat'),
    _para(
      c,
      'Semua izin diminta hanya saat fiturnya dipakai, dan semuanya boleh '
      'ditolak. Menolak izin hanya mematikan fitur terkait, bukan seluruh '
      'aplikasi.',
    ),
    _bullets(c, [
      'Mikrofon: mengirim suaramu ke PC saat sesi.',
      'Kamera: hanya untuk memindai kode QR koneksi.',
      'Notifikasi: kabar pembaruan dan status sesi.',
      'Penyimpanan: menyimpan berkas hasil transfer ke folder XyDesk.',
    ]),
    _sec(c, '8. Penyimpanan di perangkatmu'),
    _para(
      c,
      'Pengaturan, daftar perangkat, riwayat sesi, dan profil kontrol '
      'tersimpan di perangkatmu sendiri, bukan di server kami. Menghapus '
      'aplikasi ikut menghapusnya.',
    ),
    _sec(c, '9. Keamanan'),
    _para(
      c,
      'Sambungan ke server kami memakai HTTPS dan WSS. Media sesi memakai '
      'DTLS-SRTP. Kode masuk sekali pakai disimpan sebagai hash, punya batas '
      'waktu, dan batas percobaan. Tidak ada sistem yang sempurna, jadi '
      'kalau terjadi kebocoran yang berisiko buat kamu, kami akan '
      'memberitahu lewat aplikasi dan email dalam 3 hari kerja.',
    ),
    _sec(c, '10. Berapa lama disimpan'),
    _bullets(c, [
      'Metadata sesi: 90 hari.',
      'Log server: 30 hari.',
      'Catatan audit keamanan: 1 tahun.',
      'Data akun: selama akunmu aktif.',
      'Setelah akun dihapus: seluruh data terkait hilang dalam 30 hari.',
    ]),
    _sec(c, '11. Hak kamu'),
    _para(
      c,
      'Sesuai UU Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi, kamu '
      'berhak melihat, memperbaiki, mengunduh, membatasi, dan menghapus '
      'datamu, serta menarik persetujuan. Kirim permintaan ke '
      'privacy@xydesk.app; kami jawab paling lama 14 hari kerja.',
    ),
    _sec(c, '12. Anak-anak'),
    _para(
      c,
      'XyDesk tidak ditujukan untuk anak di bawah 13 tahun. Kalau kami tahu '
      'ada akun anak di bawah umur itu, akunnya kami hapus.',
    ),
    _sec(c, '13. Situs web'),
    _para(
      c,
      'Situs XyDesk tidak memakai cookie iklan. Yang disimpan di browser '
      'hanya preferensi tampilan dan sidik jari acak untuk suka dan komentar '
      'berita.',
    ),
    _sec(c, '14. Perubahan'),
    _para(
      c,
      'Kalau kebijakan ini berubah secara berarti, kami umumkan di halaman '
      'Berita dan di dalam aplikasi sebelum berlaku.',
    ),
    _sec(c, '15. Kontak'),
    _para(
      c,
      'Pertanyaan atau permintaan soal data pribadi: privacy@xydesk.app. '
      'Urusan hukum lainnya: legal@xydesk.app.',
    ),
  ];

  /// Lisensi pihak ketiga.
  ///
  /// Sebelumnya bagian ini memuat 18 komponen yang diketik tangan. Jumlah
  /// sebenarnya ada ratusan — lihat [LicenseStats], yang dibangkitkan dari
  /// lockfile oleh `tool/gen-licenses.mjs`. Daftar tangan tidak pernah bisa
  /// mengejarnya, dan daftar lisensi yang tidak lengkap adalah masalah
  /// hukum, bukan sekadar dokumentasi yang kurang rapi.
  ///
  /// Karena itu halaman ini menampilkan komponen inti saja, lalu menyerahkan
  /// daftar penuhnya ke [showLicensePage] — registry lisensi bawaan Flutter
  /// yang membaca teks LICENSE dari BINER YANG SEDANG BERJALAN. Isinya
  /// mustahil ketinggalan zaman: kalau sebuah paket ikut ter-bundle, teks
  /// lisensinya pasti ikut tampil.
  List<Widget> _licenses(BuildContext c) => [
    _para(
      c,
      'XyDesk adalah perangkat lunak proprietary (bukan sumber terbuka): '
      'bebas dipakai, tetapi dilarang meng-clone, menyalin, merekayasa '
      'balik, atau mendistribusikan ulang kode sumbernya tanpa izin '
      'tertulis dari XySpace Tech. Seluruh UI/UX dirancang sendiri oleh tim '
      'XyDesk.',
    ),
    _para(
      c,
      'XyDesk dibangun di atas ${LicenseStats.total} komponen buatan orang '
      'lain: ${LicenseStats.dart} paket Dart/Flutter, ${LicenseStats.rust} '
      'paket Rust di aplikasi PC, ${LicenseStats.npm} paket npm untuk web, '
      'dan ${LicenseStats.assets} aset serta layanan. Semuanya kami daftar, '
      'tidak ada yang kami sembunyikan.',
    ),
    const SizedBox(height: Gap.md),
    _sec(c, 'Komponen inti'),
    for (final l in const [
      ('Flutter & Dart SDK', 'BSD-3-Clause', 'Google'),
      ('libwebrtc', 'BSD-3-Clause', 'Google — jalur video dan suara'),
      ('libopus 1.5.2', 'BSD-3-Clause', 'Xiph.Org — pemroses suara'),
      ('OpenH264', 'BSD-2-Clause', 'Cisco — pemroses video'),
      (
        'windows-rs / windows-capture',
        'MIT atau Apache-2.0',
        'Microsoft & kontributor',
      ),
      ('Inter', 'SIL OFL 1.1', 'Rasmus Andersson — font'),
      ('Lucide Icons', 'ISC', 'Kontributor Lucide'),
      (
        'NVIDIA Video Codec SDK',
        'Lisensi SDK NVIDIA',
        'Dipakai kalau PC punya GPU NVIDIA',
      ),
      ('OneSignal SDK', 'Ketentuan OneSignal', 'Pemberitahuan'),
      (
        'Cloudflare Workers, D1, TURN',
        'Ketentuan Cloudflare',
        'Penghubung sesi & berita',
      ),
    ])
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.$1,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.c.textHi,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${l.$2} · ${l.$3}',
              style: TextStyle(fontSize: 11.5, color: c.c.textLow),
            ),
          ],
        ),
      ),
    const SizedBox(height: Gap.md),
    _LicenseRegistryButton(),
    const SizedBox(height: Gap.md),
    _para(
      c,
      'Tombol di atas membuka teks lisensi lengkap tiap paket, dibaca '
      'langsung dari aplikasi yang sedang kamu pakai — jadi isinya selalu '
      'sesuai versi yang terpasang. Daftar lengkap untuk semua platform ada '
      'di situs XyDesk, halaman Legal.',
    ),
  ];
}

/// Tombol menuju registry lisensi bawaan Flutter.
///
/// Dipisah jadi widget sendiri supaya bisa memakai [showLicensePage] dengan
/// [BuildContext] yang benar tanpa mengubah [LegalPage] jadi stateful.
class _LicenseRegistryButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.input,
      borderRadius: BorderRadius.circular(R.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(R.lg),
        onTap: () => showLicensePage(
          context: context,
          applicationName: 'XyDesk',
          applicationVersion: AppVersion.full,
          applicationLegalese: '© 2026 XySpace Tech. Proprietary.',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Icon(LucideIcons.scrollText, size: 17, color: c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Lisensi pihak ketiga lengkap',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
            ],
          ),
        ),
      ),
    );
  }
}

// ── potongan kecil ──
Widget _sec(BuildContext c, String t) => Padding(
  padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.sm),
  child: Text(
    t,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: c.c.textHi,
    ),
  ),
);

/// Kata/frasa penting yang disorot (warna aksen, sedikit tebal) di teks
/// legal. Ini murni penyajian — tidak mengubah makna atau isi.
const _importantTerms = <String>[
  'XySpace Tech',
  'Republik Indonesia',
  'Pelindungan Data Pribadi',
  'DTLS-SRTP',
  'HTTPS dan WSS',
  'privacy@xydesk.app',
  'legal@xydesk.app',
  'TIDAK PERNAH',
  '13 tahun',
  'pra-beta',
];

/// Render satu paragraf legal dengan penyorotan kata penting + email/URL
/// yang bisa diketuk. Teks asli tidak berubah; hanya presentasi yang
/// diperkaya (warna/tebal/tautkan).
Widget _para(BuildContext c, String t) => Padding(
  padding: const EdgeInsets.only(bottom: Gap.sm),
  child: _rich(c, t, fontSize: 13, height: 1.65),
);

/// Abstraksi teks kaya paragraf legal: pecah string jadi bagian biasa,
/// email, URL, dan frasa penting — masing-masing diberi gaya sesuai.
Widget _rich(
  BuildContext c,
  String text, {
  required double fontSize,
  required double height,
}) {
  final base = TextStyle(
    fontSize: fontSize,
    height: height,
    color: c.c.textMid,
  );
  final accent = TextStyle(
    fontSize: fontSize,
    height: height,
    color: c.c.accent,
    fontWeight: FontWeight.w600,
  );
  final strong = TextStyle(
    fontSize: fontSize,
    height: height,
    color: c.c.textHi,
    fontWeight: FontWeight.w600,
  );

  final spans = <InlineSpan>[];
  final emailRe = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
  final urlRe = RegExp(r'https?://[^\s)]+');

  // Gabungkan semua token penting ke satu regex pencocok, urutan panjang
  // dulu supaya frasa dua kata tidak kalah oleh pemicu yang lebih pendek.
  final terms = [..._importantTerms]
    ..sort((a, b) => b.length.compareTo(a.length));
  final termRe = RegExp(terms.map(RegExp.escape).join('|'));
  final tokenRe = RegExp(
    '(${emailRe.pattern})|(${urlRe.pattern})|(${termRe.pattern})',
  );

  var idx = 0;
  for (final m in tokenRe.allMatches(text)) {
    if (m.start > idx) {
      spans.add(TextSpan(text: text.substring(idx, m.start)));
    }
    final token = m.group(0)!;
    if (emailRe.hasMatch(token)) {
      spans.add(
        TextSpan(
          text: token,
          style: accent.copyWith(decoration: TextDecoration.underline),
          recognizer: (TapGestureRecognizer()
            ..onTap = () => launchUrl(
              Uri.parse('mailto:$token'),
              mode: LaunchMode.externalApplication,
            )),
        ),
      );
    } else if (urlRe.hasMatch(token)) {
      spans.add(
        TextSpan(
          text: token,
          style: accent.copyWith(decoration: TextDecoration.underline),
          recognizer: (TapGestureRecognizer()
            ..onTap = () => launchUrl(
              Uri.parse(token),
              mode: LaunchMode.externalApplication,
            )),
        ),
      );
    } else {
      spans.add(TextSpan(text: token, style: strong));
    }
    idx = m.end;
  }
  if (idx < text.length) {
    spans.add(TextSpan(text: text.substring(idx)));
  }

  return Text.rich(TextSpan(style: base, children: spans));
}

Widget _bullets(BuildContext c, List<String> items) => Padding(
  padding: const EdgeInsets.only(top: 4, bottom: Gap.sm),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final i in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 10),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.c.textLow,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(child: _rich(c, i, fontSize: 13, height: 1.6)),
            ],
          ),
        ),
    ],
  ),
);

Widget _warnBox(BuildContext c, String t) => Container(
  margin: const EdgeInsets.symmetric(vertical: Gap.md),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: AppColors.warning.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(R.lg),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.warning),
      const SizedBox(width: Gap.md),
      Expanded(child: _rich(c, t, fontSize: 12.5, height: 1.6)),
    ],
  ),
);
