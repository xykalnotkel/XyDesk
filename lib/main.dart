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
import 'features/splash/boot_screen.dart';

/// Batas waktu untuk setiap langkah inisialisasi.
///
/// Sepuluh detik jauh lebih lama dari yang dibutuhkan kondisi normal
/// (paling lama hitungan milidetik) dan jauh lebih cepat dari kesabaran
/// seseorang yang menatap layar tanpa tahu apa yang terjadi.
const Duration _initTimeout = Duration(seconds: 10);

/// Menjalankan satu langkah inisialisasi tanpa pernah menahan aplikasi.
///
/// Kegagalan dicatat, lalu dilanjut — lebih baik kehilangan satu fitur
/// daripada kehilangan seluruh aplikasi.
Future<void> _initStep(String name, Future<void> work) async {
  try {
    await work.timeout(_initTimeout);
  } catch (error, stack) {
    DevLog.e('boot', 'Inisialisasi $name dilewati', '$error\n$stack');
  }
}

/// Menjalankan aplikasi.
///
/// **Urutan di sini menentukan apakah aplikasi bisa dibuka atau tidak.**
/// Splash native Android (`LaunchTheme`) bertahan sampai Flutter menggambar
/// frame pertamanya. Karena itu tidak boleh ada satu pun `await` sebelum
/// `runApp`: sekali ada panggilan platform yang tidak pernah menjawab,
/// pengguna terkunci di splash — tanpa crash, tanpa galat, tanpa tombol.
///
/// Maka urutannya: gambar frame pertama ([XyDeskBootScreen]) → jalankan
/// semua inisialisasi dengan batas waktu → ganti dengan aplikasi
/// sebenarnya. Kalau ada yang gagal total, tampilkan [XyDeskBootError]
/// dengan tombol coba lagi.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  DevLog.install();

  // 1. Frame pertama. Splash native dilepas pada titik ini, jadi semua
  //    kegagalan di bawah terjadi di dalam Flutter, bukan di layar mati.
  runApp(const XyDeskBootScreen());

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

  // 2. Versi dibaca dari metadata paket — panggilan platform.
  await _initStep('versi', AppVersion.load());
  DevLog.i(
    'app',
    'XyDesk mulai',
    'versi ${AppVersion.version}+${AppVersion.build}',
  );

  // 3. Hanya membaca kemampuan panel di sini. Penerapannya dilakukan
  //    SettingsNotifier memakai preferensi tersimpan pengguna — kalau
  //    diterapkan di sini juga, pilihan "hemat baterai" akan ditimpa setiap
  //    aplikasi dimulai.
  await _initStep('panel', DisplayControl.probe());

  // 4. Penyimpanan lokal. Tanpa ini aplikasi tidak bisa jalan — tetapi
  //    kegagalannya harus TERLIHAT, bukan berubah jadi splash tanpa akhir.
  final Store store;
  try {
    store = await Store.open().timeout(_initTimeout);
  } catch (error, stack) {
    DevLog.e('store', 'Penyimpanan lokal tidak bisa dibuka', error, stack);
    runApp(
      XyDeskBootError(
        message:
            'Penyimpanan lokal XyDesk tidak bisa dibuka.\n\n'
            'Ini biasanya terjadi kalau memori perangkat penuh atau data '
            'aplikasi rusak. Kosongkan sedikit ruang, lalu coba lagi.',
        onRetry: () {
          unawaited(bootstrap());
        },
      ),
    );
    return;
  }

  final sessionVault = SecureSessionVault();
  String? initialToken;
  try {
    initialToken = await sessionVault.readToken().timeout(_initTimeout);
  } catch (error, stack) {
    // Secure storage dapat gagal bila OS belum siap/penyimpanan rusak.
    // Aplikasi tetap dibuka, tetapi meminta pengguna masuk kembali.
    DevLog.e('auth', 'Gagal membaca sesi aman', error, stack);
  }

  // 5. Aplikasi sebenarnya menggantikan layar boot.
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

  // 6. Notifikasi disiapkan SETELAH frame pertama, bukan sebelumnya.
  //    Dulu ini ditunggu sebelum `runApp`, sehingga satu panggilan SDK
  //    yang tidak pernah menjawab mengunci aplikasi di layar peluncuran.
  unawaited(NotificationService.instance.initialize());
}

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
  runZonedGuarded(bootstrap, (error, stack) {
    DevLog.e('zone', 'Galat tak tertangani', error, stack);
  });
}
