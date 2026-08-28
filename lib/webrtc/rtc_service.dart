import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import '../core/devlog.dart';
import 'signaling_client.dart';

/// Fase koneksi sesi remote — dikonsumsi UI untuk menampilkan status jujur.
enum RtcPhase {
  /// Menghubungi signaling dan menunggu host menerima pairing.
  pairing,

  /// Pairing diterima; negosiasi SDP/ICE sedang berjalan.
  negotiating,

  /// PeerConnection tersambung; video/input aktif.
  connected,

  /// Host menolak pairing (password salah / limit percobaan).
  rejected,

  /// Host tidak online di signaling.
  peerOffline,

  /// Sesi berakhir (bye, gagal, atau ditutup lokal).
  ended,

  /// Kegagalan nyata: signaling putus, timeout, atau ICE gagal. UI wajib
  /// menampilkan error jelas (pesan di [RtcService.lastError]) — bukan
  /// konten dummy / layar diam yang membingungkan.
  error,
}

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
  bool _stopped = false;

  String _deviceId = '';
  String _token = '';
  String _signalingBase = '';

  /// Video renderer untuk ditampilkan di `RTCVideoView`.
  RTCVideoRenderer get renderer => _renderer;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();

  /// Aliran fase koneksi — satu sumber kebenaran untuk status UI.
  Stream<RtcPhase> get phases => _phaseCtrl.stream;
  final _phaseCtrl = StreamController<RtcPhase>.broadcast();

  /// Fase terakhir yang dipancarkan (dipakai watchdog timeout).
  RtcPhase _phase = RtcPhase.pairing;

  /// Pesan kegagalan terakhir — dibaca UI saat fase [RtcPhase.error].
  String? _lastError;

  /// Watchdog: pairing/negosiasi yang menggantung tidak boleh berputar
  /// selamanya menampilkan "MENGHUBUNGI HOST…".
  Timer? _watchdog;

  /// Pesan kegagalan terakhir (null bila tidak ada kesalahan).
  String? get lastError => _lastError;

  void _emit(RtcPhase phase) {
    _phase = phase;
    if (phase != RtcPhase.pairing && phase != RtcPhase.negotiating) {
      _watchdog?.cancel();
      _watchdog = null;
    }
    if (!_phaseCtrl.isClosed) _phaseCtrl.add(phase);
  }

  /// Transisi ke fase error dengan pesan yang bisa ditampilkan UI.
  void _fail(String message) {
    _lastError = message;
    _emit(RtcPhase.error);
  }

  /// Memulai sesi sebagai client terhadap [hostId].
  ///
  /// [stun] default pakai STUN publik gratis (tanpa biaya). TURN otomatis
  /// diambil dari endpoint `/turn-ice` bila server mengonfigurasinya.
  Future<void> startSession({
    required String signalingUrl,
    required String hostId,
    required String token,
    required String deviceId,
    String pin = '',
    List<String> stun = const ['stun:stun.cloudflare.com:3478'],
  }) async {
    _deviceId = deviceId;
    _token = token;
    _signalingBase = _deriveBase(signalingUrl);

    final sig = SignalingClient(deviceId: deviceId);
    _sig = sig;

    sig.onPairResponse = (accepted, from) async {
      if (!accepted) {
        _emit(RtcPhase.rejected);
        return;
      }
      _lastError = null;
      _emit(RtcPhase.negotiating);
      try {
        await _negotiate(hostId);
      } catch (e) {
        DevLog.e('rtc', 'negosiasi gagal', e);
        _fail('Negosiasi WebRTC gagal dimulai.');
      }
    };

    sig.onDisconnected = () {
      // Selama sesi masih hidup, putusnya soket signaling adalah kegagalan
      // nyata (bukan akhir normal — akhir normal lewat 'bye' → stop()).
      if (!_stopped) _fail('Koneksi signaling terputus.');
    };

    sig.onMessage = (m) async {
      switch (m.type) {
        case 'answer':
          await _pc?.setRemoteDescription(
            RTCSessionDescription(m.sdp?['sdp'] as String?, 'answer'),
          );
          break;
        case 'ice':
          final c = m.candidate;
          if (c != null && c['candidate'] != null) {
            await _pc?.addCandidate(
              RTCIceCandidate(
                c['candidate'] as String,
                c['sdpMid'] as String?,
                (c['sdpMLineIndex'] as num?)?.toInt(),
              ),
            );
          }
          break;
        case 'bye':
          await stop();
          break;
        case 'error':
          if (m.error == 'peer-offline') {
            _emit(RtcPhase.peerOffline);
          }
          break;
      }
    };

    await _renderer.initialize();
    _emit(RtcPhase.pairing);
    await sig.connect(signalingUrl, token);
    sig.sendPair(hostId, pin);

    // Watchdog: kalau host tidak menjawab atau jawaban tidak pernah sampai,
    // jangan biarkan UI menggantung di "MENGHUBUNGI HOST…" selamanya.
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 20), () {
      if (_stopped) return;
      if (_phase == RtcPhase.pairing || _phase == RtcPhase.negotiating) {
        _fail('Host tidak merespons (timeout 20 detik). Coba lagi.');
      }
    });
  }

  Future<void> _negotiate(String hostId) async {
    // STUN selalu ada (gratis tanpa batas). TURN diambil dari endpoint
    // /turn-ice (kredensial ber-TTL); bila belum dikonfigurasi, cukup STUN.
    final iceServers = <Map<String, dynamic>>[
      {
        'urls': ['stun:stun.cloudflare.com:3478'],
      },
    ];
    final turnServers = await _fetchTurn();
    iceServers.addAll(turnServers);

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
        _renderer.srcObject = event.streams.isNotEmpty
            ? event.streams[0]
            : null;
      }
    };

    pc.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _lastError = null;
          _emit(RtcPhase.connected);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _fail('Koneksi peer gagal (ICE) — tidak bisa menembus jaringan.');
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          // Close tanpa 'bye' = kegagalan, bukan akhir yang rapi.
          if (!_stopped) _fail('Koneksi peer ditutup paksa.');
        default:
          break;
      }
    };

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _sig?.sendOffer(hostId, {'type': 'offer', 'sdp': offer.sdp});
  }

  /// Turunkan base URL HTTP dari URL WebSocket signaling:
  /// `wss://signal.xystudio.my.id/ws` -> `https://signal.xystudio.my.id`.
  static String _deriveBase(String signalingUrl) {
    var s = signalingUrl;
    if (s.startsWith('wss://')) {
      s = 'https://${s.substring(6)}';
    } else if (s.startsWith('ws://')) {
      s = 'http://${s.substring(5)}';
    }
    final pathStart = s.indexOf('/', s.indexOf('://') + 3);
    return pathStart == -1 ? s : s.substring(0, pathStart);
  }

  /// Ambil kredensial TURN dari endpoint /turn-ice (server signaling).
  ///
  /// Auth memakai token signaling perangkat ini (bukan admin secret). Bila
  /// TURN belum dikonfigurasi (503) atau gagal, kembalikan null — koneksi
  /// tetap jalan dengan STUN saja (cukup untuk LAN & sebagian besar NAT).
  Future<List<Map<String, dynamic>>> _fetchTurn() async {
    if (_sig == null) return const [];
    try {
      final base = _signalingBase;
      final uri = Uri.parse('$base/turn-ice?id=$_deviceId&token=$_token');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body);
      final servers = body['iceServers'];
      if (servers is! List) return const [];
      return servers
          .whereType<Map>()
          .map((server) => Map<String, dynamic>.from(server))
          .where((server) => server['urls'] != null)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Kirim event input BINER ke host (encode via [InputCodec]).
  ///
  /// Protokol 8-byte little-endian — lihat `input_codec.dart` &
  /// `host/src/input.rs`. Dipanggil sangat sering (mouse move >100/dtk):
  /// tanpa JSON, tanpa alokasi string.
  void sendInput(Uint8List event) {
    final ch = _inputChannel;
    if (ch?.state == RTCDataChannelState.RTCDataChannelOpen) {
      ch?.send(RTCDataChannelMessage.fromBinary(event));
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _watchdog?.cancel();
    _watchdog = null;
    await _inputChannel?.close();
    await _pc?.close();
    await _renderer.dispose();
    await _sig?.close();
    _emit(RtcPhase.ended);
    await _phaseCtrl.close();
  }
}
