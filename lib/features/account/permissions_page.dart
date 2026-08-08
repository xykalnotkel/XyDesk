import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n_bridge.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/seamless.dart';

class _Perm {
  const _Perm(this.icon, this.name, this.why, this.when, this.required_);
  final IconData icon;
  final String name;
  final String why;
  final String when;
  final bool required_;
}

/// Halaman izin: menjelaskan setiap izin dan kapan diminta.
///
/// Prinsipnya: izin diminta saat fiturnya dipakai, bukan sekaligus di awal.
/// Halaman ini murni penjelasan, bukan permintaan.
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key});

  static const _items = <_Perm>[
    _Perm(
      LucideIcons.wifi,
      'Jaringan',
      'Menghubungkan ke PC kamu.',
      'Otomatis, tanpa dialog',
      true,
    ),
    _Perm(
      LucideIcons.mic,
      'Mikrofon',
      'Mengirim suaramu ke PC saat sesi berlangsung.',
      'Saat kamu menyalakan mik pertama kali',
      false,
    ),
    _Perm(
      LucideIcons.camera,
      'Kamera',
      'Memindai kode QR koneksi dari aplikasi host.',
      'Saat membuka pemindai QR',
      false,
    ),
    _Perm(
      LucideIcons.bell,
      'Notifikasi',
      'Status sesi dan peringatan koneksi terputus.',
      'Setelah sesi pertama selesai',
      false,
    ),
    _Perm(
      LucideIcons.folder,
      'Penyimpanan & berkas',
      'Menyimpan berkas hasil transfer ke folder XyDesk di Dokumen.',
      'Saat kamu mentransfer berkas',
      false,
    ),
    _Perm(
      LucideIcons.bluetooth,
      'Bluetooth',
      'Menyambungkan gamepad nirkabel.',
      'Saat memilih pakai stik fisik',
      false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(context.tr('settings_permissions')),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.textMid),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.sm,
          Gap.screen,
          Gap.h40,
        ),
        children: [
          const Center(child: Illus(Img.secure, size: 132, opacity: 0.9)),
          const SizedBox(height: Gap.lg),
          Text(
            'XyDesk hanya meminta izin saat fiturnya dipakai. '
            'Semua boleh ditolak — menolak hanya menonaktifkan fitur '
            'terkait, bukan seluruh aplikasi.',
            style: TextStyle(fontSize: 12.5, height: 1.6, color: c.textMid),
          ),
          const SizedBox(height: Gap.lg),
          for (final p in _items) _tile(context, p),
          const SectionLabel('Penyimpanan berkas'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.folderOpen, size: 16, color: c.accent),
                    const SizedBox(width: Gap.sm),
                    Text(
                      'Lokasi berkas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textHi,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                SelectableText(
                  'Android/data/com.xystudio.xydesk/files/XyDesk/',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    height: 1.5,
                    color: c.textMid,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Berkas hasil transfer, tangkapan layar, dan ekspor profil '
                  'disimpan di sini. Folder ini ikut terhapus saat aplikasi '
                  'dicopot, sehingga tidak meninggalkan sampah.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.55,
                    color: c.textLow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, _Perm p) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(p.icon, size: 17, color: c.textMid),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textHi,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (p.required_ ? AppColors.success : c.textLow)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        p.required_ ? 'Wajib' : 'Opsional',
                        style: TextStyle(
                          fontSize: 9,
                          color: p.required_ ? AppColors.success : c.textLow,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  p.why,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: c.textMid,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Diminta: ${p.when}',
                  style: TextStyle(fontSize: 10.5, color: c.textLow),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
