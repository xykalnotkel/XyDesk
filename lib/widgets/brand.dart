import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/tokens.dart';

/// Aset gambar aplikasi.
///
/// Ilustrasi memakai WebP karena jauh lebih kecil dari PNG pada gambar
/// vektor-3D (~60% lebih ringan), sementara logo tetap PNG agar tepinya
/// tetap tajam saat dipakai di ukuran kecil.
class Img {
  const Img._();
  static const logo = 'assets/img/logo.png';

  /// Google-owned multicolor G. This file comes from Google's official
  /// Identity branding asset, not from a locally drawn approximation.
  static const googleG = 'assets/img/google_g.png';

  // ilustrasi flow mockup baru (background transparan)
  static const onboarding = 'assets/img/onboarding.webp';
  static const pairSuccess = 'assets/img/pair_success.webp';
  static const qrScan = 'assets/img/qr_scan.webp';
  static const sessionControls = 'assets/img/session_controls.webp';
  static const emptyDevices = 'assets/img/empty_devices.webp';
  static const billing = 'assets/img/billing.webp';
  static const guideOverview = 'assets/img/guide_overview.webp';
  static const guideClient = 'assets/img/guide_client.webp';
  static const guideHost = 'assets/img/guide_host.webp';

  // status perangkat
  static const pcOnline = 'assets/img/pc_online.webp';
  static const pcOffline = 'assets/img/pc_offline.webp';

  // ilustrasi layar
  static const auth = 'assets/img/il_auth.webp';
  static const settings = 'assets/img/il_settings.webp';
  static const screen = 'assets/img/il_screen.webp';
  static const empty = 'assets/img/empty.webp';
  static const connect = 'assets/img/connect.webp';
  static const error = 'assets/img/error.webp';
  static const gaming = 'assets/img/gaming.webp';

  /// Ilustrasi hero layar Billing (sewa PC) — PNG transparan hasil AI+rembg.
  static const billingHero = 'assets/img/billing_hero.webp';
  static const secure = 'assets/img/secure.webp';
}

/// Logo XyDesk.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 60});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      Img.logo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      // Kalau aset gagal dimuat, jangan sampai layar jadi kosong —
      // tampilkan bentuk pengganti yang tetap rapi.
      errorBuilder: (context, _, __) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.c.raised,
          borderRadius: BorderRadius.circular(size * 0.26),
        ),
        child: Icon(
          LucideIcons.monitor,
          size: size * 0.5,
          color: context.c.textMid,
        ),
      ),
    );
  }
}

/// Logo + wordmark, dipakai di splash dan halaman Tentang.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.size = 60, this.showTagline = true});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(size: size),
        SizedBox(height: size * 0.22),
        Text(
          'XyDesk',
          style: TextStyle(
            fontSize: size * 0.37,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
            color: c.textHi,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 5),
          Text(
            'PC kamu, di tangan kamu',
            style: TextStyle(fontSize: 12.5, color: c.textMid),
          ),
        ],
      ],
    );
  }
}

/// Gambar ilustrasi yang aman gagal — tidak pernah membuat layar kosong.
class Illus extends StatelessWidget {
  const Illus(
    this.asset, {
    super.key,
    this.size = 140,
    this.opacity = 1,
    this.opticalScale = 1,
  });

  final String asset;
  final double size;
  final double opacity;

  /// Compensates for intentional transparent margins without destructively
  /// cropping or re-exporting the clean source artwork.
  final double opticalScale;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: opticalScale,
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
        ),
      ),
    );
  }
}

/// Ilustrasi dengan judul dan keterangan — untuk keadaan kosong & error.
class IllustrationState extends StatelessWidget {
  const IllustrationState({
    super.key,
    required this.asset,
    required this.title,
    this.message,
    this.action,
    this.size = 150,
  });

  final String asset;
  final String title;
  final String? message;
  final Widget? action;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Illus(asset, size: size, opacity: 0.9),
            const SizedBox(height: Gap.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 7),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.55, color: c.textLow),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Gap.lg), action!],
          ],
        ),
      ),
    );
  }
}
