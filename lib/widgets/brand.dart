import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Aset gambar aplikasi.
///
/// Ilustrasi memakai WebP karena jauh lebih kecil dari PNG pada gambar
/// line-art (~60% lebih ringan), sementara logo tetap PNG agar tepinya
/// tetap tajam saat dipakai di ukuran kecil.
class Img {
  const Img._();
  static const logo = 'assets/img/logo.png';
  static const empty = 'assets/img/empty.webp';
  static const connect = 'assets/img/connect.webp';
  static const error = 'assets/img/error.webp';
  static const gaming = 'assets/img/gaming.webp';
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
      filterQuality: FilterQuality.medium,
      // Kalau aset gagal dimuat, jangan sampai layar jadi kosong —
      // tampilkan bentuk pengganti yang tetap rapi.
      errorBuilder: (context, _, __) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.c.raised,
          borderRadius: BorderRadius.circular(size * 0.26),
        ),
        child: Icon(Icons.desktop_windows_outlined,
            size: size * 0.5, color: context.c.textMid),
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

/// Ilustrasi dengan judul dan keterangan — dipakai untuk keadaan kosong,
/// error, dan layar penjelasan.
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
            Opacity(
              opacity: 0.9,
              child: Image.asset(
                asset,
                width: size,
                height: size,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => SizedBox(height: size),
              ),
            ),
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
            if (action != null) ...[
              const SizedBox(height: Gap.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
