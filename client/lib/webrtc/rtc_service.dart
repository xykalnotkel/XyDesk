import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import 'signaling_client.dart';

/// Layanan WebRTC client XyDesk.
///
/// Client = penelepon: buat `RTCPeerConnection`, `createOffer`, kirim ke host
/// lewat signaling, terima `answer` + `ice`, lalu render video. Input
/// (mouse/keyboard) dikirim lewat data channel yang **reliable** — kehilangan
/// satu event input tidak boleh terjadi.
class RtcService {
  RTCPeerConnection? _pc;
  RTCDataChannel? _inputChannel;
  SignalingClient? _sig;

  String _deviceId = '';
  String _token = '';
  String _signalingBase = '';

  /// Video renderer untuk ditampilkan di `RTCVideoView`.
  RTCVideoRenderer get renderer => _renderer;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();

  Stream<void> get onSessionEnd => _endCtrl.stream;
  final _endCtrl = StreamController<void>.broadcast();

  /// Memulai sesi sebagai client terhadap [hostId].
  ///
  /// [stun] default pakai STUN publik gratis (tanpa biaya). [turn] opsional —
  /// isi bila koneksi direct gagal (lihat docs/FREE-STACK.md).
  Future<void> startSession({
    required String signalingUrl,
    required String hostId,
    required String token,
    required String deviceId,
    String pin = '',
    List<String> stun = const ['stun:stun.cloudflare.com:3478'],
    Map<String, String>? turn,
  }) async {
    _deviceId = deviceId;
    _token = token;
    _signalingBase = _deriveBase(signalingUrl);

    final sig = SignalingClient(deviceId: deviceId);
    _sig = sig;

    sig.onPairResponse = (accepted, from) async {
      if (!accepted) {
        _endCtrl.add(null);
        return;
      }
      await _negotiate(hostId);
    };

    sig.onMessage = (m) async {
      switch (m.type) {
        case 'offer': // (tidak lazim: client jadi penerima) — tetap tangani
          await _pc?.setRemoteDescription(
            RTCSessionDescription(m.sdp?['sdp'] as String, 'offer'),
          );
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          sig.sendAnswer(m.from!, {
            'type': 'answer',
            'sdp': answer.sdp,
          });
          break;
        case 'answer':
          await _pc?.setRemoteDescription(
            RTCSessionDescription(m.sdp?['sdp'] as String, 'answer'),
          );
          break;
        case 'ice':
          final c = m.candidate;
          if (c != null && c['candidate'] != null) {
            await _pc?.addCandidate(RTCIceCandidate(
              c['candidate'] as String,
              c['sdpMid'] as String?,
              (c['sdpMLineIndex'] as num?)?.toInt(),
            ));
          }
          break;
        case 'bye':
          await stop();
          break;
        case 'error':
          if (m.error == 'peer-offline') _endCtrl.add(null);
          break;
      }
    };

    await _renderer.initialize();
    await sig.connect(signalingUrl, token);
    sig.sendPair(hostId, pin);
  }

  Future<void> _negotiate(String hostId) async {
    // STUN selalu ada (gratis tanpa batas). TURN diambil dari endpoint
    // /turn-ice (kredensial ber-TTL); bila belum dikonfigurasi, cukup STUN.
    final iceServers = <Map<String, dynamic>>[
      {'urls': ['stun:stun.cloudflare.com:3478']},
    ];
    final turn = await _fetchTurn();
    if (turn != null) iceServers.add(turn);

    final config = <String, dynamic>{'iceServers': iceServers};
    final pc = await createPeerConnection(config);
    _pc = pc;

    // PENTING: client = offerer yang MENERIMA video dari host. Tambah
    // transceiver video `recvonly` SEBELUM createOffer, agar offer memuat
    // m-line video (host akan mengisi track video ke transceiver ini).
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    // Data channel input: reliable + ordered (kontrol, bukan media).
    _inputChannel = await pc.createDataChannel('input', RTCDataChannelInit());

    pc.onIceCandidate = (candidate) {
      _sig?.sendIce(hostId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onTrack = (event) {
      if (event.track.kind == 'video') {
        _renderer.srcObject = event.streams.isNotEmpty ? event.streams[0] : null;
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _endCtrl.add(null);
      }
    };

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _sig?.sendOffer(hostId, {'type': 'offer', 'sdp': offer.sdp});
  }

  /// Turunkan base URL HTTP dari URL WebSocket signaling:
  /// `wss://signal.xystudio.my.id/ws` → `https://signal.xystudio.my.id`.
  static String _deriveBase(String signalingUrl) {
    var s = signalingUrl;
    if (s.startsWith('wss://')) s = 'https://${s.substring(6)}';
    else if (s.startsWith('ws://')) s = 'http://${s.substring(5)}';
    final pathStart = s.indexOf('/', s.indexOf('://') + 3);
    return pathStart == -1 ? s : s.substring(0, pathStart);
  }

  /// Ambil kredensial TURN dari endpoint /turn-ice (server signaling).
  ///
  /// Auth memakai token signaling perangkat ini (bukan admin secret). Bila
  /// TURN belum dikonfigurasi (503) atau gagal, kembalikan null — koneksi
  /// tetap jalan dengan STUN saja (cukup untuk LAN & sebagian besar NAT).
  Future<Map<String, dynamic>?> _fetchTurn() async {
    if (_sig == null) return null;
    try {
      final base = _signalingBase;
      final uri = Uri.parse('$base/turn-ice?id=$_deviceId&token=$_token');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      // body berbentuk { iceServers: [ ... ] } atau objek iceServers langsung.
      final servers = body['iceServers'];
      if (servers is List && servers.isNotEmpty) {
        return Map<String, dynamic>.from(servers.first as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Kirim event input ke host lewat data channel.
  void sendInput(String event) {
    if (_inputChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _inputChannel?.send(RTCDataChannelMessage(jsonEncode(event)));
    }
  }

  Future<void> stop() async {
    await _inputChannel?.close();
    await _pc?.close();
    await _renderer.dispose();
    await _sig?.close();
    _endCtrl.add(null);
  }
}
