import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/devlog.dart';
import 'core/responsive.dart';
import 'core/store.dart';

void main() {
  // runZonedGuarded menangkap error async yang lolos dari framework,
  // sehingga tidak ada kegagalan diam-diam yang berujung layar kosong.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      DevLog.install();
      DevLog.i('app', 'XyDesk mulai', 'versi 1.0.0+2');

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

      final store = await Store.open();

      runApp(
        ProviderScope(
          overrides: [storeProvider.overrideWithValue(store)],
          child: const XyDeskApp(),
        ),
      );
    },
    (error, stack) {
      DevLog.fatal('zone', 'Error di luar framework', error, stack);
    },
  );
}
