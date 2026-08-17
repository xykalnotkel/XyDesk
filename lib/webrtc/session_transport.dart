import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/devlog.dart';
import '../features/auth/auth_service.dart';
import 'rtc_service.dart';
import 'signaling_client.dart';

/// Status transport yang dikonsumsi `SessionPage`.
///
/// `preview` = tidak ada JWT (mode tamu) atau transport dimatikan; UI tetap
/// bisa dijelajahi tetapi tidak ada video/input yang berjalan.
enum TransportStatus {
  preview,
  pairing,
  negotiating,
  connected,
  rejected,
  peerOffline,
  ended,
  error,
}

@immutable
class TransportState {
  const TransportState({this.status = TransportStatus.preview, this.message});

  final TransportStatus status;
  final String? message;

  bool get live => status == TransportStatus.connected;
}

/// Konfigurasi endpoint signaling. Base URL sama dengan auth Worker.
abstract final class SignalingConfig {
  static const wsUrl = String.fromEnvironment(
    'XYDESK_SIGNALING_URL',
    defaultValue: 'wss://signal.xystudio.my.id/ws',
  );
}

/// Pengendali transport untuk satu sesi remote.
///
/// Alur: JWT sesi -> `/signal-token` (token signaling 5 menit) -> connect
/// `/ws` -> pair (password) -> negosiasi WebRTC -> video + data channel.
class SessionTransport extends ChangeNotifier {
  SessionTransport({required this.jwt, http.Client? client})
    : _http = client ?? http.Client();

  final String? jwt;
  final http.Client _http;

  RtcService? _rtc;
  StreamSubscription<RtcPhase>? _phaseSub;
  TransportState _state = const TransportState();
  bool _disposed = false;

  TransportState get state => _state;
  RtcService? get rtc => _rtc;

  void _set(TransportStatus status, [String? message]) {
    if (_disposed) return;
    _state = TransportState(status: status, message: message);
    notifyListeners();
  }

  /// Mulai sesi ke [hostId] dengan [password] pairing.
  ///
  /// Tanpa JWT (mode tamu) transport tetap di `preview` — jujur ke UI bahwa
  /// tidak ada koneksi, bukan pura-pura tersambung.
  Future<void> start({required String hostId, required String password}) async {
    final token = jwt;
    if (token == null || token.isEmpty) {
      _set(TransportStatus.preview, 'Masuk dengan akun untuk memulai sesi.');
      return;
    }

    final deviceId = 'app-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    _set(TransportStatus.pairing);

    final String signalToken;
    try {
      final uri = Uri.parse('${AuthConfig.baseUrl}/signal-token?id=$deviceId');
      final res = await _http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        DevLog.w('rtc', 'signal-token gagal', 'HTTP ${res.statusCode}');
        _set(TransportStatus.error, 'Gagal mendapat izin signaling.');
        return;
      }
      signalToken = res.body.trim();
    } catch (e) {
      DevLog.w('rtc', 'signal-token error', '$e');
      _set(TransportStatus.error, 'Tidak dapat menghubungi server signaling.');
      return;
    }

    final rtc = RtcService();
    _rtc = rtc;
    _phaseSub = rtc.phases.listen((phase) {
      switch (phase) {
        case RtcPhase.pairing:
          _set(TransportStatus.pairing);
        case RtcPhase.negotiating:
          _set(TransportStatus.negotiating);
        case RtcPhase.connected:
          _set(TransportStatus.connected);
        case RtcPhase.rejected:
          _set(TransportStatus.rejected, 'Host menolak pairing.');
        case RtcPhase.peerOffline:
          _set(TransportStatus.peerOffline, 'Host tidak online.');
        case RtcPhase.ended:
          _set(TransportStatus.ended);
      }
    });

    try {
      await rtc.startSession(
        signalingUrl: SignalingConfig.wsUrl,
        hostId: SignalingClient.normalizeId(hostId),
        token: signalToken,
        deviceId: deviceId,
        pin: password,
      );
    } catch (e) {
      DevLog.e('rtc', 'startSession gagal', e);
      _set(TransportStatus.error, 'Koneksi WebRTC gagal dimulai.');
    }
  }

  /// Kirim event input biner (lihat `input_codec.dart`).
  void sendInput(Uint8List event) => _rtc?.sendInput(event);

  Future<void> shutdown() async {
    await _phaseSub?.cancel();
    _phaseSub = null;
    final rtc = _rtc;
    _rtc = null;
    if (rtc != null) await rtc.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(shutdown());
    _http.close();
    super.dispose();
  }
}
