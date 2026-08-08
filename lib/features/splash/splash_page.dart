import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';

/// Splash pembuka XyDesk.
///
/// Urutannya dibuat seperti identitas produk:
/// 1. logo dirakit dari skala kecil bersama ripple,
/// 2. logo meluncur ke kanan sebentar,
/// 3. logo swipe kembali ke kiri sambil wordmark "XyDesk" muncul halus.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _phase(double value, double start, double end) {
    return ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
  }

  double _logoX(double value) {
    // Logo dirakit di tengah, bergerak sedikit ke kanan, lalu swipe ke kiri
    // untuk membuka ruang wordmark.
    final right = Curves.easeOutCubic.transform(_phase(value, 0.36, 0.54));
    final left = Curves.easeInOutCubic.transform(_phase(value, 0.54, 0.80));
    return right * 42 - left * 100;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;

    if (reduceMotion) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(
          child: _SplashLockup(
            logoX: -58,
            logoScale: 1,
            logoOpacity: 1,
            logoRotation: 0,
            wordmarkOpacity: 1,
            wordmarkSlide: 0,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            final assembled = Curves.easeOutCubic.transform(
              _phase(t, 0.02, 0.36),
            );
            final wordmarkOpacity = Curves.easeOutCubic.transform(
              _phase(t, 0.58, 0.86),
            );
            final rippleFade = 1 - _phase(t, 0.58, 0.86);

            return Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  _SnakeRipple(
                    phase: _phase(t, i * 0.14, 0.58),
                    opacity: rippleFade,
                    color: c.accent,
                  ),
                _SplashLockup(
                  logoX: _logoX(t),
                  logoScale: 0.72 + assembled * 0.28,
                  logoOpacity: assembled,
                  logoRotation: 0.04 * (1 - assembled),
                  wordmarkOpacity: wordmarkOpacity,
                  wordmarkSlide: 18 * (1 - wordmarkOpacity),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Ripple besar di belakang logo. Setiap ring dimulai sedikit bergeser agar
/// gerakannya terasa mengalir, bukan tiga lingkaran yang membesar bersamaan.
class _SnakeRipple extends StatelessWidget {
  const _SnakeRipple({
    required this.phase,
    required this.opacity,
    required this.color,
  });

  final double phase;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity * 0.78,
      child: CustomPaint(
        size: const Size(150, 150),
        painter: _SnakeRipplePainter(phase: phase, color: color),
      ),
    );
  }
}

class _SnakeRipplePainter extends CustomPainter {
  const _SnakeRipplePainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide * 0.5;
    final p = Curves.easeInOutCubic.transform(phase);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;

    for (var i = 0; i < 3; i++) {
      final radius = base * (0.50 + i * 0.13 + p * 0.42);
      final start = -1.15 + p * 5.7 + i * 2.1;
      final sweep = 0.95 + (1 - p) * 0.55;
      paint.color = color.withValues(
        alpha: (0.22 - i * 0.035).clamp(0.06, 0.22),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SnakeRipplePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

/// Lockup horizontal untuk fase akhir splash.
class _SplashLockup extends StatelessWidget {
  const _SplashLockup({
    required this.logoX,
    required this.logoScale,
    required this.logoOpacity,
    required this.logoRotation,
    required this.wordmarkOpacity,
    required this.wordmarkSlide,
  });

  final double logoX;
  final double logoScale;
  final double logoOpacity;
  final double logoRotation;
  final double wordmarkOpacity;
  final double wordmarkSlide;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 260,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(logoX, 0),
            child: Transform.rotate(
              angle: logoRotation,
              child: Opacity(
                opacity: logoOpacity,
                child: Transform.scale(
                  scale: logoScale,
                  child: const BrandLogo(size: 84),
                ),
              ),
            ),
          ),
          Positioned(
            left: 130,
            child: Opacity(
              opacity: wordmarkOpacity,
              child: Transform.translate(
                offset: Offset(wordmarkSlide, 0),
                child: Text(
                  'XyDesk',
                  style: TextStyle(
                    color: c.textHi,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
