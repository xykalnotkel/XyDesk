import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/haptics.dart';
import '../../core/tokens.dart';
import '../../widgets/seamless.dart';
import 'update_page.dart';
import 'update_repository.dart';

/// Modal Popup Visual Pembaruan Aplikasi XyDesk.
///
/// Menampilkan banner visual 4:3 bergaya morphing 3D dengan efek motion blur
/// dan teks tajam. Menghubungkan langsung pengguna ke layar pembaruan
/// (UpdatePage) untuk proses unduh di latar belakang (dengan progress bar di
/// notifikasi sistem Android) serta instalasi langsung di dalam aplikasi.
class UpdatePopupDialog extends StatelessWidget {
  const UpdatePopupDialog({
    super.key,
    required this.result,
  });

  final UpdateCheckResult result;

  /// Buka dialog pembaruan jika ada rilis baru dan belum pernah ditutup
  /// untuk build ini.
  static Future<void> showIfNeeded(
    BuildContext context,
    UpdateCheckResult result, {
    required bool wasDismissed,
    required Future<void> Function() onDismiss,
  }) async {
    if (!result.updateAvailable || wasDismissed) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => UpdatePopupDialog(result: result),
    );

    await onDismiss();
  }

  void _openUpdatePage(BuildContext context) {
    AppHaptics.tap();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UpdatePage(details: result.manifest.details),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifest = result.manifest;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Kontainer Utama dengan Border Glow Ungu
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF13131A),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
                      blurRadius: 32,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Banner Visual 4:3 (Pure Generated Image) ──
                    GestureDetector(
                      onTap: () => _openUpdatePage(context),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(21),
                        ),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/img/update_popup_banner.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF1B1B28),
                                  child: const Center(
                                    child: Icon(
                                      LucideIcons.sparkles,
                                      size: 48,
                                      color: Color(0xFFA78BFA),
                                    ),
                                  ),
                                ),
                              ),
                              // Vignette halus di bagian bawah gambar
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 48,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        const Color(0xFF13131A).withValues(alpha: 0.8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Informasi Pembaruan & Aksi ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'v${manifest.version}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFC4B5FD),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Gap.sm),
                              Text(
                                'Build ${manifest.buildNumber}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Gap.sm),
                          Text(
                            manifest.details.title,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            manifest.details.message,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.45,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: Gap.lg),

                          // Tombol Aksi Utama: Perbarui Sekarang
                          PrimaryButton(
                            label: 'Perbarui Sekarang',
                            icon: LucideIcons.download,
                            height: 48,
                            onPressed: () => _openUpdatePage(context),
                          ),
                          const SizedBox(height: Gap.sm),

                          // Tombol Aksi Sekunder: Nanti Saja
                          Center(
                            child: TextButton(
                              onPressed: () {
                                AppHaptics.tap();
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withValues(alpha: 0.55),
                                minimumSize: const Size(120, 36),
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: const Text('Nanti Saja'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tombol Tutup Melayang di Pojok Kanan Atas ──
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      AppHaptics.tap();
                      Navigator.of(context).pop();
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
