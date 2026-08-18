import 'package:package_info_plus/package_info_plus.dart';

/// Versi aplikasi, dibaca sekali dari metadata paket (pubspec `version:`).
///
/// Alasan ada berkas ini: nomor versi sebelumnya ditulis tangan di beberapa
/// tempat (`main.dart`, tiga lokasi di `account_page.dart`). Nilainya tidak
/// pernah ikut diperbarui saat rilis, sehingga UI sempat menampilkan 1.2.0
/// padahal aplikasi sudah 1.6.0 — empat rilis meleset.
///
/// Nilainya disimpan sinkron supaya widget `StatelessWidget` bisa memakainya
/// tanpa harus berubah jadi async/FutureBuilder.
class AppVersion {
  AppVersion._();

  static String _version = '';
  static String _build = '';
  static bool _loaded = false;

  /// Dipanggil sekali saat startup, sebelum `runApp`.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _build = info.buildNumber;
      _loaded = true;
    } catch (_) {
      // Metadata paket tidak tersedia (mis. unit test): biarkan kosong dan
      // tampilkan placeholder daripada angka usang yang menyesatkan.
      _loaded = false;
    }
  }

  /// Contoh: `1.7.0`. Kosong sebelum [load] selesai.
  static String get version => _version;

  /// Contoh: `10`. Kosong sebelum [load] selesai.
  static String get build => _build;

  /// Contoh: `v1.7.0`.
  static String get short => _loaded ? 'v$_version' : 'v—';

  /// Contoh: `1.7.0 · Build 10`.
  static String get full => _loaded ? '$_version · Build $_build' : '—';

  /// Contoh: `XyDesk 1.7.0 · Build 10`.
  static String get labeled =>
      _loaded ? 'XyDesk $_version · Build $_build' : 'XyDesk';

  /// Contoh: `Versi 1.7.0 · Build 10`.
  static String get versiFull =>
      _loaded ? 'Versi $_version · Build $_build' : 'Versi —';
}
