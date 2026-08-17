import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/seamless.dart';
import 'app_update_details.dart';

class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key, required this.details});

  final AppUpdateDetails details;

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  bool _openingDownload = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_openingDownload) return;
    setState(() => _openingDownload = true);
    var opened = false;
    try {
      opened = await launchUrl(
        AppUpdateDetails.officialDownloadUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _openingDownload = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tautan unduhan resmi belum dapat dibuka.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduceMotion = ref.watch(settingsProvider).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Pembaruan XyDesk'),
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
          TickerMode(
            enabled: !reduceMotion,
            child: _AnimatedBanner(
              motion: _motion,
              reduceMotion: reduceMotion,
            ),
          ),
          const SizedBox(height: Gap.xl),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(R.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.sparkles, size: 13, color: c.accent),
                    const SizedBox(width: 6),
                    Text(
                      'PEMBARUAN RESMI',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  widget.details.version,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 10.5, color: c.textLow),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            widget.details.title,
            style: TextStyle(
              fontSize: 25,
              height: 1.18,
              fontWeight: FontWeight.w700,
              color: c.textHi,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            widget.details.message,
            style: TextStyle(fontSize: 13, height: 1.65, color: c.textMid),
          ),
          const SectionLabel('Yang perlu diketahui'),
          SurfaceCard(
            child: Column(
              children: [
                for (var i = 0; i < widget.details.releaseNotes.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == widget.details.releaseNotes.length - 1
                          ? 0
                          : Gap.md,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            LucideIcons.check,
                            size: 13,
                            color: c.accent,
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(
                            widget.details.releaseNotes[i],
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.55,
                              color: c.textMid,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  c.accent.withValues(alpha: 0.16),
                  c.raised,
                ],
              ),
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.shieldCheck, size: 18, color: c.accent),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    'Tombol unduh hanya membuka APK dari GitHub Releases resmi '
                    'XyDesk. Periksa nama berkas XyDesk.apk sebelum memasang.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.55,
                      color: c.textMid,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),
          FilledButton.icon(
            onPressed: _openingDownload ? null : _download,
            icon: _openingDownload
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.download, size: 17),
            label: Text(
              _openingDownload ? 'Membuka…' : 'Unduh APK resmi',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(R.md),
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Pengunduhan berlangsung di browser agar sumber dan alamat rilis '
            'tetap dapat kamu periksa.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, height: 1.5, color: c.textLow),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBanner extends StatelessWidget {
  const _AnimatedBanner({
    required this.motion,
    required this.reduceMotion,
  });

  final Animation<double> motion;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(R.xl),
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.c.raised),
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, child) {
              final t = reduceMotion ? 0.0 : motion.value;
              return Transform.scale(
                scale: 1.0 + (t * 0.018),
                child: Transform.translate(
                  offset: Offset((t - 0.5) * 3, (t - 0.5) * -2),
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'assets/img/xydesk_update_banner.jpg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
