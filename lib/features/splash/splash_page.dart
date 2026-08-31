//! Splash XyDesk — revisi 6.2.
//!
//! ## Yang berubah dari revisi 6.1 dan kenapa
//!
//! 1. **Durasi 1700 → 1250 ms.** Splash adalah pajak yang dibayar pengguna
//!    setiap kali membuka aplikasi. 1,7 detik terasa mahal pada kali pertama
//!    dan terasa lambat pada kali kelima puluh.
//! 2. **Garis aksen diganti indikator progres tipis.** Garis lama tumbuh
//!    lalu berhenti tanpa arti — dekorasi yang menyamar sebagai status.
//!    Sekarang lebarnya benar-benar mewakili kemajuan boot.
//! 3. **Versi + tahap rilis ditampilkan di kaki layar.** Selama pra-beta,
//!    pengguna berhak tahu build apa yang sedang mereka jalankan tanpa
//!    menggali ke Pengaturan — dan itu memangkas separuh basa-basi saat
//!    mereka melapor bug.
//! 4. Cahaya latar diredam (0,5 → 0,38) supaya tile tetap jadi subjek.
//!
//! Semua fase memakai satu kurva easeOutQuart agar terasa mahal, bukan
//! sibuk. "Kurangi gerakan" → langsung ke keadaan akhir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_version.dart';
import '../../core/release_stage.dart';
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
    duration: const Duration(milliseconds: 1250),
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
  static const _bgEnd = 0.28;
  static const _tileEnd = 0.42;
  static const _wordStart = 0.32;
  static const _wordEnd = 0.62;
  static const _lineStart = 0.20;
  static const _lineEnd = 1.00;
  static const _tagStart = 0.66;
  static const _tagEnd = 0.88;
  static const _footStart = 0.72;
  static const _footEnd = 0.96;

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

    // 6. Kaki layar: versi + tahap rilis.
    final footT = _frac(t, _footStart, _footEnd);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cahaya ungu lembut di belakang tile — identitas tanpa mencolok.
          Center(
            child: Opacity(
              opacity: bgT * 0.38,
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
                  const SizedBox(height: 16),
                  // Rel progres: alur tipis yang selalu terlihat, terisi
                  // sesuai kemajuan. Garis lama tumbuh dari nol tanpa rel,
                  // jadi tidak ada yang bisa dibaca sebagai "sisa berapa".
                  SizedBox(
                    width: 104,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: lineT.clamp(0.0, 1.0),
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
          // Kaki layar: versi yang sedang berjalan + tahap rilis.
          Positioned(
            left: 0,
            right: 0,
            bottom: 26,
            child: Opacity(
              opacity: footT.clamp(0.0, 1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(R.pill),
                    ),
                    child: Text(
                      ReleaseStage.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: c.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppVersion.full,
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.3,
                      color: c.textLow,
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
