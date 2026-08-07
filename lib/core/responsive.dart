import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Kelas ukuran layar. Dipakai agar tata letak menyesuaikan HP kecil,
/// HP besar, sampai tablet — bukan sekadar diperbesar.
enum ScreenSize { compact, medium, expanded }

/// Utilitas responsif.
///
/// Masalah yang diselesaikan: HP dengan DPI tinggi (mis. 480–560 dpi) atau
/// pengguna yang menaikkan "Ukuran font" di setelan sistem bisa membuat
/// tata letak jadi berdesakan atau teks terpotong. Di sini skala teks
/// dibatasi dan ukuran elemen diturunkan dari lebar layar.
class Responsive {
  const Responsive._();

  /// Batas skala teks sistem. Di bawah 0.85 teks terlalu kecil untuk
  /// dibaca; di atas 1.3 tata letak padat seperti keyboard virtual mulai
  /// rusak. Pengguna tetap bisa memperbesar, hanya dibatasi.
  static const minTextScale = 0.85;
  static const maxTextScale = 1.30;

  static ScreenSize sizeOf(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 360) return ScreenSize.compact;
    if (w < 600) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  static bool isCompact(BuildContext c) => sizeOf(c) == ScreenSize.compact;
  static bool isTablet(BuildContext c) => sizeOf(c) == ScreenSize.expanded;

  static bool isLandscape(BuildContext c) =>
      MediaQuery.orientationOf(c) == Orientation.landscape;

  /// Skala ukuran elemen mengikuti lebar layar, dengan batas aman.
  static double scale(BuildContext context, {double base = 1}) {
    final w = MediaQuery.sizeOf(context).width;
    final f = (w / 390).clamp(0.88, 1.18); // 390 = lebar acuan desain
    return base * f;
  }

  /// Nilai berbeda per kelas layar.
  static T pick<T>(
    BuildContext context, {
    required T compact,
    required T medium,
    T? expanded,
  }) {
    switch (sizeOf(context)) {
      case ScreenSize.compact:
        return compact;
      case ScreenSize.medium:
        return medium;
      case ScreenSize.expanded:
        return expanded ?? medium;
    }
  }
}

/// Membungkus aplikasi agar skala teks sistem tidak merusak tata letak.
class TextScaleGuard extends StatelessWidget {
  const TextScaleGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: Responsive.minTextScale,
          maxScaleFactor: Responsive.maxTextScale,
        ),
      ),
      child: child,
    );
  }
}

/// Mengaktifkan refresh rate tertinggi yang didukung perangkat.
///
/// Banyak HP Android mengunci aplikasi di 60 Hz kecuali diminta eksplisit.
/// Untuk aplikasi remote desktop, 90/120 Hz terasa jelas lebih mulus saat
/// menggeser pointer dan membuka panel.
class DisplayMode {
  const DisplayMode._();

  static Future<void> useHighestRefreshRate() async {
    try {
      // Channel resmi Flutter untuk mengganti mode tampilan Android.
      const ch = MethodChannel('flutter/platform_views');
      // Pada Android 11+ Flutter sudah otomatis memakai mode tertinggi bila
      // aktivitas meminta. Panggilan ini aman diabaikan bila tidak tersedia.
      await ch.invokeMethod<void>('setHighRefreshRate').catchError((_) {});
    } catch (_) {
      // Bukan Android atau tidak didukung — abaikan, tetap jalan di 60 Hz.
    }
  }

  /// Refresh rate saat ini, untuk ditampilkan di DevLog.
  static double get current {
    final v = SchedulerBinding.instance.platformDispatcher.views.firstOrNull;
    if (v == null) return 60;
    return v.display.refreshRate;
  }
}
