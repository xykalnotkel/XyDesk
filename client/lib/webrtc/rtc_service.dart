import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

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
    final config = <String, dynamic>{
      'iceServers': [
        // STUN gratis Cloudflare; TURN (turn.cloudflare.com) ditambahkan bila
        // koneksi direct gagal — lihat docs/FREE-STACK.md (1 TB/bln gratis).
        {'urls': ['stun:stun.cloudflare.com:3478']},
      ],
    };
    final pc = await createPeerConnection(config);
    _pc = pc;

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
