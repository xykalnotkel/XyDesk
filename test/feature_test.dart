import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xydesk/core/l10n_bridge.dart';
import 'package:xydesk/core/store.dart';
import 'package:xydesk/features/auth/auth_screen.dart';
import 'package:xydesk/features/devices/device_model.dart';
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

  group('Demo flow lokal', () {
    test('pairing menyimpan perangkat baru dan membuatnya online', () async {
      final s = await testStore();
      final repo = DeviceRepo(s);

      final device = await repo.connect(
        id: '987654321',
        name: 'PC-DEMO',
        remembered: true,
      );

      expect(device.isOnline, isTrue);
      expect(device.remembered, isTrue);
      expect(repo.state.any((d) => d.id == '987654321'), isTrue);
      expect(
        s.getList('devices').any((d) => d['id'] == '987654321'),
        isTrue,
      );
    });

    test('riwayat sesi tersimpan dan muncul paling baru', () async {
      final s = await testStore();
      final repo = HistoryRepo(s);
      final at = DateTime(2026, 8, 8, 12);

      await repo.add(
        SessionRecord(
          deviceId: '987654321',
          deviceName: 'PC-DEMO',
          at: at,
          durationMin: 12,
          path: 'P2P',
          quality: '1080p60',
        ),
      );

      expect(repo.state.single.deviceName, 'PC-DEMO');
      expect(repo.state.single.durationMin, 12);
      expect(s.getList('history').single['path'], 'P2P');
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

    test('sesi backend membutuhkan JWT dan keluar menghapus sesi', () async {
      final s = await testStore(
        seed: {'user_guest': false, 'user_email': 'a@b.c'},
      );
      final tanpaToken = AuthNotifier(s);
      expect(tanpaToken.state.signedIn, isFalse);

      await s.setStr('user_email', 'a@b.c');
      final n = AuthNotifier(s, initialToken: 'jwt-test');
      expect(n.state.signedIn, isTrue);
      expect(n.state.token, 'jwt-test');
      await n.signOut();
      expect(n.state.signedIn, isFalse);
      expect(s.getStr('user_email'), isNull);
    });

    test('profil /auth/me dapat memulihkan metadata dari JWT saja', () async {
      final s = await testStore(seed: {'user_guest': false});
      final n = AuthNotifier(s, initialToken: 'restored-jwt');
      expect(n.state.signedIn, isFalse);
      expect(n.state.token, 'restored-jwt');

      await n.refreshAuthenticatedProfile(
        email: 'pulih@example.com',
        name: 'Pulih',
      );

      expect(n.state.signedIn, isTrue);
      expect(n.state.email, 'pulih@example.com');
      expect(n.state.name, 'Pulih');
      expect(n.state.token, 'restored-jwt');
      expect(s.getStr('user_email'), 'pulih@example.com');
    });
  });
}
