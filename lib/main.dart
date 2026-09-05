import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_version.dart';
import 'core/devlog.dart';
import 'core/pip_controller.dart';
import 'core/store.dart';
import 'features/auth/session_vault.dart';
import 'features/notifications/notification_service.dart';
import 'core/display_control.dart';

void main() {
  // PiP mode callback dari Android native
  const pipChannel = MethodChannel('com.xystudio.xydesk/pip');
  pipChannel.setMethodCallHandler((call) async {
    if (call.method == 'onPipModeChanged') {
      final isInPip = call.arguments as bool;
      PipController.instance.handlePipModeChanged(isInPip);
    }
  });

  // runZonedGuarded menangkap error async yang lolos dari framework,
  // sehingga tidak ada kegagalan diam-diam yang berujung layar kosong.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      DevLog.install();
      // Versi dibaca dari metadata paket, bukan ditulis tangan.
      await AppVersion.load();
      DevLog.i(
        'app',
        'XyDesk mulai',
        'versi ${AppVersion.version}+${AppVersion.build}',
      );

      // Edge-to-edge: background mengalir dari status bar sampai nav bar.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        // Tema terang (Paper): ikon status bar gelap agar selalu terbaca.
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );

      // Hanya membaca kemampuan panel di sini. Penerapannya dilakukan
      // SettingsNotifier memakai preferensi tersimpan pengguna — kalau
      // diterapkan di sini juga, pilihan "hemat baterai" akan ditimpa setiap
      // aplikasi dimulai.
      await DisplayControl.probe();

      final store = await Store.open();
      final sessionVault = SecureSessionVault();
      String? initialToken;
      try {
        initialToken = await sessionVault.readToken().timeout(
          const Duration(seconds: 10),
        );
      } catch (error, stack) {
        // Secure storage dapat gagal bila OS belum siap/penyimpanan rusak.
        // Aplikasi tetap dibuka, tetapi meminta pengguna masuk kembali.
        DevLog.e('auth', 'Gagal membaca sesi aman', error, stack);
      }

      runApp(
        ProviderScope(
          overrides: [
            storeProvider.overrideWithValue(store),
            sessionVaultProvider.overrideWithValue(sessionVault),
            initialAuthTokenProvider.overrideWithValue(initialToken),
          ],
          child: const XyDeskApp(),
        ),
      );

      // Push disiapkan SETELAH frame pertama tampil, bukan sebelumnya.
      // Dulu ini ditunggu sebelum `runApp`, sehingga satu panggilan SDK
      // yang tidak pernah menjawab membuat aplikasi berhenti di layar
      // peluncuran tanpa batas — tanpa galat, tanpa jejak. Menyiapkannya
      // di sini membuat aplikasi selalu terbuka; kalau push gagal, status
      // izinnya tampil di Pengaturan dan bisa dicoba lagi di sana.
      unawaited(NotificationService.instance.initialize());
    },
    (error, stack) {
      DevLog.fatal('zone', 'Error di luar framework', error, stack);
    },
  );
}
