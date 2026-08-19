import 'package:flutter/foundation.dart';

class NotificationConfig {
  const NotificationConfig._();

  /// OneSignal App ID adalah identifier publik, bukan REST API Key.
  /// Nilai tetap dapat dioverride saat build bila proyek OneSignal dipindahkan.
  static const oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'e3d5adea-1c0f-4986-9ce5-e088d65f0998',
  );

  static const updateRouteName = '/app-update';
  static const updateRoutePayload = 'app_update';

  // Keputusan owner (2026-08): notifikasi memakai suara default perangkat.
  // Scaffolding channel suara custom dihapus — channel Android mengunci
  // suara permanen, jadi tidak boleh ada channel spekulatif tanpa aset.

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
