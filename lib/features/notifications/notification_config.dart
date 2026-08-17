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

  /// Nama/version slug yang disiapkan untuk rekaman suara pengguna nanti.
  /// Channel belum boleh dibuat sebelum berkas suara final dibundel karena
  /// Android mengunci perilaku suara channel setelah channel pertama dibuat.
  static const updateVoiceChannelV1 = 'xydesk_updates_voice_v1';
  static const updateVoiceSoundV1 = 'xydesk_update_voice_v1';

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
