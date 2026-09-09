//! Splash XyDesk — Modern luminous watermark with subtle ambient glow aura.
//!
//! Quiet Surface aesthetic: smooth micro-scale intro, subtle violet ambient
//! bloom behind the clean 3D logo watermark, zero borders.

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
    duration: const Duration(milliseconds: 1100),
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

class _SplashScene extends StatelessWidget {
  const _SplashScene({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Curved progression for buttery-smooth ease-out
    final curveVal = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final opacity = (curveVal * 1.2).clamp(0.0, 1.0);
    final scale = 0.88 + (0.12 * curveVal);
    final auraScale = 0.75 + (0.35 * curveVal);

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft glowing ambient bloom behind logo
            Transform.scale(
              scale: auraScale,
              child: Opacity(
                opacity: (opacity * 0.45).clamp(0.0, 1.0),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.accent.withValues(alpha: 0.28),
                        c.accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Watermark Logo
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  Img.logo,
                  width: 130,
                  height: 130,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
