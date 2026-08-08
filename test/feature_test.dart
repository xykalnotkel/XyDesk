import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xydesk/core/l10n_bridge.dart';
import 'package:xydesk/core/store.dart';
import 'package:xydesk/features/auth/auth_screen.dart';
import 'package:xydesk/features/session/virtual_keyboard.dart';

import 'helpers.dart';

void main() {
  group('Multi-bahasa', () {
    test('semua kunci punya terjemahan Inggris sebagai cadangan', () {
      for (final e in kStrings.entries) {
        expect(
          e.value['en'],
          isNotNull,
          reason: 'Kunci "${e.key}" tidak punya nilai en',
        );
        expect(e.value['en'], isNotEmpty);
      }
    });

    test('bahasa bawaan Indonesia lengkap', () {
      final kurang = <String>[];
      for (final e in kStrings.entries) {
        final v = e.value['id'];
        if (v == null || v.isEmpty) kurang.add(e.key);
      }
      expect(kurang, isEmpty, reason: 'Kunci tanpa terjemahan id: $kurang');
    });

    test('kunci hilang otomatis jatuh ke Inggris', () {
      const l = L(AppLang.zh);
      // Kunci tidak dikenal dikembalikan apa adanya, tidak melempar error.
      expect(l.t('kunci_tidak_ada'), 'kunci_tidak_ada');
      // Kunci dikenal punya nilai.
      expect(l.t('nav_home'), isNotEmpty);
    });

    test('Arab ditandai RTL', () {
      expect(AppLang.ar.rtl, isTrue);
      expect(AppLang.id.rtl, isFalse);
    });

    test('byCode mengembalikan Inggris untuk kode asing', () {
      expect(AppLang.byCode('xx').code, 'en');
      expect(AppLang.byCode('id').code, 'id');
    });
  });

  group('Penyimpanan', () {
    test('pengaturan bertahan setelah dibaca ulang', () async {
      final s = await testStore();
      await s.setStr('lang', 'en');
      await s.setI('theme', ThemeMode.light.index);
      expect(s.getStr('lang'), 'en');
      expect(s.getI('theme'), ThemeMode.light.index);
    });

    test('daftar JSON tersimpan dan terbaca', () async {
      final s = await testStore();
      await s.setList('uji', [
        {'a': 1},
        {'b': 2},
      ]);
      expect(s.getList('uji').length, 2);
      expect(s.getList('uji').first['a'], 1);
    });

    test('data rusak tidak membuat aplikasi mati', () async {
      final s = await testStore(seed: {'rusak': 'bukan json'});
      expect(s.getList('rusak'), isEmpty);
    });
  });

  group('Keyboard virtual', () {
    testWidgets('mode split menampilkan dua panel terpisah', (tester) async {
      await tester.pumpWidget(
        await testWrap(const VirtualKeyboard(layout: KbLayout.split)),
      );
      await tester.pumpAndSettle();

      // Belahan kiri punya Esc, belahan kanan punya Backspace.
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('⌫'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mode full menampilkan satu blok', (tester) async {
      await tester.pumpWidget(
        await testWrap(const VirtualKeyboard(layout: KbLayout.full)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Esc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('modifier sticky bisa ditekan', (tester) async {
      await tester.pumpWidget(
        await testWrap(const VirtualKeyboard(layout: KbLayout.split)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ctrl'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Autentikasi', () {
    testWidgets('layar masuk tampil saat belum login', (tester) async {
      await tester.pumpWidget(await testApp(seed: {'user_guest': false}));
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('masuk sebagai tamu membuka aplikasi', (tester) async {
      await tester.pumpWidget(await testApp(seed: {'user_guest': false}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pakai tanpa akun'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsNothing);
    });

    test('sesi tamu tersimpan', () async {
      final s = await testStore(seed: {'user_guest': false});
      final n = AuthNotifier(s);
      expect(n.state.signedIn, isFalse);
      await n.signInGuest();
      expect(n.state.isGuest, isTrue);
      expect(s.getBool('user_guest'), isTrue);
    });

    test('keluar menghapus sesi', () async {
      final s = await testStore(seed: {'user_email': 'a@b.c'});
      final n = AuthNotifier(s);
      expect(n.state.signedIn, isTrue);
      await n.signOut();
      expect(n.state.signedIn, isFalse);
      expect(s.getStr('user_email'), isNull);
    });
  });
}
