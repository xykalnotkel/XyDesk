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

  /// Capability snapshot for the current app/host implementation. Replace it
  /// with negotiated runtime data once both peers expose audio tracks.
  static const currentBuild = SessionMediaCapabilities(
    pcSystemAudio: MediaPathCapability(
      state: MediaPipelineState.notImplemented,
      summary: 'Belum tersedia pada build ini',
      missingComponents: [
        'WASAPI loopback host',
        'Track Opus host ke perangkat',
        'Decoder dan output audio klien',
      ],
    ),
    phoneMicrophone: MediaPathCapability(
      state: MediaPipelineState.notImplemented,
      summary: 'Belum tersedia pada build ini',
      missingComponents: [
        'Capture dan pemrosesan mik perangkat',
        'Track Opus perangkat ke host',
        'Endpoint mikrofon virtual Windows',
      ],
    ),
    freeDuringBeta: true,
  );
}
