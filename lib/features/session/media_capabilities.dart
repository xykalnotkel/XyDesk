import 'package:flutter/foundation.dart';

/// Runtime truth for a media path. A saved user preference is deliberately
/// separate from this state so the UI cannot report a stream as active merely
/// because its toggle was enabled.
enum MediaPipelineState { notImplemented, available, active, error }

@immutable
class MediaPathCapability {
  const MediaPathCapability({
    required this.state,
    required this.summary,
    required this.missingComponents,
  });

  final MediaPipelineState state;
  final String summary;
  final List<String> missingComponents;

  bool get canActivate =>
      state == MediaPipelineState.available ||
      state == MediaPipelineState.active;
  bool get isActive => state == MediaPipelineState.active;
}

@immutable
class SessionMediaCapabilities {
  const SessionMediaCapabilities({
    required this.pcSystemAudio,
    required this.phoneMicrophone,
    required this.freeDuringBeta,
  });

  final MediaPathCapability pcSystemAudio;
  final MediaPathCapability phoneMicrophone;

  /// Entitlement is intentionally permissive during beta. This flag is not a
  /// transport capability and must never be used to imply that audio works.
  final bool freeDuringBeta;

  /// Capability snapshot for the current app/host implementation.
  ///
  /// Rilis 6.1: jalur audio NYATA terpasang di kedua sisi.
  /// - Audio PC: host menangkap WASAPI loopback → Opus; perangkat memutar
  ///   track remote (perlu `RTCVideoView` audio kecil di layar sesi).
  /// - Mik: mic perangkat dikirim sebagai track Opus; host MEMUTARNYA di
  ///   speaker PC (endpoint mikrofon virtual Windows menyusul — disampaikan
  ///   jujur di panel audio).
  static const currentBuild = SessionMediaCapabilities(
    pcSystemAudio: MediaPathCapability(
      state: MediaPipelineState.available,
      summary: 'Audio PC diputar di perangkat ini bila host Windows aktif',
      missingComponents: [],
    ),
    phoneMicrophone: MediaPathCapability(
      state: MediaPipelineState.available,
      summary: 'Mic perangkat dikirim — terdengar di speaker PC host',
      missingComponents: ['Endpoint mikrofon virtual Windows (fase berikut)'],
    ),
    freeDuringBeta: true,
  );
}
