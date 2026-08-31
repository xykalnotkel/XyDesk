//! Splash XyDesk — revisi total 6.0: koreografi pendek dan halus.
//!
//! Alur (total 1800 ms):
//!   1. Tile logo (gelap + X putih + garis aksen ungu) muncul membesar
//!      dari 0.82 → 1.0 dengan easeOutQuart — seperti "bernapas masuk".
//!   2. Wordmark "XyDesk" naik pelan sambil memudar masuk (fade + 14 px).
//!   3. Garis aksen ungu tumbuh dari kiri ke kanan di bawah wordmark.
//!   4. Tagline muncul terakhir, lalu diam 200 ms sebelum diganti gate app.
//!
//! Tanpa glow mencolok, tanpa bayangan, tanpa animasi berlebihan —
//! kurva easeOutQuart konsisten supaya terasa mahal, bukan sibuk.
//! Saat pengguna mengaktifkan "kurangi gerakan", splash langsung tampil
//! pada keadaan akhir (t = 1) tanpa animasi.

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
  /// Total durasi koreografi: 1800 ms + jeda tenang diatur oleh gate.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
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

/// Kurva halus per fase — semua easeOutQuart supaya tidak ada sentakan.
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
  static const _logoEnd = 0.42;
  static const _wordStart = 0.30;
  static const _wordEnd = 0.62;
  static const _lineStart = 0.56;
  static const _lineEnd = 0.80;
  static const _tagStart = 0.72;
  static const _tagEnd = 0.92;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.sizeOf(context);
    final shortSide = size.width < size.height ? size.width : size.height;
    final logoSize = (shortSide * 0.22).clamp(78.0, 108.0).toDouble();

    // 1. Logo tile: membesar + memudar masuk.
    final logoT = _quart(_frac(t, 0, _logoEnd));
    final logoScale = 0.82 + 0.18 * logoT;
    final logoOpacity = logoT.clamp(0.0, 1.0);

    // 2. Wordmark naik + fade.
    final wordT = _quart(_frac(t, _wordStart, _wordEnd));
    final wordDy = 14.0 * (1 - wordT);
    final wordOpacity = wordT.clamp(0.0, 1.0);

    // 3. Garis aksen ungu tumbuh horizontal.
    final lineT = _quart(_frac(t, _lineStart, _lineEnd));
    final lineW = 96.0 * lineT;

    // 4. Tagline memudar masuk.
    final tagT = _frac(t, _tagStart, _tagEnd);
    final tagOpacity = tagT.clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: logoOpacity,
                child: Transform.scale(
                  scale: logoScale,
                  child: Image.asset(
                    Img.logo,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Opacity(
                opacity: wordOpacity,
                child: Transform.translate(
                  offset: Offset(0, wordDy),
                  child: const Text(
                    'XyDesk',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Garis aksen ungu — identitas warna XyDesk.
              SizedBox(
                width: 96,
                height: 4,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: lineW,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Opacity(
                opacity: tagOpacity,
                child: Text(
                  'PC kamu, di tangan kamu',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.2,
                    color: c.textMid,
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
