/// Permintaan izin runtime — satu-satunya tempat `permission_handler`
/// dipanggil, supaya alur dialog konsisten dan mudah diaudit.
///
/// Kenapa modul ini ada: Android TIDAK pernah menampilkan dialog untuk izin
/// yang tidak diminta, semeleg apa pun manifestnya. Manifest sudah
/// mendeklarasikan RECORD_AUDIO sejak lama, tetapi tidak ada satu pun kode
/// yang memintanya — akibatnya pengguna hanya pernah melihat dialog kamera
/// dan notifikasi, dan toggle mic gagal dengan pesan yang tidak menunjuk ke
/// mana pun. Kamera punya penyakit sama: scanner langsung menyalakan kamera
/// tanpa meminta, jadi layar hitam yang terlihat bukan kesalahan pengguna.
///
/// Aturan pemakaian: minta izin PADA MOMEN fitur dipakai (mic saat toggle
/// dinyalakan, kamera saat halaman pemindai terbuka), bukan saat aplikasi
/// mulai — dialog yang muncul tanpa konteks adalah dialog yang ditolak.
library;

import 'package:permission_handler/permission_handler.dart';

import 'devlog.dart';

class Izin {
  const Izin._();

  /// Izin mikrofon untuk mengirim suara perangkat ke host.
  static Future<bool> mikrofon() => _minta(Permission.microphone, 'mikrofon');

  /// Izin kamera untuk pemindai QR pairing.
  static Future<bool> kamera() => _minta(Permission.camera, 'kamera');

  /// Status tanpa memicu dialog — untuk menampilkan keadaan di UI.
  static Future<bool> statusMikrofon() => Permission.microphone.isGranted;
  static Future<bool> statusKamera() => Permission.camera.isGranted;

  /// true bila sistem menandai izin ini ditolak permanen, sehingga meminta
  /// lagi tidak berguna dan pengguna harus diarahkan ke pengaturan aplikasi.
  static Future<bool> ditolakPermanen(Permission p) => p.isPermanentlyDenied;

  /// Membuka halaman info aplikasi di pengaturan sistem — satu-satunya jalan
  /// pulang dari "ditolak permanen".
  static Future<bool> bukaPengaturan() => openAppSettings();

  static Future<bool> _minta(Permission p, String label) async {
    try {
      final status = await p.request();
      if (status.isGranted) return true;
      DevLog.w('izin', '$label tidak diberi', status.toString());
      return false;
    } catch (e) {
      // Plugin izin gagal (ROM aneh, dsb.) — jangan jatuhkan fitur pemanggil;
      // biar pemanggil yang memutuskan pesan ke pengguna.
      DevLog.w('izin', 'gagal meminta $label', '$e');
      return false;
    }
  }
}
