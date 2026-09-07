//! Splash XyDesk — simple watermark only (Founder request 2026-09-07).
//!
//! Hanya logo watermark, tanpa wordmark, tanpa progress bar, tanpa setting.
//! Pengaturan kualitas dll cukup di session screen & host.
//! Durasi 800ms fade simple.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/store.dart';
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
    duration: const Duration(milliseconds: 800),
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
    // Simple fade only — watermark
    final opacity = t.clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            Img.logo,
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
