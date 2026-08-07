import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xydesk/app.dart';
import 'package:xydesk/core/store.dart';
import 'package:xydesk/core/theme.dart';

/// Menyiapkan Store berbasis SharedPreferences tiruan untuk pengujian.
Future<Store> testStore({Map<String, Object> seed = const {}}) async {
  SharedPreferences.setMockInitialValues({
    // Anggap sudah masuk supaya test langsung sampai ke AppShell,
    // bukan tertahan di layar masuk.
    'user_guest': true,
    ...seed,
  });
  return Store.open();
}

/// Membungkus aplikasi lengkap dengan Store tiruan.
Future<Widget> testApp({Map<String, Object> seed = const {}}) async {
  final store = await testStore(seed: seed);
  return ProviderScope(
    overrides: [storeProvider.overrideWithValue(store)],
    child: const XyDeskApp(),
  );
}

/// Membungkus satu widget dengan tema dan Store tiruan.
Future<Widget> testWrap(Widget child,
    {Map<String, Object> seed = const {}}) async {
  final store = await testStore(seed: seed);
  return ProviderScope(
    overrides: [storeProvider.overrideWithValue(store)],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}
