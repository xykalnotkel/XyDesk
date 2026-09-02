import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

import '../core/devlog.dart';
import 'input_codec.dart';
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

  /// Host sedang melayani sesi lain. Meski password benar, koneksi kedua
  /// DITOLAK — host hanya melayani satu sesi pada satu waktu dan tidak
  /// membiarkan sesi aktif diambil alih diam-diam.
  hostBusy,

  /// Sesi berakhir (bye, gagal, atau ditutup lokal).
  ended,

  /// Kegagalan nyata: signaling putus, timeout, atau ICE gagal. UI wajib
  /// menampilkan error jelas (pesan di [RtcService.lastError]) — bukan
  /// konten dummy / layar diam yang membingungkan.
  error,
}

/// Info display host — dikirim host lewat data channel (pesan meta).
@immutable
class HostDisplay {
  const HostDisplay({
    required this.index,
    required this.name,
    required this.width,
    required this.height,
  });

  final int index;
  final String name;
  final int width;
  final int height;

  factory HostDisplay.fromJson(Map<String, dynamic> j) => HostDisplay(
    index: j['index'] as int? ?? 0,
    name: j['name'] as String? ?? '',
    width: j['width'] as int? ?? 0,
    height: j['height'] as int? ?? 0,
  );
}

/// Meta yang dikirim host saat sesi dimulai (dan setiap kali berubah):
/// daftar layar, layar terpilih, dan status pipeline audio host.
@immutable
class HostMeta {
  const HostMeta({
    required this.displays,
    required this.wantedDisplay,
    required this.audioAvailable,
    required this.audioPipeline,
  });

  final List<HostDisplay> displays;
  final int wantedDisplay;
  final bool audioAvailable;
  final String audioPipeline;

  factory HostMeta.fromJson(Map<String, dynamic> j) => HostMeta(
    displays: [
      for (final d in j['displays'] as List? ?? [])
        HostDisplay.fromJson(d as Map<String, dynamic>),
    ],
    wantedDisplay: j['wanted'] as int? ?? 0,
    audioAvailable: (j['audio']?['available'] as bool?) ?? false,
    audioPipeline: (j['audio']?['pipeline'] as String?) ?? '',
  );
}

/// Layanan WebRTC client XyDesk.
///
/// Client = penelepon: buat `RTCPeerConnection`, `createOffer`, kirim ke host
/// lewat signaling, terima `answer` + `ice`, lalu render video. Input
/// (mouse/keyboard) dikirim lewat data channel yang **reliable** — kehilangan
/// satu event input tidak boleh terjadi.
///
/// Audio (rilis 6.1): transceiver audio `recvonly` memutar suara sistem host
/// (Opus) — host mengirim bila WASAPI Windows aktif. Mic perangkat dikirim
/// lewat track `sendonly` (getUserMedia) — host memutarnya di speaker PC.
/// Ringkasan kualitas sesi yang dibaca langsung dari `getStats()` WebRTC.
///
/// Semua angka di sini berasal dari mesin WebRTC, bukan perkiraan UI. Bila
/// sesi belum jalan, nilainya null dan panel menampilkan tanda strip — lebih
/// jujur daripada menampilkan angka yang kelihatan meyakinkan tapi karangan.
@immutable
class SessionStats {
  const SessionStats({
    this.width,
    this.height,
    this.fps,
    this.kbps,
    this.rttMs,
    this.jitterMs,
    this.packetLossPercent,
    this.codec,
    this.audioKbps,
  });

  final int? width;
  final int? height;
  final double? fps;
  final double? kbps;
  final double? rttMs;
  final double? jitterMs;
  final double? packetLossPercent;
  final String? codec;
  final double? audioKbps;

  bool get hasVideo => width != null && height != null;

  String get resolutionLabel =>
      hasVideo ? '$width x $height' : 'Belum ada gambar';

  String get fpsLabel => fps == null ? '-' : '${fps!.round()} fps';

  String get bitrateLabel {
    final v = kbps;
    if (v == null) return '-';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} Mbps';
    return '${v.round()} kbps';
  }

  String get rttLabel => rttMs == null ? '-' : '${rttMs!.round()} ms';

  String get lossLabel => packetLossPercent == null
      ? '-'
      : '${packetLossPercent!.toStringAsFixed(1)}%';

  String get audioLabel {
    final v = audioKbps;
    if (v == null) return 'Tidak ada suara masuk';
    return '${v.round()} kbps';
  }
}

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

  /// Renderer audio remote (suara sistem host). Pasang `RTCVideoView`-nya
  /// (boleh berukuran 1×1 / offstage) agar audio ikut diputar.
  RTCVideoRenderer get audioRenderer => _audioRenderer;
  final RTCVideoRenderer _audioRenderer = RTCVideoRenderer();

  RTCRtpTransceiver? _audioTransceiver;
  MediaStream? _micStream;

  /// Benar bila mic perangkat sedang dikirim ke host.
  bool _micEnabled = false;
  bool get micEnabled => _micEnabled;

  /// Benar bila pemutaran audio host aktif di sisi perangkat ini.
  bool _audioForwardEnabled = true;
  bool get audioForwardEnabled => _audioForwardEnabled;

  /// Meta terakhir dari host (layar + audio pipeline), beserta alirannya.
  HostMeta? get hostMeta => _hostMeta;
  HostMeta? _hostMeta;
  Stream<HostMeta> get hostMetaStream => _metaCtrl.stream;
  final _metaCtrl = StreamController<HostMeta>.broadcast();

  /// Statistik sesi, disegarkan tiap detik selama koneksi hidup.
  SessionStats get stats => _stats;
  SessionStats _stats = const SessionStats();
  Stream<SessionStats> get statsStream => _statsCtrl.stream;
  final _statsCtrl = StreamController<SessionStats>.broadcast();
  Timer? _statsTimer;
  int? _lastVideoBytes;
  int? _lastAudioBytes;
  int? _lastPacketsLost;
  int? _lastPacketsReceived;
  DateTime? _lastStatsAt;

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
          } else if (m.error == 'host-sibuk') {
            // Host sibuk: sesi lain sedang berjalan. UI menampilkan pesan
            // tendangan yang jelas — bukan error generik.
            _lastError = 'Perangkat sedang dipakai sesi lain. Coba lagi nanti.';
            _emit(RtcPhase.hostBusy);
          }
          break;
      }
    };

    await _renderer.initialize();
    await _audioRenderer.initialize();
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

    // Audio dua arah (host → perangkat, dan mic perangkat → host).
    //
    // Arahnya HARUS SendRecv sejak offer pertama. Menurut aturan JSEP arah
    // akhir adalah irisan penawaran klien dan keinginan host: dengan
    // RecvOnly, host menjawab SendOnly dan tidak pernah menerima — track
    // mic hasil getUserMedia tidak sampai ke host meski izin sudah diberikan.
    // Dengan SendRecv, addTrack(track mic) sekadar menempel ke transceiver
    // yang sudah ada: tidak ada offer kedua, tidak ada sesi yang dirombak
    // (host membangun Session baru untuk setiap offer yang diterimanya).
    _audioTransceiver = await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
    );

    // Data channel input: reliable + ordered (kontrol, bukan media).
    _inputChannel = await pc.createDataChannel('input', RTCDataChannelInit());
    _inputChannel!.onMessage = (message) {
      // Host mengirim PESAN TEKS meta (layar + audio) di channel ini —
      // input biner tetap satu arah (perangkat → host).
      if (!message.isBinary) _handleMeta(message.text);
    };

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
      } else if (event.track.kind == 'audio') {
        _audioRenderer.srcObject = event.streams.isNotEmpty
            ? event.streams[0]
            : null;
      }
    };

    pc.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _startStatsPolling();
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

  /// Meta teks dari host (data channel) — layar & status audio.
  void _handleMeta(String text) {
    try {
      final data = jsonDecode(text);
      if (data is Map<String, dynamic> && data['type'] == 'meta') {
        final meta = HostMeta.fromJson(data);
        _hostMeta = meta;
        if (!_metaCtrl.isClosed) _metaCtrl.add(meta);
      }
    } catch (e) {
      DevLog.w('rtc', 'meta host tidak valid', '$e');
    }
  }

  /// Minta host mengganti monitor (berlaku segera — capture di-respawn).
  /// Event 0x07 DISPLAY_SELECT pada protokol input biner.
  void selectDisplay(int index) {
    final ch = _inputChannel;
    if (ch?.state != RTCDataChannelState.RTCDataChannelOpen) return;
    ch!.send(RTCDataChannelMessage.fromBinary(InputCodec.displaySelect(index)));
  }

  /// Aktif/nonaktifkan pemutaran audio host (transceiver direction —
  /// tanpa negosiasi ulang, tidak memutus sesi).
  Future<void> setAudioForwardEnabled(bool on) async {
    _audioForwardEnabled = on;
    final t = _audioTransceiver;
    if (t == null) return;
    try {
      await t.setDirection(
        // Bukan Inactive: itu mematikan mic yang sedang dikirim juga.
        // SendOnly = suara host berhenti, mic perangkat tetap jalan.
        on ? TransceiverDirection.SendRecv : TransceiverDirection.SendOnly,
      );
    } catch (e) {
      DevLog.w('rtc', 'set direction audio gagal', '$e');
    }
  }

  /// Aktifkan mic perangkat (minta izin saat pertama kali) dan kirim track
  /// audio ke host. Gagal → kembalikan pesan untuk ditampilkan UI.
  Future<String?> enableMic() async {
    if (_micEnabled) return null;
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true},
        'video': false,
      });
      final track = stream.getAudioTracks().first;
      // addTrack menempel ke transceiver audio SendRecv yang sudah ada
      // (dibuat saat negotiate()), jadi TIDAK perlu offer baru. RTP mic
      // langsung mengalir di m-line yang sudah disepakati sejak awal.
      await _pc?.addTrack(track, stream);
      _micStream = stream;
      _micEnabled = true;
      return null;
    } catch (e) {
      DevLog.w('rtc', 'mic gagal', '$e');
      return 'Izin mikrofon ditolak atau mic tidak tersedia.';
    }
  }

  /// Matikan mic — stop semua track lokal (stream berakhir untuk host).
  Future<void> disableMic() async {
    if (!_micEnabled) return;
    final stream = _micStream;
    _micStream = null;
    _micEnabled = false;
    if (stream != null) {
      for (final t in stream.getTracks()) {
        try {
          await t.stop();
        } catch (_) {}
      }
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

  /// Mulai membaca `getStats()` tiap detik. Angka bitrate dihitung dari
  /// selisih byte antar pembacaan, bukan dari nilai kumulatif mentah.
  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final pc = _pc;
      if (pc == null || _stopped) return;
      try {
        await _collectStats(pc);
      } catch (error) {
        DevLog.w('rtc', 'getStats gagal', '$error');
      }
    });
  }

  Future<void> _collectStats(RTCPeerConnection pc) async {
    final reports = await pc.getStats();
    final now = DateTime.now();
    int? width, height, videoBytes, audioBytes, packetsLost, packetsReceived;
    double? fps, rtt, jitter;
    String? codecId, codecName;

    for (final r in reports) {
      final v = r.values;
      switch (r.type) {
        case 'inbound-rtp':
          final kind = v['kind'] ?? v['mediaType'];
          if (kind == 'video') {
            width = (v['frameWidth'] as num?)?.toInt();
            height = (v['frameHeight'] as num?)?.toInt();
            fps = (v['framesPerSecond'] as num?)?.toDouble();
            videoBytes = (v['bytesReceived'] as num?)?.toInt();
            packetsLost = (v['packetsLost'] as num?)?.toInt();
            packetsReceived = (v['packetsReceived'] as num?)?.toInt();
            codecId = v['codecId'] as String?;
          } else if (kind == 'audio') {
            audioBytes = (v['bytesReceived'] as num?)?.toInt();
            jitter = (v['jitter'] as num?)?.toDouble();
          }
        case 'candidate-pair':
          final nominated = v['nominated'] == true || v['state'] == 'succeeded';
          if (nominated && v['currentRoundTripTime'] != null) {
            rtt = ((v['currentRoundTripTime'] as num).toDouble()) * 1000;
          }
        case 'codec':
          if (codecId != null && r.id == codecId) {
            codecName = (v['mimeType'] as String?)?.split('/').last;
          }
      }
    }
    // Pencarian codec kedua: laporan codec bisa datang sebelum inbound-rtp.
    if (codecName == null && codecId != null) {
      for (final r in reports) {
        if (r.id == codecId) {
          codecName = (r.values['mimeType'] as String?)?.split('/').last;
        }
      }
    }

    final last = _lastStatsAt;
    final elapsed = last == null
        ? null
        : now.difference(last).inMilliseconds / 1000.0;
    double? kbps, audioKbps, loss;
    if (elapsed != null && elapsed > 0.2) {
      final pv = _lastVideoBytes;
      if (videoBytes != null && pv != null && videoBytes >= pv) {
        kbps = (videoBytes - pv) * 8 / 1000 / elapsed;
      }
      final pa = _lastAudioBytes;
      if (audioBytes != null && pa != null && audioBytes >= pa) {
        audioKbps = (audioBytes - pa) * 8 / 1000 / elapsed;
      }
      final pl = _lastPacketsLost;
      final pr = _lastPacketsReceived;
      if (packetsLost != null &&
          packetsReceived != null &&
          pl != null &&
          pr != null) {
        final dLost = packetsLost - pl;
        final dRecv = packetsReceived - pr;
        final total = dLost + dRecv;
        if (total > 0) loss = (dLost / total) * 100;
      }
    }

    _lastVideoBytes = videoBytes;
    _lastAudioBytes = audioBytes;
    _lastPacketsLost = packetsLost;
    _lastPacketsReceived = packetsReceived;
    _lastStatsAt = now;

    _stats = SessionStats(
      width: width,
      height: height,
      fps: fps,
      kbps: kbps,
      rttMs: rtt,
      jitterMs: jitter == null ? null : jitter * 1000,
      packetLossPercent: loss,
      codec: codecName?.toUpperCase(),
      audioKbps: audioKbps,
    );
    if (!_statsCtrl.isClosed) _statsCtrl.add(_stats);
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _watchdog?.cancel();
    _watchdog = null;
    _statsTimer?.cancel();
    _statsTimer = null;
    await disableMic();
    await _inputChannel?.close();
    await _pc?.close();
    await _renderer.dispose();
    await _audioRenderer.dispose();
    await _sig?.close();
    _emit(RtcPhase.ended);
    await _phaseCtrl.close();
    await _metaCtrl.close();
    await _statsCtrl.close();
  }
}
