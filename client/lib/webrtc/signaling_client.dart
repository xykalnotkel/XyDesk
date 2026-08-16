import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Pesan signaling — struktur identik dengan `signaling/protocol.go`.
class SignalMessage {
  SignalMessage({
    required this.type,
    this.to,
    this.from,
    this.pin,
    this.accepted,
    this.sdp,
    this.candidate,
    this.error,
    this.reason,
    this.devices,
  });

  final String type;
  final String? to;
  final String? from;
  final String? pin;
  final bool? accepted;
  final Map<String, dynamic>? sdp;
  final Map<String, dynamic>? candidate;
  final String? error;
  final String? reason;
  final List<Map<String, dynamic>>? devices;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (to != null) 'to': to,
        if (from != null) 'from': from,
        if (pin != null) 'pin': pin,
        if (accepted != null) 'accepted': accepted,
        if (sdp != null) 'sdp': sdp,
        if (candidate != null) 'candidate': candidate,
        if (reason != null) 'reason': reason,
      };

  factory SignalMessage.fromJson(Map<String, dynamic> j) => SignalMessage(
        type: j['type'] as String? ?? '',
        to: j['to'] as String?,
        from: j['from'] as String?,
        pin: j['pin'] as String?,
        accepted: j['accepted'] as bool?,
        sdp: j['sdp'] as Map<String, dynamic>?,
        candidate: j['candidate'] as Map<String, dynamic>?,
        error: j['error'] as String?,
        reason: j['reason'] as String?,
        devices:
            (j['devices'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
}

/// Klien signaling untuk app XyDesk (role=client).
///
/// Membungkus WebSocket ke server Go. Callback dipicu oleh pesan masuk;
/// pasangkan dengan [RtcService] untuk negosiasi WebRTC.
class SignalingClient {
  SignalingClient({required this.deviceId});

  final String deviceId;
  WebSocketChannel? _ch;
  StreamSubscription? _sub;

  /// Panggil saat server mengirim `pair-response` (host menjawab pairing).
  void Function(bool accepted, String? from)? onPairResponse;

  /// Panggil saat tawaran/balasan/ICE datang — teruskan ke RtcService.
  void Function(SignalMessage msg)? onMessage;

  /// Panggil saat koneksi terputus.
  void Function()? onDisconnected;

  bool get isConnected => _ch != null;

  Future<void> connect(String url, String token) async {
    // Token dilewatkan via query (?token=) — server Go menerima ini, jadi
    // tidak perlu header kustom (cocok untuk web_socket_channel di semua
    // platform: Android/iOS/web/desktop).
    final wsUrl = '$url?id=$deviceId&role=client&token=$token';
    final ch = WebSocketChannel.connect(Uri.parse(wsUrl));
    _ch = ch;

    _sub = ch.stream.listen(
      (data) {
        final m = SignalMessage.fromJson(jsonDecode(data as String) as Map<String, dynamic>);
        switch (m.type) {
          case 'pair-response':
            onPairResponse?.call(m.accepted ?? false, m.from);
            break;
          default:
            onMessage?.call(m);
        }
      },
      onDone: () => onDisconnected?.call(),
      onError: (_) => onDisconnected?.call(),
    );

    // daftar sebagai client
    _send(SignalMessage(type: 'hello', to: deviceId, reason: 'client'));
  }

  /// Normalisasi ID perangkat: buang spasi & tanda hubung, sehingga
  /// "123 456 789" / "123-456-789" → "123456789" (cocok dgn ID host).
  static String normalizeId(String id) => id.replaceAll(RegExp(r'[\s\-]'), '');

  void sendPair(String hostId, String pin) =>
      _send(SignalMessage(type: 'pair', to: normalizeId(hostId), pin: pin));

  void sendOffer(String hostId, Map<String, dynamic> sdp) =>
      _send(SignalMessage(type: 'offer', to: normalizeId(hostId), sdp: sdp));

  void sendAnswer(String clientId, Map<String, dynamic> sdp) =>
      _send(SignalMessage(type: 'answer', to: clientId, sdp: sdp));

  void sendIce(String peerId, Map<String, dynamic> candidate) =>
      _send(SignalMessage(type: 'ice', to: peerId, candidate: candidate));

  void sendBye(String peerId) => _send(SignalMessage(type: 'bye', to: peerId));

  void _send(SignalMessage m) {
    if (m.type == 'hello') {
      // hello dikirim setelah terhubung; kirim mentah
      _ch?.sink.add(jsonEncode(m.toJson()));
    } else {
      _ch?.sink.add(jsonEncode(m.toJson()));
    }
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _ch?.sink.close();
    _ch = null;
  }
}
