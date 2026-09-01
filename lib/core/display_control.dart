import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'devlog.dart';

/// Kontrol tampilan perangkat: refresh rate dan layar tetap menyala.
///
/// ## Kenapa berkas ini ada
///
/// Versi sebelumnya memanggil metode `setHighRefreshRate` pada channel
/// `flutter/platform_views`. Metode itu **tidak pernah ada** di Flutter, dan
/// panggilannya dibungkus `catchError((_) {})` sehingga kegagalannya tidak
/// pernah terlihat. Akibatnya sakelar "Refresh rate tinggi" di Pengaturan
/// tersimpan rapi ke disk dan tidak melakukan apa pun.
///
/// Ini pola yang paling merusak kepercayaan pada halaman pengaturan: sakelar
/// yang menyala, ingat pilihanmu, dan bohong. Sekarang implementasinya nyata
/// (`MainActivity.kt`, channel `com.xystudio.xydesk/display`), dan bila
/// perangkat memang hanya mendukung satu refresh rate, UI mengatakannya.
class DisplayControl {
  const DisplayControl._();

  static const _channel = MethodChannel('com.xystudio.xydesk/display');

  /// Refresh rate yang sedang dipakai panel, dalam Hz.
  static double current = 60;

  /// Refresh rate yang didukung pada resolusi aktif. Kosong berarti belum
  /// diperiksa; satu elemen berarti perangkat tidak punya pilihan.
  static List<double> supported = const [];

  /// Perangkat ini benar-benar punya pilihan refresh rate.
  static bool get canSwitch => supported.length > 1;

  static bool get _android => Platform.isAndroid;

  static Future<void> _refresh(Map<Object?, Object?>? raw) async {
    if (raw == null) return;
    final value = (raw['current'] as num?)?.toDouble();
    if (value != null && value > 0) current = value;
    final list = (raw['supported'] as List?)
        ?.map((e) => (e as num).toDouble())
        .toList();
    if (list != null) supported = List.unmodifiable(list);
  }

  /// Membaca kemampuan panel. Dipanggil sekali saat aplikasi mulai.
  static Future<void> probe() async {
    if (!_android) {
      current = _flutterRefreshRate();
      return;
    }
    try {
      await _refresh(
        await _channel.invokeMapMethod<Object?, Object?>('getDisplayInfo'),
      );
      DevLog.i(
        'display',
        'Kemampuan panel',
        '${current.round()} Hz · didukung '
            '${supported.map((e) => e.round()).join('/')}',
      );
    } on MissingPluginException {
      // Build lama tanpa channel ini. Jangan diam — sakelar di Pengaturan
      // harus tahu bahwa ia tidak punya efek.
      supported = const [];
      DevLog.w('display', 'Channel tampilan tidak tersedia di build ini');
    } catch (e) {
      supported = const [];
      DevLog.w('display', 'Gagal membaca mode tampilan', '$e');
    }
  }

  /// Menerapkan preferensi refresh rate pengguna.
  ///
  /// Mengembalikan Hz yang benar-benar berlaku, supaya pemanggil bisa
  /// menampilkan hasil sebenarnya alih-alih mengasumsikan berhasil.
  static Future<double> setHighRefreshRate(bool enabled) async {
    if (!_android) return current;
    try {
      await _refresh(
        await _channel.invokeMapMethod<Object?, Object?>('setHighRefreshRate', {
          'enabled': enabled,
        }),
      );
      DevLog.i(
        'display',
        'Refresh rate diterapkan',
        '${enabled ? 'tertinggi' : 'hemat'} → ${current.round()} Hz',
      );
    } catch (e) {
      DevLog.w('display', 'Gagal mengatur refresh rate', '$e');
    }
    return current;
  }

  /// Mencegah layar mati. Wajib selama sesi remote berjalan — tanpa ini,
  /// layar padam saat pengguna hanya menonton dan sesi terlihat "putus".
  static Future<void> setKeepScreenOn(bool enabled) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<bool>('setKeepScreenOn', {
        'enabled': enabled,
      });
      DevLog.i('display', 'Layar tetap menyala', '$enabled');
    } catch (e) {
      DevLog.w('display', 'Gagal mengatur layar tetap menyala', '$e');
    }
  }

  static double _flutterRefreshRate() {
    final view = SchedulerBinding.instance.platformDispatcher.views.firstOrNull;
    return view?.display.refreshRate ?? 60;
  }
}
