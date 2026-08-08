import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';

/// Splash pembuka XyDesk.
///
/// Urutannya sengaja dibuat seperti identitas produk:
/// 1. logo muncul bersama ripple melingkar,
/// 2. logo bergeser ke kiri,
/// 3. wordmark "XyDesk" masuk dari kanan.
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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;

    if (reduceMotion) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(
          child: _SplashLockup(
            logoSlide: 1,
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
            final logoSlide = Curves.easeOutCubic.transform(
              _phase(t, 0.38, 0.70),
            );
            final wordmarkOpacity = Curves.easeOutCubic.transform(
              _phase(t, 0.50, 0.78),
            );
            final wordmarkSlide = 18 * (1 - wordmarkOpacity);
            final rippleFade = 1 - _phase(t, 0.58, 0.86);

            return Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  _Ripple(
                    phase: _phase(t, i * 0.14, 0.58),
                    opacity: rippleFade,
                    color: c.accent,
                  ),
                _SplashLockup(
                  logoSlide: logoSlide,
                  wordmarkOpacity: wordmarkOpacity,
                  wordmarkSlide: wordmarkSlide,
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
class _Ripple extends StatelessWidget {
  const _Ripple({
    required this.phase,
    required this.opacity,
    required this.color,
  });

  final double phase;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = Curves.easeOutCubic.transform(phase);
    return Opacity(
      opacity: (1 - p) * 0.42 * opacity,
      child: Transform.scale(
        scale: 0.72 + p * 1.35,
        child: Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lockup horizontal untuk fase akhir splash.
class _SplashLockup extends StatelessWidget {
  const _SplashLockup({
    required this.logoSlide,
    required this.wordmarkOpacity,
    required this.wordmarkSlide,
  });

  final double logoSlide;
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
            offset: Offset(-58 * logoSlide, 0),
            child: const BrandLogo(size: 84),
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
