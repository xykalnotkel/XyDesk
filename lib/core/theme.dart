
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Tema XyDesk.
///
/// Aturan utama: **nol garis pemisah**. Semua sumber garis bawaan Material
/// dimatikan di sini supaya tidak perlu diakali per-widget:
///   • `surfaceTintColor` transparan  → hilangkan tint M3
///   • `scrolledUnderElevation: 0`    → hilangkan garis saat konten discroll
///   • `DividerThemeData` transparan  → hilangkan semua Divider
class AppTheme {
  const AppTheme._();

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Inter di-bundle di assets — sama persis dengan mockup.
      fontFamily: 'Inter',
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
      ).copyWith(surface: p.bg, primary: p.accent, error: AppColors.danger),
    );

    return base.copyWith(
      extensions: [p],
      textTheme: _textTheme(base.textTheme, p).apply(fontFamily: 'Inter'),

      // ── Seamless: topbar tanpa garis, tanpa tint ──
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: p.textMid, size: 20),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: p.textHi,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
      ),

      // ── Seamless: bottom nav menyatu dengan background ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 62,
        indicatorColor: p.accentSoft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          return IconThemeData(size: 19, color: on ? p.textHi : p.textLow);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            // Item aktif memakai textHi, BUKAN aksen — supaya tidak ada
            // dua titik perhatian di satu layar.
            color: on ? p.textHi : p.textLow,
          );
        }),
      ),

      // ── Nol garis pemisah ──
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        space: 0,
        thickness: 0,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: p.textMid,
        textColor: p.textHi,
        minVerticalPadding: 10,
        contentPadding: EdgeInsets.zero,
      ),

      cardTheme: CardThemeData(
        color: p.raised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.lg),
        ),
      ),

      // ── Input: tanpa border; fokus = ring 1px, bukan glow ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.input,
        hintStyle: TextStyle(color: p.textLow, fontSize: 14),
        constraints: const BoxConstraints(minHeight: 56),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: p.accent, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 11.5),
      ),

      // ── Tombol: solid, TANPA gradient, FULLY ROUNDED ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          // Nonaktif harus jelas terbaca sebagai nonaktif — 0.38 masih
          // terlihat seperti tombol aktif di layar OLED.
          disabledBackgroundColor: p.accent.withValues(alpha: 0.20),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: p.textHi,
          side: BorderSide(color: p.textLow.withValues(alpha: 0.30)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p.accent
              : const Color(0xFF3A3A3E),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        trackOutlineWidth: WidgetStateProperty.all(0),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.textLow.withValues(alpha: 0.25),
        thumbColor: Colors.white,
        overlayColor: p.accent.withValues(alpha: 0.10),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.overlay,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.lg),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.overlay,
        contentTextStyle: TextStyle(color: p.textHi, fontSize: 12.5),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.lg),
        ),
      ),

      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, AppPalette p) {
    return base.copyWith(
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: p.textHi,
      ),
      headlineMedium: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: p.textHi,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: p.textHi,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: p.textHi),
      bodyMedium: TextStyle(fontSize: 14, color: p.textMid),
      bodySmall: TextStyle(fontSize: 12, color: p.textLow),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: p.textHi,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: p.textMid,
      ),
    );
  }
}
