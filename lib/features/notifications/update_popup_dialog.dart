import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/haptics.dart';
import '../../core/tokens.dart';
import 'update_page.dart';
import 'update_repository.dart';

/// Modal Popup Visual Pembaruan Aplikasi XyDesk.
///
/// Kartu portrait bergaya "Quiet Surface": banner 3D glossy di atas
/// (ketuk untuk langsung ke layar pembaruan), di bawahnya isi yang benar-benar
/// berguna — versi rilis, status resmi, pesan singkat, dan dua aksi
/// ("Nanti" / "Perbarui Sekarang") — plus tombol X melayang untuk menutup.
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
    final c = context.c;
    final manifest = widget.result.manifest;
    final details = manifest.details;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: c.raised,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Banner visual: ketuk = buka layar pembaruan ──
                      GestureDetector(
                        onTap: _openUpdatePage,
                        onTapDown: (_) => setState(() => _pressed = true),
                        onTapUp: (_) => setState(() => _pressed = false),
                        onTapCancel: () => setState(() => _pressed = false),
                        child: AnimatedScale(
                          scale: _pressed ? 0.97 : 1.0,
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOutCubic,
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/img/update_popup_banner.jpg',
                                    fit: BoxFit.cover,
                                    semanticLabel: 'Ilustrasi pembaruan XyDesk',
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
                                // Peralihan lembut ke permukaan kartu.
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          c.raised.withValues(alpha: 0),
                                          c.raised,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _Chip(
                                  icon: LucideIcons.sparkles,
                                  label:
                                      'v${manifest.version} • build '
                                      '${manifest.buildNumber}',
                                  color: c.accentDeep,
                                ),
                                _Chip(
                                  icon: LucideIcons.shieldCheck,
                                  label: 'Release resmi',
                                  color: c.textMid,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Pembaruan tersedia',
                              style: TextStyle(
                                color: c.textHi,
                                fontSize: 20,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              details.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textMid,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    AppHaptics.tap();
                                    Navigator.of(context).pop();
                                  },
                                  child: Text(
                                    'Nanti',
                                    style: TextStyle(color: c.textMid),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _openUpdatePage,
                                    child: const Text('Perbarui Sekarang'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tombol X melayang di pojok kanan atas ──
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

/// Chip kecil bergaya status — selaras dengan chip di UpdatePage.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
