import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xydesk/app.dart';
import 'package:xydesk/core/theme.dart';
import 'package:xydesk/features/connect/connect_page.dart';
import 'package:xydesk/widgets/hud_glyphs.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(theme: AppTheme.dark(), home: Scaffold(body: child)),
    );

void main() {
  testWidgets('Aplikasi menyala dan menampilkan bottom-nav', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: XyDeskApp()));
    await tester.pumpAndSettle();

    expect(find.text('Perangkat'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('GAMING-RIG'), findsOneWidget);
  });

  testWidgets('Tidak ada Divider di layar utama', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: XyDeskApp()));
    await tester.pumpAndSettle();

    // Aturan "nol garis pemisah" diverifikasi otomatis, bukan sekadar niat.
    expect(find.byType(Divider), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets('Pindah tab ke Connect', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: XyDeskApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Hubungkan ke perangkat'), findsOneWidget);
    expect(find.text('Dukung kami di'), findsOneWidget);
  });

  group('DeviceIdFormatter', () {
    final f = DeviceIdFormatter();

    TextEditingValue apply(String s) => f.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: s),
        );

    test('menyisipkan spasi setelah digit ke-3 dan ke-6', () {
      expect(apply('123456789').text, '123 456 789');
      expect(apply('1234').text, '123 4');
    });

    test('membuang karakter non-digit', () {
      expect(apply('12a34b').text, '123 4');
    });

    test('membatasi maksimal 9 digit', () {
      expect(apply('1234567890123').text, '123 456 789');
    });
  });

  testWidgets('Tombol Hubungkan nonaktif sampai form valid', (tester) async {
    await tester.pumpWidget(_wrap(const ConnectPage()));
    await tester.pumpAndSettle();

    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull,
        reason: 'Form kosong harus menonaktifkan tombol');

    await tester.enterText(find.byType(TextField).first, '123456789');
    await tester.enterText(find.byType(TextField).last, 'rahasia');
    await tester.pumpAndSettle();

    final btn2 = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn2.onPressed, isNotNull);
  });

  group('Glyph HUD', () {
    testWidgets('semua glyph tergambar tanpa error', (tester) async {
      for (final g in HudGlyph.values) {
        await tester.pumpWidget(_wrap(Center(child: HudIcon(g, size: 40))));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Glyph $g gagal digambar');
      }
    });

    testWidgets('HudButton menampilkan label dan bereaksi saat ditekan',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(Center(
        child: HudButton(
          glyph: HudGlyph.mouseLeft,
          label: 'Kiri',
          onTap: () => tapped = true,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Kiri'), findsOneWidget);
      await tester.tap(find.byType(HudButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('HudButton berlatar transparan saat diam (border-only)',
        (tester) async {
      await tester.pumpWidget(_wrap(const Center(
        child: HudButton(glyph: HudGlyph.dpad, label: 'D-Pad'),
      )));
      await tester.pumpAndSettle();

      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HudButton),
              matching: find.byType(Container),
            )
            .first,
      );
      final dec = box.decoration as BoxDecoration;
      // Isi harus transparan agar piksel game tetap terlihat.
      expect(dec.color, Colors.transparent);
      expect(dec.border, isNotNull);
    });
  });
}
