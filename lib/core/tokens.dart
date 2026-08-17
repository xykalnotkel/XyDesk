import 'package:flutter/material.dart';

/// Token desain XyDesk — "Quiet Surface".
///
/// Sumber kebenaran tunggal untuk warna, jarak, radius, dan durasi.
/// Semua nilai di sini cocok dengan `docs/DESIGN.md`.
class AppColors {
  const AppColors._();

  // ── Dark: "Graphite" ──
  static const bgDark = Color(0xFF131315);
  static const raisedDark = Color(0xFF1B1B1E);
  static const overlayDark = Color(0xFF232326);
  static const inputDark = Color(0xFF202023);
  static const accentDark = Color(0xFF5B7FE8);
  static const textHiDark = Color(0xFFEDEDEF);
  static const textMidDark = Color(0xFFA0A0A8);
  static const textLowDark = Color(0xFF6B6B73);

  // ── Light: "Paper" ──
  static const bgLight = Color(0xFFFAFAF9);
  static const raisedLight = Color(0xFFFFFFFF);
  static const overlayLight = Color(0xFFFFFFFF);
  static const inputLight = Color(0xFFF2F2F0);
  static const accentLight = Color(0xFF3D63D8);
  static const textHiLight = Color(0xFF18181B);
  static const textMidLight = Color(0xFF52525B);
  static const textLowLight = Color(0xFF9A9AA2);

  // ── Semantic (desaturasi, sama di dua mode) ──
  static const success = Color(0xFF4FA97A);
  static const warning = Color(0xFFC9963F);
  static const danger = Color(0xFFD9646E);

  // Varian teks untuk latar terang. Warna status dasar di atas dirancang
  // untuk Graphite; jika dipakai sebagai teks di Paper kontrasnya terlalu
  // rendah. Token terpisah mencegah layar memilih warna mentah sendiri.
  static const successTextLight = Color(0xFF167347);
  static const warningTextLight = Color(0xFF855400);
  static const dangerTextLight = Color(0xFFA52A36);
}

/// Warna yang bergantung tema, diambil lewat `context.c`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.raised,
    required this.overlay,
    required this.input,
    required this.accent,
    required this.textHi,
    required this.textMid,
    required this.textLow,
    required this.successText,
    required this.warningText,
    required this.dangerText,
  });

  final Color bg, raised, overlay, input, accent, textHi, textMid, textLow;
  final Color successText, warningText, dangerText;

  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get danger => AppColors.danger;

  /// Isi aksen sangat halus — dipakai untuk pil indikator nav & modifier aktif.
  Color get accentSoft => accent.withValues(alpha: 0.12);

  static const dark = AppPalette(
    bg: AppColors.bgDark,
    raised: AppColors.raisedDark,
    overlay: AppColors.overlayDark,
    input: AppColors.inputDark,
    accent: AppColors.accentDark,
    textHi: AppColors.textHiDark,
    textMid: AppColors.textMidDark,
    textLow: AppColors.textLowDark,
    successText: AppColors.success,
    warningText: AppColors.warning,
    dangerText: AppColors.danger,
  );

  static const light = AppPalette(
    bg: AppColors.bgLight,
    raised: AppColors.raisedLight,
    overlay: AppColors.overlayLight,
    input: AppColors.inputLight,
    accent: AppColors.accentLight,
    textHi: AppColors.textHiLight,
    textMid: AppColors.textMidLight,
    textLow: AppColors.textLowLight,
    successText: AppColors.successTextLight,
    warningText: AppColors.warningTextLight,
    dangerText: AppColors.dangerTextLight,
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? raised,
    Color? overlay,
    Color? input,
    Color? accent,
    Color? textHi,
    Color? textMid,
    Color? textLow,
    Color? successText,
    Color? warningText,
    Color? dangerText,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      raised: raised ?? this.raised,
      overlay: overlay ?? this.overlay,
      input: input ?? this.input,
      accent: accent ?? this.accent,
      textHi: textHi ?? this.textHi,
      textMid: textMid ?? this.textMid,
      textLow: textLow ?? this.textLow,
      successText: successText ?? this.successText,
      warningText: warningText ?? this.warningText,
      dangerText: dangerText ?? this.dangerText,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      input: Color.lerp(input, other.input, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textHi: Color.lerp(textHi, other.textHi, t)!,
      textMid: Color.lerp(textMid, other.textMid, t)!,
      textLow: Color.lerp(textLow, other.textLow, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
    );
  }
}

extension PaletteX on BuildContext {
  AppPalette get c => Theme.of(this).extension<AppPalette>()!;
}

/// Skala jarak kelipatan 4.
class Gap {
  const Gap._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const h32 = 32.0;
  static const h40 = 40.0;
  static const h56 = 56.0;

  /// Padding horizontal standar layar.
  static const screen = 20.0;
}

/// Radius — lebih kecil dari versi neon agar terasa presisi.
class R {
  const R._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;

  /// Keyboard virtual sengaja hampir kotak (3dp), bukan membulat.
  static const key = 3.0;
  static const pill = 999.0;
}

/// Durasi interaksi utama ≤ 280ms, tanpa bounce. `fade` sengaja lebih lama
/// karena dipakai untuk transisi opacity, bukan umpan balik sentuh.
class D {
  const D._();
  static const fast = Duration(milliseconds: 120);
  static const tab = Duration(milliseconds: 220);
  static const panel = Duration(milliseconds: 260);
  static const sheet = Duration(milliseconds: 240);
  static const fade = Duration(milliseconds: 400);

  /// Overlay sesi memudar setelah diam selama ini.
  static const idleHide = Duration(seconds: 3);

  static const curve = Curves.easeOutCubic;
}
