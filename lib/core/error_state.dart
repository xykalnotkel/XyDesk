import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/tokens.dart';

/// Tipe error yang bisa terjadi di XyDesk.
///
/// Setiap tipe punya pesan, ikon, dan saran aksi yang jelas — bukan error
/// generik yang membuat pengguna bingung. Error state harus actionable:
/// pengguna harus tahu apa yang salah dan apa yang bisa dilakukan.
enum XyDeskErrorType {
  /// Koneksi ke server signaling gagal (network error, DNS, timeout).
  network,

  /// Server signaling merespons tapi menolak (token expired, auth failed).
  authentication,

  /// Host tidak merespons pairing request (host offline, firewall, dll).
  hostOffline,

  /// Host menolak pairing (password salah, host sibuk, max connections).
  hostRejected,

  /// Koneksi WebRTC gagal (ICE failed, no route, firewall blocking).
  connectionFailed,

  /// Sesi terputus di tengah jalan (host crash, network drop).
  sessionDisconnected,

  /// Timeout — operasi tidak selesai dalam batas waktu.
  timeout,

  /// Error tidak diketahui / unexpected.
  unknown,
}

/// State error yang ditampilkan di UI.
class XyDeskError {
  const XyDeskError({
    required this.type,
    required this.message,
    this.detail,
    this.action,
    this.retryable = false,
  });

  final XyDeskErrorType type;
  final String message;
  final String? detail;
  final String? action;
  final bool retryable;

  IconData get icon => switch (type) {
    XyDeskErrorType.network => LucideIcons.wifiOff,
    XyDeskErrorType.authentication => LucideIcons.shieldAlert,
    XyDeskErrorType.hostOffline => LucideIcons.monitorOff,
    XyDeskErrorType.hostRejected => LucideIcons.shieldX,
    XyDeskErrorType.connectionFailed => LucideIcons.unplug,
    XyDeskErrorType.sessionDisconnected => LucideIcons.link2Off,
    XyDeskErrorType.timeout => LucideIcons.timerOff,
    XyDeskErrorType.unknown => LucideIcons.alertCircle,
  };

  /// Warna status error. Palet diberikan pemanggil karena `textLow`
  /// bergantung tema — AppColors tidak punya warna teks yang netral tema.
  Color color(AppPalette c) => switch (type) {
    XyDeskErrorType.network => AppColors.danger,
    XyDeskErrorType.authentication => AppColors.warning,
    XyDeskErrorType.hostOffline => AppColors.warning,
    XyDeskErrorType.hostRejected => AppColors.danger,
    XyDeskErrorType.connectionFailed => AppColors.danger,
    XyDeskErrorType.sessionDisconnected => AppColors.danger,
    XyDeskErrorType.timeout => AppColors.warning,
    XyDeskErrorType.unknown => c.textLow,
  };

  /// Factory methods untuk error yang umum terjadi.
  static XyDeskError networkError([String? detail]) => XyDeskError(
    type: XyDeskErrorType.network,
    message: 'Tidak dapat terhubung ke server',
    detail: detail ?? 'Periksa koneksi internet kamu dan coba lagi.',
    action: 'Coba lagi',
    retryable: true,
  );

  static XyDeskError authError([String? detail]) => XyDeskError(
    type: XyDeskErrorType.authentication,
    message: 'Sesi tidak valid',
    detail: detail ?? 'Silakan masuk kembali ke akun kamu.',
    action: 'Masuk ulang',
  );

  static XyDeskError hostOfflineError() => const XyDeskError(
    type: XyDeskErrorType.hostOffline,
    message: 'PC tidak online',
    detail:
        'Pastikan XyDesk Host berjalan di PC tujuan dan terhubung ke internet.',
    action: 'Coba lagi',
    retryable: true,
  );

  static XyDeskError hostRejectedError([String? reason]) => XyDeskError(
    type: XyDeskErrorType.hostRejected,
    message: 'PC menolak sambungan',
    detail: reason ?? 'Password salah, atau PC sedang melayani sesi lain.',
    action: 'Coba lagi',
    retryable: true,
  );

  static XyDeskError connectionFailedError([String? detail]) => XyDeskError(
    type: XyDeskErrorType.connectionFailed,
    message: 'Koneksi gagal',
    detail: detail ?? 'Tidak dapat membuat koneksi peer-to-peer ke PC.',
    action: 'Coba lagi',
    retryable: true,
  );

  static XyDeskError sessionDisconnectedError() => const XyDeskError(
    type: XyDeskErrorType.sessionDisconnected,
    message: 'Sesi terputus',
    detail:
        'Koneksi ke PC terputus. PC mungkin offline atau jaringan bermasalah.',
    action: 'Hubungkan ulang',
    retryable: true,
  );

  static XyDeskError timeoutError([String? detail]) => XyDeskError(
    type: XyDeskErrorType.timeout,
    message: 'Waktu habis',
    detail: detail ?? 'PC tidak merespons dalam batas waktu yang ditentukan.',
    action: 'Coba lagi',
    retryable: true,
  );

  static XyDeskError unknownError([String? detail]) => XyDeskError(
    type: XyDeskErrorType.unknown,
    message: 'Terjadi kesalahan',
    detail: detail ?? 'Silakan coba lagi atau hubungi dukungan.',
    action: 'Coba lagi',
    retryable: true,
  );
}

/// Widget error state yang jelas dan actionable.
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onAction,
  });

  final XyDeskError error;
  final VoidCallback? onRetry;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: error.color(c).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: error.color(c).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(error.icon, size: 34, color: error.color(c)),
            ),
            const SizedBox(height: 16),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: 8),
            if (error.detail != null)
              Text(
                error.detail!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: c.textMid),
              ),
            const SizedBox(height: 24),
            if (error.retryable && onRetry != null)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: Text(error.action ?? 'Coba lagi'),
              ),
            if (!error.retryable && onAction != null)
              FilledButton(
                onPressed: onAction,
                child: Text(error.action ?? 'OK'),
              ),
          ],
        ),
      ),
    );
  }
}
