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
  // Idempoten: `main()` sudah memanggilnya sebelum kanal PiP. Dipanggil lagi
  // di sini supaya `bootstrap()` tetap aman berdiri sendiri (mis. dari tombol
  // coba lagi [XyDeskBootError] atau dari uji).
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Frame pertama — SEBELUM apa pun yang bisa gagal. Splash native dilepas
  //    pada titik ini, jadi semua kegagalan di bawah terjadi di dalam Flutter,
  //    bukan di layar mati.
  runApp(const XyDeskBootScreen());

  // Perekam log dipasang setelah frame pertama. Ia murni Dart dan tidak
  // pernah menyentuh kanal platform, tapi tidak ada alasan menaruhnya di
  // depan satu-satunya baris yang menjamin splash native dilepas.
  try {
    DevLog.install();
  } catch (error, stack) {
    debugPrint('DevLog tidak bisa dipasang: $error\n$stack');
  }

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

/// Daftarkan kanal PiP dari Android native.
///
/// **Wajib dipanggil SETELAH `WidgetsFlutterBinding.ensureInitialized()`.**
/// `MethodChannel.setMethodCallHandler` menyentuh binary messenger, dan
/// messenger itu tidak ada sebelum binding siap. Flutter menuliskan aturannya
/// sendiri di assert `platform_channel.dart`:
///
/// > "Cannot set the method call handler before the binary messenger has been
/// > initialized. This happens when you call setMethodCallHandler() before the
/// WidgetsFlutterBinding has been initialized."
///
/// Di debug itu melempar `FlutterError`; di release assert-nya hilang dan
/// `_findBinaryMessenger()` menyentuh `ServicesBinding.instance` yang null,
/// jadi yang melempar adalah "Null check operator used on a null value".
/// Dua-duanya terjadi di `main()`, DI LUAR `runZonedGuarded` dan SEBELUM
/// `runApp` — akibatnya frame pertama tidak pernah digambar dan splash native
/// Android bertahan selamanya tanpa crash, tanpa galat, tanpa tombol.
/// Persis kegagalan yang dideskripsikan komentar di atas [bootstrap].
///
/// Urutan ini dijaga `test/core/bootstrap_order_test.dart`.
void registerPipChannel() {
  try {
    const pipChannel = MethodChannel(pipChannelName);
    pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        // `== true`, bukan `as bool`: argumen yang hilang atau salah tipe
        // tidak boleh melempar di dalam handler kanal.
        PipController.instance.handlePipModeChanged(call.arguments == true);
      }
      return null;
    });
  } catch (error, stack) {
    // PiP adalah kenyamanan saat sesi berjalan, bukan syarat membuka aplikasi.
    // Kegagalan di sini dicatat lalu dilewati — tidak ada fitur opsional yang
    // berhak mengunci pengguna di splash.
    DevLog.e('boot', 'Kanal PiP tidak bisa didaftarkan', '$error\n$stack');
  }
}

void main() {
  // 1. Binding dulu, sebelum satu pun kanal platform disentuh. Lihat
  //    [registerPipChannel] — inilah urutan yang pernah membuat aplikasi
  //    tidak bisa dibuka sama sekali.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Kanal PiP. Sudah aman karena binding siap, dan tetap dibungkus
  //    try/catch di dalam [registerPipChannel].
  registerPipChannel();

  // 3. runZonedGuarded menangkap error async yang lolos dari framework,
  //    sehingga tidak ada kegagalan diam-diam yang berujung layar kosong.
  runZonedGuarded(bootstrap, (error, stack) {
    DevLog.e('zone', 'Galat tak tertangani', error, stack);
  });
}
