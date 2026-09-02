import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/devlog.dart';
import '../../core/l10n_bridge.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../webrtc/input_codec.dart';
import '../../webrtc/session_transport.dart';
import '../../webrtc/vk_codes.dart';
import '../../widgets/brand.dart';
import '../../widgets/hud_glyphs.dart';
import 'media_capabilities.dart';
import 'session_panels.dart';
import 'virtual_keyboard.dart';
import '../../core/display_control.dart';

/// Adaptive remote-session surface.
///
/// Gaming and Desktop are two views of one session instead of separate pages.
/// The always-visible HUD is intentionally small; advanced controls live in a
/// single readable end panel rather than the former eight-category side rail.
class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
    this.password = '',
  });

  final String deviceName;

  final String deviceId;

  /// Password pairing host. Kosong = coba pairing tanpa password (host
  /// menolak bila mensyaratkan) atau tampilkan preview untuk mode tamu.
  final String password;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> {
  bool _connecting = true;
  bool _overlayVisible = true;
  bool _panelVisible = false;
  bool _keyboardVisible = false;
  SessionPanelSection _panelSection = SessionPanelSection.stream;
  int _panelRevision = 0;
  Timer? _idleTimer;
  Timer? _connectTimer;
  late SessionSettings _settings;

  /// Aliran isi papan klip PC (balasan permintaan 0x09).
  StreamSubscription<String>? _clipboardSub;
  KbLayout _keyboardLayout = KbLayout.split;
  double _keyboardOpacity = 0.95;
  late final SessionTransport _transport;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(settingsProvider);
    _transport = SessionTransport(jwt: ref.read(authProvider).token);
    _transport.addListener(_onTransportChanged);
    unawaited(
      _transport.start(hostId: widget.deviceId, password: widget.password),
    );
    _settings = SessionSettings(
      pcAudioRequested: preferences.audioEnabled,
      microphoneRequested: preferences.micPassthrough,
      haptics: preferences.haptics,
      pointerLock: preferences.relativeMouseMode,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Selama sesi, pengguna sering hanya menonton — tanpa sentuhan, Android
    // memadamkan layar dan sesi terlihat seolah putus.
    if (preferences.keepScreenOn) {
      unawaited(DisplayControl.setKeepScreenOn(true));
    }
    DevLog.i(
      'sesi',
      'Membuka preview sesi ke ${widget.deviceName}',
      'id=${widget.deviceId}',
    );
    final platformReduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    final reduceMotion = preferences.reduceMotion || platformReduce;
    _connectTimer = Timer(Duration(milliseconds: reduceMotion ? 0 : 450), () {
      if (!mounted) return;
      setState(() => _connecting = false);
      DevLog.i('sesi', 'Preview UI siap — transport belum aktif');
      _restartIdleTimer();
    });
  }

  void _onTransportChanged() {
    if (!mounted) return;
    final s = _transport.state;
    DevLog.i(
      'sesi',
      'Transport',
      '${s.status}${s.message == null ? '' : ' - ${s.message}'}',
    );
    // Papan klip PC hanya bisa diterima setelah kanal datanya terbuka, yang
    // terjadinya bersamaan dengan sesi menjadi live.
    if (s.live && _clipboardSub == null) {
      final rtc = _transport.rtc;
      if (rtc != null) {
        _clipboardSub = rtc.clipboardStream.listen(_onClipboardFromHost);
      }
    }
    // Begitu live, HUD disembunyikan supaya layar remote bersih; pengguna
    // memunculkannya lewat handle kecil di tepi kanan.
    if (s.live && _overlayVisible) {
      _overlayVisible = false;
      _idleTimer?.cancel();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _transport.removeListener(_onTransportChanged);
    _transport.dispose();
    _idleTimer?.cancel();
    _connectTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Flag layar-tetap-menyala milik window, bukan halaman. Kalau tidak
    // dicabut di sini, ia akan tetap aktif di seluruh aplikasi setelah sesi
    // ditutup dan diam-diam menghabiskan baterai.
    unawaited(DisplayControl.setKeepScreenOn(false));
    _clipboardSub?.cancel();
    DevLog.i('sesi', 'Menutup sesi');
    super.dispose();
  }

  /// Kirim satu kombinasi tombol (modifier sticky + tombol utama) ke host.
  void _sendKeyCombo(String label, Set<String> modifiers) {
    if (!_transport.state.live) return;
    final vk = vkForLabel(label);
    if (vk == null) return;
    final modVks = modifiers
        .map(vkForLabel)
        .whereType<int>()
        .toList(growable: false);
    for (final m in modVks) {
      _transport.sendInput(InputCodec.key(m, down: true));
    }
    _transport.sendInput(InputCodec.key(vk, down: true));
    _transport.sendInput(InputCodec.key(vk, down: false));
    for (final m in modVks.reversed) {
      _transport.sendInput(InputCodec.key(m, down: false));
    }
  }

  /// Kirim isi papan klip perangkat ini ke PC (0x08 CLIPBOARD_SET).
  ///
  /// Dulu ini memakai 0x06 TEXT, yang berarti host MENGETIKKAN teksnya ke
  /// jendela yang sedang aktif. Itu berguna, tetapi bukan yang dijanjikan
  /// pengaturan "Sinkronisasi papan klip" — dan berbahagia kalau jendela
  /// yang aktif bukan yang pengguna maksud. Sekarang isinya betul-betul
  /// menjadi papan klip PC, lalu pengguna menekan Ctrl+V sendiri.
  Future<void> _sendClipboard() async {
    if (!_transport.state.live) {
      _showUnavailable('Clipboard butuh sesi yang tersambung.');
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      _showUnavailable('Clipboard kosong.');
      return;
    }
    // Batas ukuran diurus kodek (64 KiB, dipotong di batas karakter).
    _transport.sendInput(InputCodec.clipboardSet(text));
    _showUnavailable('Tersalin ke papan klip PC — tekan Ctrl+V di sana.');
  }

  /// Minta PC mengirim isi papan klipnya ke ponsel (0x09 CLIPBOARD_REQ).
  ///
  /// Sengaja model tarik: host tidak punya pengamat papan klip Windows,
  /// jadi arah PC → HP tidak bisa dijanjikan otomatis tanpa berbohong.
  /// Hasilnya datang ke [_onClipboardFromHost].
  Future<void> _requestClipboard() async {
    if (!_transport.state.live) {
      _showUnavailable('Clipboard butuh sesi yang tersambung.');
      return;
    }
    _transport.sendInput(InputCodec.clipboardRequest());
    _showUnavailable('Meminta isi papan klip PC…');
  }

  /// Isi papan klip PC yang diminta — tulis ke papan klip perangkat ini.
  Future<void> _onClipboardFromHost(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text.isEmpty
              ? 'Papan klip PC kosong, atau isinya bukan teks.'
              : 'Isi papan klip PC sudah ada di ponsel kamu.',
        ),
      ),
    );
  }

  void _leaveSession() {
    // Offline previews are deliberately not added to remote-session history.
    // History should begin only after a real negotiated transport is active.
    unawaited(_transport.shutdown());
    Navigator.of(context).maybePop();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(D.idleHide, () {
      if (mounted && !_panelVisible && !_keyboardVisible) {
        setState(() => _overlayVisible = false);
      }
    });
  }

  void _wake() {
    if (!_overlayVisible) setState(() => _overlayVisible = true);
    _restartIdleTimer();
  }

  void _openPanel([SessionPanelSection section = SessionPanelSection.stream]) {
    setState(() {
      _panelSection = section;
      _panelRevision++;
      _panelVisible = true;
      _overlayVisible = true;
    });
    _idleTimer?.cancel();
  }

  void _closePanel() {
    setState(() => _panelVisible = false);
    _restartIdleTimer();
  }

  void _showKeyboard() {
    setState(() {
      _keyboardVisible = true;
      _panelVisible = false;
      _overlayVisible = true;
    });
    _idleTimer?.cancel();
  }

  /// Aktif/nonaktifkan pemutaran audio sistem host (transceiver direction —
  /// tanpa negosiasi ulang, tidak memutus sesi).
  Future<void> _toggleAudioForward() async {
    final rtc = _transport.rtc;
    if (rtc == null) return;
    final next = !_settings.pcAudioRequested;
    await rtc.setAudioForwardEnabled(next);
    if (!mounted) return;
    setState(() => _settings = _settings.copyWith(pcAudioRequested: next));
  }

  /// Aktif/nonaktifkan mic perangkat → host (meminta izin saat pertama kali).
  Future<void> _toggleMic() async {
    final rtc = _transport.rtc;
    if (rtc == null) return;
    if (_settings.microphoneRequested) {
      await rtc.disableMic();
      if (!mounted) return;
      setState(
        () => _settings = _settings.copyWith(microphoneRequested: false),
      );
      return;
    }
    final err = await rtc.enableMic();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _settings = _settings.copyWith(microphoneRequested: true));
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) return _ConnectingView(name: widget.deviceName);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 440;
          final panelWidth = (constraints.maxWidth * 0.46)
              .clamp(340.0, 410.0)
              .toDouble();
          return Stack(
            children: [
              Positioned.fill(
                child: _transport.state.live
                    ? _RemoteVideoSurface(
                        transport: _transport,
                        relativeMouse: _settings.pointerLock,
                        // Saat live, tap adalah klik kiri murni — kontrol
                        // dibuka lewat rail di tepi kanan, bukan tap layar.
                        onWake: () {},
                      )
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _wake,
                        child: _RemoteScreenPlaceholder(
                          experience: _settings.experience,
                          transport: _transport.state,
                          onRetry: () => _transport.retry(
                            hostId: widget.deviceId,
                            password: widget.password,
                          ),
                        ),
                      ),
              ),
              // Pemutar audio remote (suara sistem host) — 1×1 transparan.
              // Wajib berada di pohon widget agar track Opus diputar.
              if (_transport.state.live)
                Positioned(
                  left: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0,
                      child: SizedBox(
                        width: 1,
                        height: 1,
                        child: RTCVideoView(
                          _transport.rtc!.audioRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_keyboardVisible &&
                  !_panelVisible &&
                  _settings.experience == SessionExperience.gaming &&
                  _settings.showGamingControls)
                _GamingControls(
                  compact: compact,
                  onKey: (vk, down) {
                    if (_transport.state.live) {
                      _transport.sendInput(InputCodec.key(vk, down: down));
                    }
                  },
                ),
              // Satu-satunya HUD yang tersisa: rail tipis menempel di tepi
              // kanan. Tidak ada lagi bar melayang di tengah atas maupun
              // tengah bawah yang menutupi gambar PC.
              if (!_keyboardVisible)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Center(
                    child: _SessionRail(
                      expanded: _overlayVisible,
                      compact: compact,
                      showClipboard:
                          _settings.experience == SessionExperience.desktop,
                      audioRequested: _settings.pcAudioRequested,
                      microphoneRequested: _settings.microphoneRequested,
                      onToggleExpanded: () {
                        if (_overlayVisible) {
                          setState(() => _overlayVisible = false);
                          _idleTimer?.cancel();
                        } else {
                          _wake();
                        }
                      },
                      onAudio: _toggleAudioForward,
                      onMicrophone: _toggleMic,
                      onKeyboard: _showKeyboard,
                      onClipboard: _sendClipboard,
                      onClipboardPull: _requestClipboard,
                      onSettings: () => _openPanel(),
                      onDisconnect: _confirmDisconnect,
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: D.panel,
                curve: D.curve,
                top: 0,
                bottom: 0,
                right: _panelVisible ? 0 : -panelWidth - 24,
                width: panelWidth,
                child: SessionControlPanel(
                  key: ValueKey((_panelSection, _panelRevision)),
                  initialSection: _panelSection,
                  deviceName: widget.deviceName,
                  state: _settings,
                  transport: _transport.state,
                  rtc: _transport.rtc,
                  onChanged: (value) => setState(() => _settings = value),
                  onClose: _closePanel,
                  onDisconnect: _confirmDisconnect,
                ),
              ),
              AnimatedPositioned(
                duration: D.sheet,
                curve: D.curve,
                left: 0,
                right: 0,
                bottom: _keyboardVisible ? 0 : -360,
                child: VirtualKeyboard(
                  layout: _keyboardLayout,
                  opacity: _keyboardOpacity,
                  onLayoutChanged: (value) =>
                      setState(() => _keyboardLayout = value),
                  onOpacityChanged: (value) =>
                      setState(() => _keyboardOpacity = value),
                  onKeyWithModifiers: _sendKeyCombo,
                  onDismiss: () {
                    setState(() => _keyboardVisible = false);
                    _restartIdleTimer();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    _wake();
  }

  Future<void> _confirmDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr('session_disconnect_confirm'),
          style: const TextStyle(fontSize: 16),
        ),
        content: const Text(
          'Preview sesi akan ditutup. PC host tetap menyala dan dapat dipilih '
          'kembali kapan saja.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.tr('session_disconnect_action'),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _leaveSession();
  }
}

class _ConnectingView extends StatelessWidget {
  const _ConnectingView({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 18),
                Text(
                  'Menyiapkan preview $name',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHiDark,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Menyiapkan preview kontrol',
                  style: TextStyle(fontSize: 12, color: AppColors.textMidDark),
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: c.textLow.withValues(alpha: 0.18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Permukaan video sungguhan + input trackpad.
///
/// Gestur (mode desktop/trackpad):
///   - seret satu jari  -> gerak pointer relatif
///   - ketuk            -> klik kiri
///   - seret dua jari   -> scroll
class _RemoteVideoSurface extends StatelessWidget {
  const _RemoteVideoSurface({
    required this.transport,
    required this.relativeMouse,
    required this.onWake,
  });

  final SessionTransport transport;
  final bool relativeMouse;
  final VoidCallback onWake;

  void _click(int button) {
    transport.sendInput(InputCodec.mouseButton(button, down: true));
    transport.sendInput(InputCodec.mouseButton(button, down: false));
  }

  @override
  Widget build(BuildContext context) {
    final renderer = transport.rtc?.renderer;
    if (renderer == null) return const ColoredBox(color: Colors.black);
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onWake();
          _click(MouseButton.left);
        },
        onSecondaryTap: () => _click(MouseButton.right),
        // Satu handler scale untuk dua gestur (pan & scale tidak boleh
        // dipasang bersamaan di GestureDetector yang sama):
        //   1 jari  = gerak pointer (rel/abs sesuai mode),
        //   2 jari  = scroll trackpad (WHEEL_DELTA konvensi Windows).
        onScaleUpdate: (d) {
          if (d.pointerCount >= 2) {
            final dy = (d.focalPointDelta.dy * 5).round();
            final dx = (d.focalPointDelta.dx * 5).round();
            if (dx != 0 || dy != 0) {
              transport.sendInput(InputCodec.scroll(dx, dy));
            }
            return;
          }
          if (relativeMouse) {
            transport.sendInput(
              InputCodec.mouseMoveRel(
                d.focalPointDelta.dx.round(),
                d.focalPointDelta.dy.round(),
              ),
            );
          } else {
            // Mode absolut: posisi jari dipetakan langsung ke layar host
            // (fraksi 0..1 dari permukaan video).
            transport.sendInput(
              InputCodec.mouseMoveAbs(
                d.localFocalPoint.dx / constraints.maxWidth,
                d.localFocalPoint.dy / constraints.maxHeight,
              ),
            );
          }
        },
        child: RTCVideoView(
          renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        ),
      ),
    );
  }
}

class _RemoteScreenPlaceholder extends StatelessWidget {
  const _RemoteScreenPlaceholder({
    required this.experience,
    required this.transport,
    this.onRetry,
  });

  final SessionExperience experience;
  final TransportState transport;

  /// Dipanggil tombol "Coba lagi" (hanya tampil pada status error).
  final VoidCallback? onRetry;

  String get _statusLabel => switch (transport.status) {
    TransportStatus.preview => 'PREVIEW • TRANSPORT OFFLINE',
    TransportStatus.pairing => 'MENGHUBUNGI HOST…',
    TransportStatus.negotiating => 'NEGOSIASI KONEKSI…',
    TransportStatus.connected => 'TERSAMBUNG',
    TransportStatus.rejected => 'PAIRING DITOLAK',
    TransportStatus.peerOffline => 'HOST TIDAK ONLINE',
    TransportStatus.hostBusy => 'PERANGKAT SEDANG DIPAKAI',
    TransportStatus.ended => 'SESI BERAKHIR',
    TransportStatus.error => 'KONEKSI GAGAL',
  };

  /// Konten saat status error: kegagalan ditampilkan terang-terangan
  /// (bukan ilustrasi dekoratif) + tombol coba lagi.
  List<Widget> _errorContent() {
    return [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.danger.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: const Icon(
          LucideIcons.alertTriangle,
          size: 34,
          color: AppColors.danger,
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'KONEKSI GAGAL',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.danger,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        transport.message ?? 'Tidak dapat terhubung ke host.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xD9FFFFFF),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: onRetry,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.danger.withValues(alpha: 0.9),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        ),
        child: const Text(
          'Coba lagi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
      ),
    ];
  }

  /// Konten saat host sibuk: koneksi DITOLAK karena sesi lain sedang
  /// berjalan. Bukan error teknis — pengguna diarahkan menunggu.
  List<Widget> _busyContent() {
    return [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: const Icon(
          LucideIcons.userX,
          size: 32,
          color: AppColors.warning,
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'DITOLAK • SEDANG DIPAKAI',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.warning,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        transport.message ?? 'Perangkat sedang dipakai sesi lain.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xD9FFFFFF),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: onRetry,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.warning.withValues(alpha: 0.9),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        ),
        child: const Text(
          'Coba lagi',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1E26), Color(0xFF0E1015), Color(0xFF171920)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _AmbientGridPainter()),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: transport.status == TransportStatus.error
                    ? _errorContent()
                    : transport.status == TransportStatus.hostBusy
                    ? _busyContent()
                    : [
                        Opacity(
                          opacity: 0.52,
                          child: Image.asset(
                            experience == SessionExperience.gaming
                                ? Img.gaming
                                : Img.screen,
                            width: 112,
                            height: 112,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(R.sm),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Text(
                            _statusLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Layar remote akan tampil di sini',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xA6FFFFFF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          transport.message ??
                              'HUD dapat dipreview, tetapi belum mengirim input atau audio.',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0x66FFFFFF),
                          ),
                        ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGridPainter extends CustomPainter {
  const _AmbientGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1;
    const spacing = 54.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Rail kontrol sesi.
///
/// Menempel di tepi kanan dan hanya selebar ikon. Versi sebelumnya memakai
/// bar melayang di tengah atas dan dock di tengah bawah; dua-duanya menutupi
/// bagian layar PC yang paling sering dilihat. Rail ini bisa dilipat jadi tab
/// kecil, dan saat dilipat tidak ada apa pun yang menghalangi gambar.
class _SessionRail extends StatelessWidget {
  const _SessionRail({
    required this.expanded,
    required this.compact,
    required this.showClipboard,
    required this.audioRequested,
    required this.microphoneRequested,
    required this.onToggleExpanded,
    required this.onAudio,
    required this.onMicrophone,
    required this.onKeyboard,
    required this.onClipboard,
    required this.onClipboardPull,
    required this.onSettings,
    required this.onDisconnect,
  });

  final bool expanded;
  final bool compact;
  final bool showClipboard;
  final bool audioRequested;
  final bool microphoneRequested;
  final VoidCallback onToggleExpanded;
  final VoidCallback onAudio;
  final VoidCallback onMicrophone;
  final VoidCallback onKeyboard;
  final VoidCallback onClipboard;
  final VoidCallback onClipboardPull;
  final VoidCallback onSettings;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    const caps = SessionMediaCapabilities.currentBuild;
    if (!expanded) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggleExpanded,
        child: Opacity(
          opacity: 0.34,
          child: Container(
            width: 20,
            height: 58,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: const Color(0xC818191D),
              borderRadius: BorderRadius.circular(R.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Icon(
              LucideIcons.chevronLeft,
              size: 14,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final size = compact ? 40.0 : 44.0;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
      decoration: BoxDecoration(
        color: const Color(0xEB18191D),
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(-4, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailButton(
            icon: LucideIcons.chevronRight,
            tooltip: 'Sembunyikan kontrol',
            size: size,
            onTap: onToggleExpanded,
          ),
          const _RailDivider(),
          _RailButton(
            icon: LucideIcons.volume2,
            tooltip: 'Suara PC',
            size: size,
            active: audioRequested,
            pending: audioRequested && !caps.pcSystemAudio.isActive,
            onTap: onAudio,
          ),
          _RailButton(
            icon: LucideIcons.mic,
            tooltip: 'Mik ke PC',
            size: size,
            active: microphoneRequested,
            pending: microphoneRequested && !caps.phoneMicrophone.isActive,
            onTap: onMicrophone,
          ),
          _RailButton(
            icon: LucideIcons.keyboard,
            tooltip: 'Keyboard',
            size: size,
            onTap: onKeyboard,
          ),
          if (showClipboard)
            _RailButton(
              icon: LucideIcons.clipboard,
              tooltip: 'Kirim ke papan klip PC',
              size: size,
              onTap: onClipboard,
            ),
          if (showClipboard)
            _RailButton(
              icon: LucideIcons.clipboardPaste,
              tooltip: 'Ambil dari papan klip PC',
              size: size,
              onTap: onClipboardPull,
            ),
          _RailButton(
            icon: LucideIcons.settings,
            tooltip: 'Pengaturan sesi',
            size: size,
            onTap: onSettings,
          ),
          const _RailDivider(),
          _RailButton(
            icon: LucideIcons.power,
            tooltip: 'Putuskan',
            size: size,
            danger: true,
            onTap: onDisconnect,
          ),
        ],
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.onTap,
    this.active = false,
    this.pending = false,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback onTap;
  final bool active;
  final bool pending;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.danger
        : pending
        ? AppColors.warning
        : active
        ? AppColors.accentDark
        : Colors.white70;
    return Tooltip(
      message: pending ? '$tooltip - belum aktif' : tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.sm),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 19, color: color),
              if (active && !danger)
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: 14,
                    height: 2,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (pending)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 5, height: 5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GamingControls extends StatelessWidget {
  const _GamingControls({required this.compact, required this.onKey});

  final bool compact;

  /// Kirim tombol keyboard (vk, down) ke host. Pemetaan default game PC:
  /// D-pad = WASD; A=Space (lompat), B=Shift (lari), X=E (aksi), Y=Q.
  final void Function(int vk, bool down) onKey;

  @override
  Widget build(BuildContext context) {
    final bottom = compact ? 76.0 : 88.0;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: 24,
            bottom: bottom,
            child: _DpadControl(size: compact ? 82 : 98, onKey: onKey),
          ),
          Positioned(
            right: 30,
            bottom: bottom + 4,
            child: SizedBox(
              width: compact ? 126 : 150,
              height: compact ? 92 : 108,
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 22,
                    child: _ActionButton(
                      label: 'B',
                      compact: compact,
                      vk: 0xA0, // Shift kiri
                      onKey: onKey,
                    ),
                  ),
                  Positioned(
                    right: compact ? 52 : 62,
                    top: 0,
                    child: _ActionButton(
                      label: 'Y',
                      compact: compact,
                      vk: 0x51, // Q
                      onKey: onKey,
                    ),
                  ),
                  Positioned(
                    right: compact ? 52 : 62,
                    bottom: 0,
                    child: _ActionButton(
                      label: 'A',
                      compact: compact,
                      vk: 0x20, // Space
                      onKey: onKey,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 22,
                    child: _ActionButton(
                      label: 'X',
                      compact: compact,
                      vk: 0x45, // E
                      onKey: onKey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// D-pad virtual: sentuhan pada kuadran diterjemahkan ke WASD hold/release.
class _DpadControl extends StatefulWidget {
  const _DpadControl({required this.size, required this.onKey});

  final double size;
  final void Function(int vk, bool down) onKey;

  @override
  State<_DpadControl> createState() => _DpadControlState();
}

class _DpadControlState extends State<_DpadControl> {
  static const _w = 0x57, _a = 0x41, _s = 0x53, _d = 0x44;
  final Set<int> _held = {};

  void _update(Offset local) {
    final c = widget.size / 2;
    final dx = local.dx - c;
    final dy = local.dy - c;
    final dead = widget.size * 0.12;
    final next = <int>{};
    if (dy < -dead) next.add(_w);
    if (dy > dead) next.add(_s);
    if (dx < -dead) next.add(_a);
    if (dx > dead) next.add(_d);
    for (final vk in _held.difference(next)) {
      widget.onKey(vk, false);
    }
    for (final vk in next.difference(_held)) {
      widget.onKey(vk, true);
    }
    _held
      ..clear()
      ..addAll(next);
  }

  void _releaseAll() {
    for (final vk in _held) {
      widget.onKey(vk, false);
    }
    _held.clear();
  }

  @override
  void dispose() {
    _releaseAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _releaseAll(),
      onPanCancel: _releaseAll,
      child: _TouchControl(
        size: widget.size,
        glyph: HudGlyph.dpad,
        label: 'Gerak',
      ),
    );
  }
}

class _TouchControl extends StatelessWidget {
  const _TouchControl({
    required this.size,
    required this.glyph,
    required this.label,
  });

  final double size;
  final HudGlyph glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.58,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HudIcon(glyph, size: size * 0.58, color: Colors.white70),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.compact,
    required this.vk,
    required this.onKey,
  });

  final String label;
  final bool compact;
  final int vk;
  final void Function(int vk, bool down) onKey;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down) return;
    _down = down;
    widget.onKey(widget.vk, down);
    if (down) HapticFeedback.selectionClick();
    setState(() {});
  }

  @override
  void dispose() {
    if (_down) widget.onKey(widget.vk, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 42.0 : 50.0;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _down
              ? AppColors.accentDark.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: _down ? 0.7 : 0.34),
          ),
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
