import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/tokens.dart';
import '../features/news/news_avatar.dart';
import 'brand.dart';

/// Nama penulis dengan badge resmi XyDesk.
///
/// ## Kenapa badge ini ada, dan kenapa bentuknya begini
///
/// Di kolom komentar, nama adalah satu-satunya identitas. Tanpa penanda,
/// siapa pun bisa mengetik "Haekal Saputra" dan pembaca tidak punya cara
/// membedakannya dari yang asli — persis pola penipuan yang justru
/// diperingatkan XyDesk di halaman Ketentuan.
///
/// Dua lapis pertahanannya ada di server (`news/src/worker.js`):
///   1. Badge hanya diberikan bila request membawa `ADMIN_TOKEN`.
///   2. Nama tim dikunci: komentar publik yang memakainya DITOLAK, bukan
///      sekadar tampil tanpa badge — karena pembaca sekilas membaca nama,
///      bukan ketiadaan lencana.
///
/// Widget ini hanya menggambar hasil keputusan itu. Ia tidak pernah menebak
/// dari nama; kalau `official` salah, tidak ada badge.
///
/// Sejak rebrand, penanda resmi memakai foto pendiri XySpace
/// (samakan dengan web) — bukan lagi badge logo X.
class AuthorName extends StatelessWidget {
  const AuthorName({
    super.key,
    required this.name,
    this.official = false,
    this.trailing,
    this.fontSize = 13,
  });

  final String name;
  final bool official;

  /// Teks tambahan setelah nama, mis. tanggal.
  final String? trailing;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final suffix = trailing == null ? '' : ' · $trailing';

    if (!official) {
      return Text(
        '$name$suffix',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: c.textHi,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: Image.network(
            newsFounderAvatar,
            width: fontSize + 4,
            height: fontSize + 4,
            fit: BoxFit.cover,
            // Kalau gagal (mis. offline), jangan kosongkan baris penulis —
            // kembalikan ke logo agar identitas resmi tetap terbaca.
            errorBuilder: (_, __, ___) => Image.asset(
              Img.logo,
              width: fontSize + 4,
              height: fontSize + 4,
              fit: BoxFit.contain,
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Image.asset(
                Img.logo,
                width: fontSize + 4,
                height: fontSize + 4,
                fit: BoxFit.contain,
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: c.textHi,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(R.pill),
          ),
          child: Text(
            'RESMI',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: c.accent,
            ),
          ),
        ),
        if (suffix.isNotEmpty)
          Flexible(
            child: Text(
              suffix,
              style: TextStyle(fontSize: fontSize - 1.5, color: c.textLow),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// Avatar bulat komentator — meniru web (`web/src/App.tsx`).
///
/// Resmi memakai foto pendiri; selainnya DiceBear SVG dari nama penulis
/// ([newsAvatarUrl]). Bentuknya bulat dan tidak pernah membuat baris gagal:
/// kalau gambar tidak termuat, tampilkan siluet netral, bukan layar kosong.
class CommentAvatar extends StatelessWidget {
  const CommentAvatar({
    super.key,
    required this.author,
    this.official = false,
    this.size = 34,
  });

  final String author;

  /// Ditetapkan server, bukan tebakan klien — lihat [AuthorName].
  final bool official;

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    Widget fallback() =>
        Icon(LucideIcons.user, size: size * 0.5, color: c.textLow);

    final Widget inner = official
        ? Image.network(
            newsFounderAvatar,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return fallback();
            },
          )
        // DiceBear mengembalikan SVG, jadi pakai flutter_svg (bukan
        // Image.network yang hanya bisa PNG/JPEG).
        : SvgPicture.network(
            newsAvatarUrl(author),
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholderBuilder: (_) => fallback(),
          );

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: c.overlay,
        alignment: Alignment.center,
        child: inner,
      ),
    );
  }
}
