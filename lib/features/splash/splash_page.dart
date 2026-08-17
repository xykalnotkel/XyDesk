import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/store.dart';
import '../../widgets/brand.dart';

/// Pembuka aplikasi — seluruh animasi milik Flutter (splash native hanya
/// warna latar, tanpa logo, supaya tidak ada kesan splash dobel).
///
/// Koreografi:
///   1. Logo muncul kecil lalu membesar (blur gerak menipis saat tiba).
///   2. Di puncak ukurannya ada efek "klik": scale menekan sekejap dan
///      cincin denyut memancar keluar.
///   3. Logo bergeser ke kanan sedikit (ancang-ancang), lalu meluncur ke
///      kiri menuju posisi lockup.
///   4. Bersamaan dengan luncuran logo ke kiri, wordmark "XyDesk" terungkap
///      dari kiri ke kanan. Arah keduanya sengaja berlawanan.
///   5. Cincin ala kipas CPU berputar cepat di belakang logo selama fase
///      awal, lalu memudar setelah efek klik.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2450),
  )..forward();

  /// Putaran kontinu untuk cincin CPU dan pergeseran glow ambient.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        ref.watch(settingsProvider).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return const _SplashScene(t: 1, spin: 0);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _spin]),
      builder: (context, _) => _SplashScene(t: _intro.value, spin: _spin.value),
    );
  }
}

class _SplashScene extends StatelessWidget {
  const _SplashScene({required this.t, required this.spin});

  /// Progres koreografi 0..1 (linear; kurva diberikan per fase).
  final double t;

  /// Progres putaran 0..1 yang berulang (cincin CPU + glow).
  final double spin;

  // ── Fase koreografi (fraksi dari total durasi) ──
  static const _growEnd = 0.34;
  static const _clickStart = 0.34;
  static const _clickEnd = 0.46;
  static const _rightStart = 0.46;
  static const _rightEnd = 0.58;
  static const _leftStart = 0.58;
  static const _leftEnd = 0.78;
  static const _wordStart = 0.60;
  static const _wordEnd = 0.88;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortSide = math.min(size.width, size.height);
    final logoSize = (shortSide * 0.23).clamp(82.0, 104.0).toDouble();
    final glowShift = (spin - 0.5) * 14;

    // 1. Membesar: 0.30 -> 1.05 dengan easeOutCubic; blur gerak menipis.
    final growT = Curves.easeOutCubic.transform(_frac(t, 0, _growEnd));
    final growScale = 0.30 + 0.75 * growT;
    final arriveBlur = 10 * (1 - growT);

    // 2. Efek klik: tekan ke 0.90 lalu kembali ke 1.0 (punch), disertai
    //    cincin denyut yang memancar dan memudar.
    final clickT = _frac(t, _clickStart, _clickEnd);
    final punch = clickT == 0
        ? 0.0
        : math.sin(clickT * math.pi) * (clickT < 0.5 ? 1 : 0.55);
    final clickScale = 1.05 - 0.15 * punch;
    final pulseR = Curves.easeOut.transform(clickT);

    // 3-4. Geser kanan (ancang-ancang) lalu meluncur ke kiri menuju lockup.
    final rightT = Curves.easeOutCubic.transform(
      _frac(t, _rightStart, _rightEnd),
    );
    final leftT = Curves.easeInOutCubic.transform(
      _frac(t, _leftStart, _leftEnd),
    );
    final wordT = Curves.easeOutCubic.transform(_frac(t, _wordStart, _wordEnd));

    // Ukuran lockup akhir: [logo][jeda][wordmark] berpusat di tengah layar.
    const wordWidth = 132.0;
    const lockupGap = 18.0;
    const lockupShift = (wordWidth + lockupGap) / 2;
    final nudgeRight = 30.0 * rightT;
    final logoDx = nudgeRight - (nudgeRight + lockupShift) * leftT;

    final logoScale = t < _clickStart ? growScale : clickScale;

    // 5. Cincin CPU: berputar cepat selama fase tumbuh, memudar usai klik.
    final ringOpacity = t < _growEnd
        ? growT * 0.5
        : 0.5 * (1 - _frac(t, _clickEnd, _rightEnd));

    return ColoredBox(
      color: const Color(0xFF090A10),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.10),
                  radius: 1.06,
                  colors: [
                    Color(0xFF19152A),
                    Color(0xFF0E0F18),
                    Color(0xFF090A10),
                  ],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
            Positioned(
              left: -80 + glowShift,
              top: size.height * 0.18,
              child: _BlurOrb(
                size: 210,
                color: const Color(0xFF6842E8).withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              right: -96 - glowShift,
              bottom: size.height * 0.12,
              child: _BlurOrb(
                size: 250,
                color: const Color(0xFF3B7CFF).withValues(alpha: 0.12),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: logoSize * 1.6,
                    width: size.width,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cincin denyut efek klik.
                        if (clickT > 0 && pulseR < 1)
                          Opacity(
                            opacity: (1 - pulseR) * 0.55,
                            child: Container(
                              width: logoSize * (1.1 + 0.9 * pulseR),
                              height: logoSize * (1.1 + 0.9 * pulseR),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF9A7BFF),
                                  width: 2 * (1 - pulseR) + 0.5,
                                ),
                              ),
                            ),
                          ),
                        // Cincin CPU berputar cepat di belakang logo.
                        if (ringOpacity > 0.01)
                          Transform.translate(
                            offset: Offset(logoDx, 0),
                            child: Opacity(
                              opacity: ringOpacity,
                              child: Transform.rotate(
                                angle: spin * 2 * math.pi,
                                child: CustomPaint(
                                  size: Size.square(logoSize * 1.42),
                                  painter: const _CpuRingPainter(),
                                ),
                              ),
                            ),
                          ),
                        // Logo.
                        Transform.translate(
                          offset: Offset(logoDx, 0),
                          child: Opacity(
                            opacity: growT.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: logoScale,
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: arriveBlur,
                                  sigmaY: arriveBlur,
                                ),
                                child: BrandLogo(size: logoSize),
                              ),
                            ),
                          ),
                        ),
                        // Logo bergerak kanan ke kiri; teks terungkap dari
                        // kiri ke kanan pada posisi akhirnya.
                        if (wordT > 0)
                          Transform.translate(
                            offset: Offset(
                              logoDx + lockupShift + logoSize / 2,
                              0,
                            ),
                            child: ClipRect(
                              clipper: _LeftToRightReveal(wordT),
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 12 * (1 - wordT),
                                  sigmaY: 0.4 * (1 - wordT),
                                ),
                                child: ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFFFFFF),
                                          Color(0xFFE5DEFF),
                                          Color(0xFFB8A4FF),
                                        ],
                                      ).createShader(bounds),
                                  child: const Text(
                                    'XyDesk',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 38,
                                      height: 1,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -1.9,
                                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftToRightReveal extends CustomClipper<Rect> {
  const _LeftToRightReveal(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(covariant _LeftToRightReveal oldClipper) =>
      oldClipper.progress != progress;
}

/// Cincin putus-putus ala kipas pendingin CPU: beberapa busur dengan celah,
/// intensitas menurun ke arah ekor agar terasa berputar cepat.
class _CpuRingPainter extends CustomPainter {
  const _CpuRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - 2;
    const segments = 5;
    const sweep = (2 * math.pi / segments) * 0.62;

    for (var i = 0; i < segments; i++) {
      final start = (2 * math.pi / segments) * i;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: const [Color(0x005B8CFF), Color(0xFF7E5CF6)],
        ).createShader(rect);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Fraksi progres [value] di antara [begin]..[end], di-clamp 0..1.
double _frac(double value, double begin, double end) {
  return ((value - begin) / (end - begin)).clamp(0, 1).toDouble();
}
