import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/devlog.dart';
import 'core/responsive.dart';
import 'core/store.dart';
import 'features/auth/session_vault.dart';
import 'features/notifications/notification_service.dart';

void main() {
  // runZonedGuarded menangkap error async yang lolos dari framework,
  // sehingga tidak ada kegagalan diam-diam yang berujung layar kosong.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      DevLog.install();
      DevLog.i('app', 'XyDesk mulai', 'versi 1.2.0+4');

      // Edge-to-edge: background mengalir dari status bar sampai nav bar.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );

      await DisplayMode.useHighestRefreshRate();
      DevLog.i('display', 'Refresh rate', '${DisplayMode.current.round()} Hz');

      // Menyiapkan push tanpa menampilkan dialog izin pada peluncuran awal.
      await NotificationService.instance.initialize();

      final store = await Store.open();
      final sessionVault = SecureSessionVault();
      String? initialToken;
      try {
        initialToken = await sessionVault.readToken();
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
    },
    (error, stack) {
      DevLog.fatal('zone', 'Error di luar framework', error, stack);
    },
  );
}
