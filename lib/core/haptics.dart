import 'package:flutter/services.dart';

/// Umpan balik getar terpusat.
///
/// ## Kenapa dipusatkan
///
/// Sakelar "Getaran" di Pengaturan tersimpan ke disk, tetapi nilainya hanya
/// dibaca oleh layar sesi. Setiap tombol lain di aplikasi memanggil
/// `HapticFeedback` langsung — atau tidak sama sekali. Jadi mematikan getaran
/// tidak benar-benar mematikan getaran.
///
/// Kelas ini menjadi satu-satunya pintu. Nilai `enabled` disetel oleh
/// `SettingsNotifier` saat pengaturan dimuat dan setiap kali sakelar berubah,
/// jadi pemanggil tidak perlu punya akses ke Riverpod hanya untuk bergetar.
class AppHaptics {
  const AppHaptics._();

  /// Disetel oleh `SettingsNotifier`. Bawaan mengikuti nilai bawaan pengaturan.
  static bool enabled = true;

  /// Ketukan ringan — untuk tap biasa: baris daftar, tab, chip.
  static void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Getaran sedang — untuk tindakan yang mengubah keadaan: sakelar, kirim.
  static void impact() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Getaran tegas — untuk peringatan dan tindakan merusak.
  static void heavy() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
