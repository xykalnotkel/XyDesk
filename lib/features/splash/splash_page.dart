//! Splash XyDesk — revisi 6.5: cukup logo + wordmark.
//!
//! Semua elemen tambahan (progres bar, tagline, versi di kaki) dihapus —
//! splash hanya identitas visual singkat sebelum aplikasi siap.
//! Durasi 1200 ms; "kurangi gerakan" langsung ke keadaan akhir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        ref.watch(settingsProvider).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return const _SplashScene(t: 1);
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => _SplashScene(t: _ctrl.value),
    );
  }
}

double _quart(double t) => 1 - (1 - t) * (1 - t) * (1 - t) * (1 - t);

double _frac(double t, double a, double b) {
  if (t <= a) return 0;
  if (t >= b) return 1;
  return (t - a) / (b - a);
}

class _SplashScene extends StatelessWidget {
  const _SplashScene({required this.t});

  /// Progres koreografi 0..1.
  final double t;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.sizeOf(context);
    final shortSide = size.width < size.height ? size.width : size.height;
    final tileSize = (shortSide * 0.32).clamp(100.0, 150.0).toDouble();

    // Logo fade + scale masuk.
    final logoT = _quart(_frac(t, 0, 0.45));
    final logoScale = 0.88 + 0.12 * logoT;

    // Wordmark muncul setelah logo, fade + naik sedikit.
    final wordT = _quart(_frac(t, 0.28, 0.75));
    final wordDy = 10.0 * (1 - wordT);

    // Cahaya ungu halus di belakang logo.
    final bgT = _quart(_frac(t, 0, 0.35));

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cahaya ungu lembut — identitas tanpa mencolok.
          Center(
            child: Opacity(
              opacity: bgT * 0.25,
              child: Container(
                width: tileSize * 2.8,
                height: tileSize * 2.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.accent.withValues(alpha: 0.30),
                      c.accent.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.50, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo.
                Opacity(
                  opacity: logoT.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: logoScale,
                    child: Image.asset(
                      Img.logo,
                      width: tileSize,
                      height: tileSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Wordmark — gradient ungu.
                Opacity(
                  opacity: wordT.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, wordDy),
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6D28D9), Color(0xFFA78BFA)],
                      ).createShader(bounds),
                      child: const Text(
                        'XyDesk',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
