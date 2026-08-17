import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'update_repository.dart';

enum UpdateDownloadPhase {
  idle,
  queued,
  running,
  paused,
  verifying,
  ready,
  failed,
}

class UpdateDownloadStatus {
  const UpdateDownloadStatus({
    required this.phase,
    required this.downloadedBytes,
    required this.totalBytes,
    this.message,
  });

  const UpdateDownloadStatus.idle()
      : phase = UpdateDownloadPhase.idle,
        downloadedBytes = 0,
        totalBytes = 0,
        message = null;

  final UpdateDownloadPhase phase;
  final int downloadedBytes;
  final int totalBytes;
  final String? message;

  double? get progress {
    if (totalBytes <= 0 || downloadedBytes < 0) return null;
    return (downloadedBytes / totalBytes).clamp(0, 1).toDouble();
  }

  bool get isActive => switch (phase) {
        UpdateDownloadPhase.queued ||
        UpdateDownloadPhase.running ||
        UpdateDownloadPhase.paused ||
        UpdateDownloadPhase.verifying =>
          true,
        _ => false,
      };

  factory UpdateDownloadStatus.fromMap(Map<Object?, Object?> map) {
    final phaseName = map['phase'] as String? ?? 'idle';
    final phase = UpdateDownloadPhase.values.firstWhere(
      (value) => value.name == phaseName,
      orElse: () => UpdateDownloadPhase.failed,
    );
    return UpdateDownloadStatus(
      phase: phase,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      message: map['message'] as String?,
    );
  }
}

class AndroidUpdateDownloader {
  const AndroidUpdateDownloader();

  static const _channel = MethodChannel('com.xystudio.xydesk/update');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<UpdateDownloadStatus> status() async {
    if (!isSupported) return const UpdateDownloadStatus.idle();
    return _invokeStatus('getStatus');
  }

  Future<UpdateDownloadStatus> start(
    OfficialUpdateManifest manifest,
  ) async {
    if (!isSupported) {
      throw const UpdateDownloadException(
        'Download update otomatis hanya tersedia di Android.',
      );
    }
    return _invokeStatus(
      'startDownload',
      <String, Object>{
        'url': manifest.apkUri.toString(),
        'sha256': manifest.apkSha256,
        'bytes': manifest.apkBytes,
        'version': manifest.version,
        'build': manifest.buildNumber,
      },
    );
  }

  Future<UpdateDownloadStatus> install() async {
    if (!isSupported) {
      throw const UpdateDownloadException(
        'Pemasangan update otomatis hanya tersedia di Android.',
      );
    }
    return _invokeStatus('installDownloadedUpdate');
  }

  Future<void> openInstallPermissionSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
    } on PlatformException catch (error) {
      throw UpdateDownloadException(
        error.message ?? 'Pengaturan izin pemasangan tidak dapat dibuka.',
      );
    }
  }

  Future<UpdateDownloadStatus> _invokeStatus(
    String method, [
    Map<String, Object>? arguments,
  ]) async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        method,
        arguments,
      );
      if (result == null) {
        throw const UpdateDownloadException(
          'Android tidak mengembalikan status update.',
        );
      }
      return UpdateDownloadStatus.fromMap(result);
    } on PlatformException catch (error) {
      throw UpdateDownloadException(
        error.message ?? 'Proses update Android gagal.',
        code: error.code,
      );
    } on MissingPluginException {
      throw const UpdateDownloadException(
        'Komponen update Android belum tersedia pada instalasi ini.',
      );
    }
  }
}

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message, {this.code});

  final String message;
  final String? code;

  bool get needsInstallPermission => code == 'INSTALL_PERMISSION_REQUIRED';

  @override
  String toString() => message;
}
