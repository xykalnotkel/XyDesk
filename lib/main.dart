import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/devlog.dart';

void main() {
  // runZonedGuarded menangkap error async yang lolos dari framework,
  // sehingga tidak ada lagi kegagalan diam-diam yang berujung layar kosong.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    DevLog.install();
    DevLog.i('app', 'XyDesk mulai', 'versi 1.0.0+1');

    // Edge-to-edge: background mengalir dari status bar sampai navigation bar.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ));

    runApp(const ProviderScope(child: XyDeskApp()));
  }, (error, stack) {
    DevLog.fatal('zone', 'Error di luar framework', error, stack);
  });
}
