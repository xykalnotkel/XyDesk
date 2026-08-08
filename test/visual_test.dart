import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'helpers.dart';
import 'package:xydesk/core/devlog.dart';
import 'package:xydesk/core/theme.dart';
import 'package:xydesk/features/session/session_page.dart';

/// Test yang memverifikasi keluhan nyata: "UI beda jauh dari mockup" dan
/// "pas pencet lanjut sesi malah putih doang".
void main() {
  group('Kecocokan dengan mockup', () {
    test('Font Inter dipakai di kedua tema', () {
      // Sebelumnya kosong -> Flutter memakai Roboto, sehingga seluruh
      // tampilan terasa berbeda dari mockup meski warnanya sama.
      expect(AppTheme.dark().textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(AppTheme.dark().appBarTheme.titleTextStyle?.fontFamily, 'Inter');
    });

    testWidgets('Ikon memakai Lucide, bukan Material', (tester) async {
      await tester.pumpWidget(await testApp());
      await tester.pumpAndSettle();

      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((w) => w.icon)
          .whereType<IconData>()
          .toList();

      expect(icons, isNotEmpty);
      // Semua ikon harus berasal dari font Lucide.
      for (final i in icons) {
        expect(
          i.fontFamily,
          contains('Lucide'),
          reason: 'Ikon $i bukan Lucide — tampilan akan beda dari mockup',
        );
      }
    });

    testWidgets('Ikon nav aktif tidak berwarna aksen', (tester) async {
      await tester.pumpWidget(await testApp());
      await tester.pumpAndSettle();
      // Aturan desain: satu titik perhatian per layar.
      final theme = AppTheme.dark();
      final sel = theme.navigationBarTheme.iconTheme?.resolve({
        WidgetState.selected,
      })?.color;
      expect(sel, const Color(0xFFEDEDEF));
    });
  });

  group('Bug layar putih saat masuk sesi', () {
    testWidgets('SessionPage menampilkan layar loading, bukan kosong', (
      tester,
    ) async {
      await tester.pumpWidget(
        await testWrap(
          const SessionPage(deviceName: 'GAMING-RIG', deviceId: '123 456 789'),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Menghubungkan'), findsOneWidget);
      expect(find.textContaining('Menemukan host'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tuntaskan Timer simulasi agar tidak ada timer menggantung.
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pumpAndSettle();
    });

    testWidgets('Setelah loading, placeholder terbaca jelas', (tester) async {
      await tester.pumpWidget(
        await testWrap(
          const SessionPage(deviceName: 'GAMING-RIG', deviceId: '123 456 789'),
        ),
      );
      // Lewati simulasi koneksi 2,2 detik.
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump();

      // Layar tidak boleh kosong — harus ada penjelasan.
      expect(find.textContaining('Layar remote akan tampil'), findsOneWidget);
      expect(find.textContaining('mode demo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tombol keyboard & panel bisa dibuka di sesi', (tester) async {
      await tester.pumpWidget(
        await testWrap(
          const SessionPage(deviceName: 'GAMING-RIG', deviceId: '123 456 789'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump();

      // FAB keyboard ada
      expect(find.byIcon(LucideIcons.keyboard), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.keyboard));
      await tester.pumpAndSettle();
      // Beberapa tombol keyboard muncul
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('Ctrl'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DevLog', () {
    setUp(DevLog.clear);

    test('mencatat dan mengekspor', () {
      DevLog.i('tes', 'pesan info');
      DevLog.e('tes', 'pesan error', Exception('contoh'));

      expect(DevLog.entries.length, 2);
      expect(DevLog.errorCount.value, 1);

      final teks = DevLog.export();
      expect(teks, contains('XyDesk DevLog'));
      expect(teks, contains('pesan info'));
      expect(teks, contains('pesan error'));
    });

    test('membatasi jumlah baris agar memori tidak membengkak', () {
      for (var i = 0; i < 900; i++) {
        DevLog.d('spam', 'baris $i');
      }
      expect(DevLog.entries.length, lessThanOrEqualTo(800));
    });

    testWidgets('FAB DevLog tampil di layar utama', (tester) async {
      await tester.pumpWidget(await testApp());
      await tester.pumpAndSettle();
      expect(find.byType(DevLogFab), findsOneWidget);
    });
  });
}
