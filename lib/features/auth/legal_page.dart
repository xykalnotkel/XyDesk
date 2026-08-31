import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_version.dart';
import '../../core/l10n_bridge.dart';
import '../../core/tokens.dart';

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
    _sec(c, '1. Penerimaan'),
    _para(
      c,
      'Dengan memasang atau memakai XyDesk, kamu setuju terikat pada '
      'ketentuan ini. Bila tidak setuju, jangan memakai aplikasi ini.',
    ),
    _sec(c, '2. Penggunaan yang Diizinkan'),
    _para(
      c,
      'XyDesk hanya boleh dipakai untuk mengakses komputer milikmu '
      'sendiri, atau komputer yang pemiliknya telah memberi izin '
      'secara sadar dan sukarela.',
    ),
    _bullets(c, [
      'Dilarang memakai XyDesk untuk mengakses perangkat tanpa izin.',
      'Dilarang memakai XyDesk dalam penipuan, termasuk berpura-pura '
          'sebagai petugas bank, layanan pelanggan, atau instansi resmi.',
      'Dilarang merekayasa balik, membongkar, atau menyalahgunakan '
          'infrastruktur layanan.',
    ]),
    _warnBox(
      c,
      'Peringatan penipuan: layanan resmi TIDAK PERNAH meminta kamu '
      'memasang aplikasi remote desktop lalu menyebutkan ID dan kata '
      'sandi. Jika ada yang meminta demikian, itu penipuan.',
    ),
    _sec(c, '3. Akun'),
    _para(
      c,
      'Kamu bertanggung jawab menjaga kerahasiaan kredensial akun. '
      'Beritahu kami segera bila mencurigai akses tanpa izin.',
    ),
    _sec(c, '4. Ketersediaan Layanan'),
    _para(
      c,
      'Layanan disediakan "sebagaimana adanya". Kami berusaha menjaga '
      'ketersediaan, namun tidak menjamin bebas gangguan, terutama '
      'pada jalur relay yang bergantung pada jaringan pihak ketiga.',
    ),
    _sec(c, '5. Batasan Tanggung Jawab'),
    _para(
      c,
      'Sejauh diizinkan hukum, kami tidak bertanggung jawab atas '
      'kerugian tidak langsung, kehilangan data, atau kehilangan '
      'keuntungan yang timbul dari pemakaian aplikasi.',
    ),
    _sec(c, '6. Perubahan'),
    _para(
      c,
      'Ketentuan dapat berubah. Perubahan penting akan diberitahukan '
      'di dalam aplikasi minimal 14 hari sebelum berlaku.',
    ),
    _sec(c, '7. Kontak'),
    _para(c, 'Pertanyaan: legal@xydesk.app'),
  ];

  List<Widget> _privacy(BuildContext c) => [
    _sec(c, '1. Ringkasan'),
    _para(
      c,
      'XyDesk dirancang agar kami tidak bisa melihat isi layarmu. '
      'Seluruh media dan input terenkripsi ujung-ke-ujung; server kami '
      'hanya meneruskan paket terenkripsi.',
    ),
    _sec(c, '2. Data yang Kami Simpan'),
    _bullets(c, [
      'Alamat email (bila kamu membuat akun).',
      'ID perangkat, nama perangkat, dan sistem operasinya.',
      'Metadata sesi: waktu mulai/selesai, durasi, jalur P2P atau relay, '
          'bitrate rata-rata, dan latensi rata-rata.',
      'Catatan diagnostik bila kamu mengirimkannya secara manual.',
    ]),
    _sec(c, '3. Yang TIDAK Pernah Kami Simpan'),
    _bullets(c, [
      'Isi layar atau tangkapan layar.',
      'Ketikan keyboard maupun gerakan mouse.',
      'Audio dari mikrofon atau sistem.',
      'Berkas yang kamu transfer dan isi papan klip.',
    ]),
    _sec(c, '4. Izin Perangkat'),
    _para(
      c,
      'Semua izin diminta hanya saat fiturnya dipakai, dan semuanya '
      'boleh ditolak. Menolak izin hanya menonaktifkan fitur terkait, '
      'bukan seluruh aplikasi.',
    ),
    _bullets(c, [
      'Mikrofon — mengirim suaramu ke PC saat sesi.',
      'Kamera — hanya untuk memindai kode QR koneksi.',
      'Notifikasi — status sesi dan peringatan koneksi.',
      'Penyimpanan — menyimpan berkas hasil transfer ke folder XyDesk.',
    ]),
    _sec(c, '5. Penyimpanan Lokal'),
    _para(
      c,
      'Pengaturan, daftar perangkat, riwayat, dan profil kontrol '
      'tersimpan di perangkatmu sendiri, bukan di server kami.',
    ),
    _sec(c, '6. Retensi'),
    _para(
      c,
      'Metadata sesi disimpan 90 hari. Catatan audit 1 tahun. '
      'Menghapus akun akan menghapus seluruh data terkait dalam 30 hari.',
    ),
    _sec(c, '7. Hak Kamu'),
    _para(
      c,
      'Kamu berhak mengakses, memperbaiki, mengunduh, dan menghapus '
      'datamu. Hubungi privacy@xydesk.app.',
    ),
  ];

  /// Lisensi pihak ketiga.
  ///
  /// Sebelumnya bagian ini memuat 18 komponen yang diketik tangan. Jumlah
  /// sebenarnya yang ikut terkirim ke perangkat pengguna ada 482 (90 paket
  /// Dart, 324 crate Rust, 58 paket npm, 10 aset & layanan) — daftar tangan
  /// tidak pernah bisa mengejarnya, dan daftar lisensi yang tidak lengkap
  /// adalah masalah hukum, bukan sekadar dokumentasi yang kurang rapi.
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
      'XyDesk memakai 482 komponen pihak ketiga: 90 paket Dart/Flutter, '
      '324 crate Rust di aplikasi Host, 58 paket npm di web dan layanan, '
      'serta 10 aset, SDK, dan layanan awan. Semuanya didaftar lengkap '
      'beserta lisensinya — tidak ada yang disembunyikan.',
    ),
    const SizedBox(height: Gap.md),
    _sec(c, 'Komponen inti'),
    for (final l in const [
      ('Flutter & Dart SDK', 'BSD-3-Clause', 'Google'),
      ('libwebrtc', 'BSD-3-Clause', 'Google — media peer-to-peer'),
      ('libopus 1.5.2', 'BSD-3-Clause', 'Xiph.Org — codec audio'),
      ('OpenH264', 'BSD-2-Clause', 'Cisco — encode video'),
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
        'Opsional saat GPU NVIDIA ada',
      ),
      ('OneSignal SDK', 'Ketentuan OneSignal', 'Push notifikasi'),
      (
        'Cloudflare Workers, D1, TURN',
        'Ketentuan Cloudflare',
        'Signaling & berita',
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
      'Tombol di atas membuka teks lisensi lengkap setiap paket, dibaca '
      'langsung dari aplikasi yang sedang kamu jalankan. Inventaris penuh '
      'lintas platform (termasuk crate Rust dan paket npm) ada di dokumen '
      'THIRD-PARTY-LICENSES pada repositori proyek.',
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

Widget _para(BuildContext c, String t) => Padding(
  padding: const EdgeInsets.only(bottom: Gap.sm),
  child: Text(
    t,
    style: TextStyle(fontSize: 13, height: 1.65, color: c.c.textMid),
  ),
);

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
              Expanded(
                child: Text(
                  i,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: c.c.textMid,
                  ),
                ),
              ),
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
      Expanded(
        child: Text(
          t,
          style: TextStyle(fontSize: 12.5, height: 1.6, color: c.c.textHi),
        ),
      ),
    ],
  ),
);
