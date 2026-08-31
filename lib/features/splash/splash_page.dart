//! Splash XyDesk — revisi 6.1: halus, premium, identitas ungu.
//!
//! Koreografi 1700 ms (kurva easeOutQuart konsisten — tidak ada sentakan):
//!   1. Latar putih dengan cahaya ungu lembut di belakang tile (fade in).
//!   2. Tile logo (gelap + X putih + aksen ungu) muncul membesar 0.84 → 1.0.
//!   3. Wordmark "XyDesk" gradient ungu menyusul — fade + naik 12 px,
//!      letter-spacing mengendur dari lebar ke normal.
//!   4. Garis aksen ungu tumbuh; tagline muncul terakhir.
//!
//! Tanpa glow mencolok/bayangan pada logo; semua fase satu kurva agar
//! terasa mahal, bukan sibuk. "Kurangi gerakan" → langsung keadaan akhir.

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
    duration: const Duration(milliseconds: 1700),
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

  // Fase (fraksi total durasi).
  static const _bgEnd = 0.30;
  static const _tileEnd = 0.44;
  static const _wordStart = 0.34;
  static const _wordEnd = 0.66;
  static const _lineStart = 0.60;
  static const _lineEnd = 0.84;
  static const _tagStart = 0.74;
  static const _tagEnd = 0.94;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.sizeOf(context);
    final shortSide = size.width < size.height ? size.width : size.height;
    final tileSize = (shortSide * 0.30).clamp(96.0, 136.0).toDouble();

    // 1. Cahaya ungu latar memudar masuk.
    final bgT = _quart(_frac(t, 0, _bgEnd));

    // 2. Tile logo membesar + fade.
    final tileT = _quart(_frac(t, 0, _tileEnd));
    final tileScale = 0.84 + 0.16 * tileT;

    // 3. Wordmark: fade + naik; letter-spacing mengendur.
    final wordT = _quart(_frac(t, _wordStart, _wordEnd));
    final wordDy = 12.0 * (1 - wordT);
    final wordSpacing = 6.0 * (1 - wordT);

    // 4. Garis aksen ungu tumbuh horizontal.
    final lineT = _quart(_frac(t, _lineStart, _lineEnd));

    // 5. Tagline.
    final tagT = _frac(t, _tagStart, _tagEnd);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cahaya ungu lembut di belakang tile — identitas tanpa mencolok.
          Center(
            child: Opacity(
              opacity: bgT * 0.5,
              child: Container(
                width: tileSize * 2.6,
                height: tileSize * 2.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.accent.withValues(alpha: 0.35),
                      c.accent.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tile logo: kotak gelap rounded + X putih + aksen ungu.
                  Opacity(
                    opacity: tileT.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: tileScale,
                      child: Image.asset(
                        Img.logo,
                        width: tileSize,
                        height: tileSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Opacity(
                    opacity: wordT.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, wordDy),
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF6D28D9), Color(0xFFA78BFA)],
                        ).createShader(bounds),
                        child: Text(
                          'XyDesk',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: wordSpacing,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 104,
                    height: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: lineT,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6D28D9), Color(0xFFA78BFA)],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Opacity(
                    opacity: tagT.clamp(0.0, 1.0),
                    child: Text(
                      'PC kamu, di tangan kamu',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 0.4,
                        color: c.textMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
