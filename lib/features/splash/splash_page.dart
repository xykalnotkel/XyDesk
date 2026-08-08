import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tokens.dart';
import '../widgets/brand.dart';

/// Splash pembuka dengan efek "round logo ripple":
/// cincin melingkar yang beriak keluar dari logo, bergaya Jitter
/// "round logo ripple". Diganti karena aset Jitter tidak bisa di-unduh
/// langsung, jadi efeknya di-reka ulang native.
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
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // "Kurangi animasi" aktif -> tampilkan logo statis tanpa riak.
    if (ref.watch(settingsProvider).reduceMotion) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: BrandLogo(size: 84)),
      );
    }
    const rings = 3;
    final slot = 1 / rings;

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < rings; i++)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  // Geser fase tiap ring supaya beriaknya selang-seling.
                  final raw = _ctrl.value - i * slot;
                  final local = raw < 0 ? raw + 1 : raw;
                  final p = (local / slot).clamp(0.0, 1.0);
                  final scale = 0.7 + p * 1.4; // 0.7 -> 2.1
                  final opacity = (1 - p) * 0.5;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.accent.withValues(alpha: opacity),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            const BrandLogo(size: 84),
          ],
        ),
      ),
    );
  }
}
