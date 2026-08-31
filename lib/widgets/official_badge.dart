import 'package:flutter/material.dart';

import '../core/tokens.dart';
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
        Image.asset(
          Img.logo,
          width: fontSize + 4,
          height: fontSize + 4,
          fit: BoxFit.contain,
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
