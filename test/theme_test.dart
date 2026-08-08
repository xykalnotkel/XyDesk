import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xydesk/core/theme.dart';
import 'package:xydesk/core/tokens.dart';

void main() {
  group('Aturan seamless — nol garis pemisah', () {
    for (final entry in {
      'dark': AppTheme.dark(),
      'light': AppTheme.light(),
    }.entries) {
      final name = entry.key;
      final theme = entry.value;

      test('[$name] AppBar tidak memunculkan garis saat konten discroll', () {
        expect(
          theme.appBarTheme.scrolledUnderElevation,
          0,
          reason:
              'scrolledUnderElevation > 0 menghasilkan garis di bawah topbar',
        );
        expect(theme.appBarTheme.elevation, 0);
        expect(theme.appBarTheme.backgroundColor, Colors.transparent);
        expect(
          theme.appBarTheme.surfaceTintColor,
          Colors.transparent,
          reason:
              'surfaceTintColor M3 memunculkan warna tint yang terlihat seperti garis',
        );
      });

      test('[$name] NavigationBar transparan tanpa elevasi', () {
        expect(theme.navigationBarTheme.backgroundColor, Colors.transparent);
        expect(theme.navigationBarTheme.elevation, 0);
        expect(theme.navigationBarTheme.surfaceTintColor, Colors.transparent);
      });

      test('[$name] Divider dimatikan sepenuhnya', () {
        expect(theme.dividerTheme.color, Colors.transparent);
        expect(theme.dividerTheme.thickness, 0);
        expect(theme.dividerTheme.space, 0);
      });

      test('[$name] Input tanpa border; fokus memakai ring 1px', () {
        final dec = theme.inputDecorationTheme;
        expect(
          (dec.enabledBorder as OutlineInputBorder).borderSide,
          BorderSide.none,
        );
        final focused = dec.focusedBorder as OutlineInputBorder;
        expect(
          focused.borderSide.width,
          1,
          reason: 'Fokus harus ring tipis 1px, bukan glow tebal',
        );
      });

      test('[$name] Card tanpa elevasi', () {
        expect(theme.cardTheme.elevation, 0);
      });
    }
  });

  group('Token warna', () {
    test('Palet dark & light tersedia lewat ThemeExtension', () {
      expect(AppTheme.dark().extension<AppPalette>(), isNotNull);
      expect(AppTheme.light().extension<AppPalette>(), isNotNull);
    });

    test('Tidak memakai pure black atau pure white', () {
      const d = AppPalette.dark;
      const l = AppPalette.light;
      expect(d.bg, isNot(const Color(0xFF000000)));
      expect(l.bg, isNot(const Color(0xFFFFFFFF)));
    });

    test('Beda luminansi antar permukaan bertetangga sangat halus', () {
      // Aturan desain: perbedaan ≤ 4% agar tidak terbaca sebagai "garis".
      final bg = AppPalette.dark.bg.computeLuminance();
      final raised = AppPalette.dark.raised.computeLuminance();
      expect((raised - bg).abs(), lessThan(0.04));
    });

    test('Kontras teks memenuhi WCAG AA (>= 4.5:1)', () {
      double ratio(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(
        ratio(AppPalette.dark.textMid, AppPalette.dark.bg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        ratio(AppPalette.light.textMid, AppPalette.light.bg),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Token gerak', () {
    test('Semua animasi <= 280ms dan tanpa bounce', () {
      for (final d in [D.fast, D.tab, D.panel, D.sheet]) {
        expect(d.inMilliseconds, lessThanOrEqualTo(280));
      }
      expect(D.curve, Curves.easeOutCubic);
    });

    test('Overlay sesi memudar setelah 3 detik', () {
      expect(D.idleHide, const Duration(seconds: 3));
    });
  });

  test('Radius tombol keyboard hampir kotak (3dp)', () {
    // Permintaan desain: keyboard tidak boleh terlalu membulat.
    expect(R.key, 3.0);
    expect(R.key, lessThan(R.sm));
  });
}
