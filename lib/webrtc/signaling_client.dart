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
    this.name,
    this.platform,
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

  /// Label diri untuk panel host: `name` = nama perangkat/akun, `platform`
  /// = 'android' | 'ios' | 'linux' | 'macos' | 'windows' | 'web'.
  ///
  /// Hanya dikirim pada pesan `pair`. Host cuma Menampilkannya (chip "siapa
  /// yang menonton") dan tidak pernah menjadikannya dasar keputusan akses, jadi
  /// nilai kosong/tidak akurat tidak berbahaya. Hub Cloudflare meneruskan
  /// field tambahan apa adanya; hub Go dev (`signaling/protocol.go`) memakai
  /// struct bertipe dan akan MEMBUANG keduanya sampai role Backend ikut
  /// menambahkannya (sudah dicatat di HANDOFF).
  final String? name;
  final String? platform;

  Map<String, dynamic> toJson() => {
    'type': type,
    if (to != null) 'to': to,
    if (from != null) 'from': from,
    if (pin != null) 'pin': pin,
    if (accepted != null) 'accepted': accepted,
    if (sdp != null) 'sdp': sdp,
    if (candidate != null) 'candidate': candidate,
    if (reason != null) 'reason': reason,
    if (name != null) 'name': name,
    if (platform != null) 'platform': platform,
  };

  factory SignalMessage.fromJson(Map<String, dynamic> j) => SignalMessage(
    type: j['type'] as String? ?? '',
    to: j['to'] as String?,
    from: j['from'] as String?,
    pin: j['pin'] as String?,
    accepted: j['accepted'] as bool?,
    name: j['name'] as String?,
    platform: j['platform'] as String?,
    sdp: j['sdp'] as Map<String, dynamic>?,
    candidate: j['candidate'] as Map<String, dynamic>?,
    error: j['error'] as String?,
    reason: j['reason'] as String?,
    devices: (j['devices'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
  );
}

/// Kegagalan menyambung ke server signaling, dengan pesan siap tampil.
///
/// Dibedakan dari galat umum supaya [RtcService] bisa menampilkan sebab yang
/// sebenarnya ("server tidak menjawab") alih-alih pesan generik
/// ("Koneksi WebRTC gagal dimulai") yang tidak memberi tahu pengguna apa yang
/// harus dilakukan.
class SignalingException implements Exception {
  const SignalingException(this.message);

  final String message;

  @override
  String toString() => 'SignalingException: $message';
}

/// Klien signaling untuk app XyDesk (role=client).
///
/// Membungkus WebSocket ke server Go. Callback dipicu oleh pesan masuk;
/// pasangkan dengan [RtcService] untuk negosiasi WebRTC.
class SignalingClient {
  SignalingClient({required this.deviceId});

  /// Batas waktu handshake WebSocket.
  ///
  /// Tanpa ini, handshake yang tidak pernah selesai (DNS hitam, TLS ditahan
  /// proxy, server diam) membuat UI menggantung sampai watchdog 20 detik di
  /// `RtcService` — terlalu lama untuk kegagalan yang sebenarnya sudah
  /// terjadi di detik pertama.
  static const handshakeTimeout = Duration(seconds: 10);

  final String deviceId;
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  bool _open = false;

  /// Panggil saat server mengirim `pair-response` (host menjawab pairing).
  void Function(bool accepted, String? from)? onPairResponse;

  /// Panggil saat tawaran/balasan/ICE datang — teruskan ke RtcService.
  void Function(SignalMessage msg)? onMessage;

  /// Panggil saat koneksi terputus.
  void Function()? onDisconnected;

  /// Benar hanya setelah handshake WebSocket selesai.
  ///
  /// Sebelumnya ini `_ch != null`, yang diisi tepat setelah
  /// `WebSocketChannel.connect(...)` — panggilan itu lazy dan langsung
  /// kembali, jadi properti ini mengklaim "tersambung" bahkan sebelum soket
  /// terbuka, dan tetap mengklaimnya setelah handshake gagal. Setiap UI yang
  /// membacanya melaporkan status yang salah.
  bool get isConnected => _open;

  Future<void> connect(String url, String token) async {
    // Token dilewatkan via query (?token=) — server Go menerima ini, jadi
    // tidak perlu header kustom (cocok untuk web_socket_channel di semua
    // platform: Android/iOS/web/desktop).
    final wsUrl = '$url?id=$deviceId&role=client&token=$token';
    final ch = WebSocketChannel.connect(Uri.parse(wsUrl));
    _ch = ch;
    _open = false;

    _sub = ch.stream.listen(
      (data) {
        final m = SignalMessage.fromJson(
          jsonDecode(data as String) as Map<String, dynamic>,
        );
        switch (m.type) {
          case 'pair-response':
            onPairResponse?.call(m.accepted ?? false, m.from);
            break;
          default:
            onMessage?.call(m);
        }
      },
      onDone: () {
        _open = false;
        onDisconnected?.call();
      },
      onError: (_) {
        _open = false;
        onDisconnected?.call();
      },
    );

    // Tunggu handshake SEBELUM mengklaim tersambung atau mengirim apa pun.
    //
    // Pesan yang dikirim sebelum soket terbuka hanya di-buffer; kalau soket
    // kemudian gagal, `hello` dan `pair` hilang tanpa jejak dan pengguna
    // menatap "MENGHUBUNGI HOST…" sampai watchdog menyerah. Menunggu di sini
    // mengubah kegagalan diam-diam itu menjadi pesan yang jelas.
    try {
      await ch.ready.timeout(handshakeTimeout);
    } catch (error) {
      _open = false;
      // Batalkan langganan lebih dulu: kalau tidak, penutupan soket ikut
      // memicu `onDisconnected` dan satu kegagalan dilaporkan dua kali dengan
      // pesan berbeda — mana yang sampai ke UI jadi tidak bisa ditebak.
      await _sub?.cancel();
      _sub = null;
      unawaited(_ch?.sink.close());
      _ch = null;
      throw SignalingException(
        error is TimeoutException
            ? 'Server signaling tidak menjawab dalam '
                  '${handshakeTimeout.inSeconds} detik. Periksa koneksi internet.'
            : 'Tidak dapat menghubungi server signaling.',
      );
    }

    _open = true;

    // daftar sebagai client
    _send(SignalMessage(type: 'hello', to: deviceId, reason: 'client'));
  }

  /// Normalisasi ID perangkat: buang spasi & tanda hubung, sehingga
  /// "123 456 789" / "123-456-789" → "123456789" (cocok dgn ID host).
  static String normalizeId(String id) => id.replaceAll(RegExp(r'[\s\-]'), '');

  /// Label diri untuk `pair` — diisi lapisan UI (halaman Connect) sebelum
  /// connect. Dibiarkan bisa `null` supaya layanan signaling tetap bisa
  /// dipakai tanpa tahu-menahu soal identitas: host menampilkan ID saja.
  static String? selfName;
  static String? selfPlatform;

  void sendPair(String hostId, String pin) => _send(
    SignalMessage(
      type: 'pair',
      to: normalizeId(hostId),
      pin: pin,
      name: selfName,
      platform: selfPlatform,
    ),
  );

  void sendOffer(String hostId, Map<String, dynamic> sdp) =>
      _send(SignalMessage(type: 'offer', to: normalizeId(hostId), sdp: sdp));

  void sendAnswer(String clientId, Map<String, dynamic> sdp) =>
      _send(SignalMessage(type: 'answer', to: clientId, sdp: sdp));

  void sendIce(String peerId, Map<String, dynamic> candidate) =>
      _send(SignalMessage(type: 'ice', to: peerId, candidate: candidate));

  void sendBye(String peerId) => _send(SignalMessage(type: 'bye', to: peerId));

  void _send(SignalMessage m) {
    final sink = _ch?.sink;
    if (sink == null) return;
    try {
      sink.add(jsonEncode(m.toJson()));
    } catch (_) {
      // Soket sudah mati. Melempar dari dalam sini hanya berakhir di
      // `runZonedGuarded` — tercatat di log, tidak terlihat pengguna, dan
      // layar tetap menggantung. Lebih jujur menandai putus dan membiarkan
      // `RtcService` menampilkan galat.
      _open = false;
      onDisconnected?.call();
    }
  }

  Future<void> close() async {
    _open = false;
    await _sub?.cancel();
    await _ch?.sink.close();
    _ch = null;
  }
}
