import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/haptics.dart';
import 'update_page.dart';
import 'update_repository.dart';

/// Modal Popup Visual Pembaruan Aplikasi XyDesk.
///
/// Berupa pure gambar vertikal (portrait 3:4) beresolusi tinggi dengan tipografi
/// 3D yang jelas, efek morphing kaca ungu, elemen melayang dengan motion blur,
/// dan tombol "X" melayang di pojok atas. Mengetuk gambar langsung membuka
/// layar pembaruan (UpdatePage) untuk unduhan latar belakang dan instalasi APK.
class UpdatePopupDialog extends StatefulWidget {
  const UpdatePopupDialog({super.key, required this.result});

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
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (ctx) => UpdatePopupDialog(result: result),
    );

    await onDismiss();
  }

  @override
  State<UpdatePopupDialog> createState() => _UpdatePopupDialogState();
}

class _UpdatePopupDialogState extends State<UpdatePopupDialog> {
  bool _pressed = false;

  void _openUpdatePage() {
    AppHaptics.tap();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UpdatePage(details: widget.result.manifest.details),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Pure Full-bleed 3:4 Portrait Image Banner ──
              GestureDetector(
                onTap: _openUpdatePage,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                child: AnimatedScale(
                  scale: _pressed ? 0.97 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.75),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22.5),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Image.asset(
                          'assets/img/update_popup_banner.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF13131A),
                            child: const Center(
                              child: Icon(
                                LucideIcons.sparkles,
                                size: 48,
                                color: Color(0xFFA78BFA),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Tombol X Melayang di Pojok Kanan Atas ──
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      AppHaptics.tap();
                      Navigator.of(context).pop();
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        LucideIcons.x,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.9),
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
