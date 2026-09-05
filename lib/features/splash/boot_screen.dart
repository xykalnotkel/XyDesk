//! Layar boot — frame pertama yang dijamin tampil.
//!
//! Splash native Android (`LaunchTheme`) **bertahan sampai Flutter menggambar
//! frame pertamanya**. Jadi setiap `await` sebelum `runApp` adalah jebakan:
//! satu panggilan platform yang tidak pernah menjawab — penyimpanan lokal
//! yang terkunci, channel native yang diam, SDK pihak ketiga yang
//! tersendat — mengunci pengguna di splash itu untuk selamanya, tanpa crash,
//! tanpa galat, tanpa jejak yang jelas di log.
//!
//! Karena itu aplikasi menggambar layar ini paling dulu (murni Flutter,
//! tanpa provider, tanpa panggilan platform), baru kemudian menjalankan
//! semua inisialisasi dengan batas waktu. Kalau ada yang gagal total,
//! pengguna melihat [`XyDeskBootError`] dengan tombol coba lagi — bukan
//! layar mati yang tidak bisa diapa-apakan.

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../widgets/brand.dart';

/// Layar boot: logo saja, tanpa animasi dan tanpa dependensi.
///
/// Sengaja dibuat sesederhana mungkin — tidak ada `ProviderScope`, tidak ada
/// `SharedPreferences`, tidak ada `MethodChannel`. Satu-satunya tugasnya
/// adalah menggambar frame pertama secepat mungkin supaya splash native
/// dilepas.
class XyDeskBootScreen extends StatelessWidget {
  const XyDeskBootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Tema terang (Paper) dipakai polos: layar ini muncul sebelum tema
      // pengguna sempat dibaca dari preferensi tersimpan.
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bgLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.bgLight,
          brightness: Brightness.light,
        ),
      ),
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 132,
            child: Image(image: AssetImage(Img.logo), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

/// Layar galat boot: dipakai kalau aplikasi benar-benar tidak bisa mulai.
///
/// Yang paling mungkin gagal total adalah penyimpanan lokal — tanpa itu
/// tidak ada yang bisa dibaca, termasuk preferensi tema. Alih-alih diam di
/// splash, pengguna diberi pesan yang jujur dan tombol untuk mencoba lagi.
class XyDeskBootError extends StatelessWidget {
  const XyDeskBootError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bgLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.bgLight,
          brightness: Brightness.light,
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 96,
                  child: Image(
                    image: AssetImage(Img.logo),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'XyDesk belum bisa mulai',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
