import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/store.dart';
import '../../widgets/brand.dart';

/// Transisi dari splash native menuju aplikasi.
///
/// Logo dibuat lebih besar dan seluruh dekorasi memakai spektrum ungu/biru;
/// tidak ada garis status kuning. Blur hanya dipakai saat objek bergerak masuk,
/// kemudian kembali tajam agar tetap ringan di perangkat kelas menengah.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..forward();

  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        ref.watch(settingsProvider).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      return const _SplashScene(intro: 1, ambient: 0.5);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _ambient]),
      builder: (context, _) => _SplashScene(
        intro: Curves.easeOutCubic.transform(_intro.value),
        ambient: Curves.easeInOut.transform(_ambient.value),
      ),
    );
  }
}

class _SplashScene extends StatelessWidget {
  const _SplashScene({required this.intro, required this.ambient});

  final double intro;
  final double ambient;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortSide = math.min(size.width, size.height);
    final logoSize = (shortSide * 0.23).clamp(82.0, 104.0).toDouble();
    final glowShift = (ambient - 0.5) * 18;
    final wordmarkT = _interval(intro, 0.30, 0.82);
    final taglineT = _interval(intro, 0.52, 1);

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
            _FloatingShard(
              alignment: const Alignment(-0.76, -0.55),
              drift: Offset(glowShift * 0.42, -glowShift * 0.26),
              rotation: -0.42,
              width: 44,
              color: const Color(0xFF9A7BFF),
              opacity: 0.26 * _interval(intro, 0.10, 0.72),
            ),
            _FloatingShard(
              alignment: const Alignment(0.76, -0.30),
              drift: Offset(-glowShift * 0.34, glowShift * 0.22),
              rotation: 0.52,
              width: 34,
              color: const Color(0xFF68A4FF),
              opacity: 0.22 * _interval(intro, 0.18, 0.80),
            ),
            _FloatingShard(
              alignment: const Alignment(-0.62, 0.48),
              drift: Offset(-glowShift * 0.28, glowShift * 0.18),
              rotation: 0.24,
              width: 27,
              color: const Color(0xFFC3B2FF),
              opacity: 0.18 * _interval(intro, 0.24, 0.86),
            ),
            _FloatingShard(
              alignment: const Alignment(0.66, 0.58),
              drift: Offset(glowShift * 0.32, -glowShift * 0.18),
              rotation: -0.68,
              width: 49,
              color: const Color(0xFF7357F4),
              opacity: 0.22 * _interval(intro, 0.16, 0.78),
            ),
            Center(
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - intro)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 0.62 * intro,
                          child: Container(
                            width: logoSize * 1.46,
                            height: logoSize * 1.46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF7654F6)
                                      .withValues(alpha: 0.34),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: intro,
                          child: Transform.scale(
                            scale: 0.76 + (0.24 * intro),
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 9 * (1 - intro),
                                sigmaY: 9 * (1 - intro),
                              ),
                              child: BrandLogo(size: logoSize),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: wordmarkT,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - wordmarkT)),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 5 * (1 - wordmarkT),
                            sigmaY: 5 * (1 - wordmarkT),
                          ),
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => const LinearGradient(
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
                                fontSize: 36,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.9,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Opacity(
                      opacity: taglineT,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - taglineT)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.045),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                          child: const Text(
                            'REMOTE  •  FLUID  •  SECURE',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.55,
                              color: Color(0xFFA8A7B4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class _FloatingShard extends StatelessWidget {
  const _FloatingShard({
    required this.alignment,
    required this.drift,
    required this.rotation,
    required this.width,
    required this.color,
    required this.opacity,
  });

  final Alignment alignment;
  final Offset drift;
  final double rotation;
  final double width;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: drift,
        child: Transform.rotate(
          angle: rotation,
          child: Opacity(
            opacity: opacity.clamp(0, 1).toDouble(),
            child: Container(
              width: width,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.58),
                    color.withValues(alpha: 0.08),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.16),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _interval(double value, double begin, double end) {
  return ((value - begin) / (end - begin)).clamp(0, 1).toDouble();
}
