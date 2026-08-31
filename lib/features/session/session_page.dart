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

  /// Kirim isi clipboard perangkat ini ke host — host mengetikkannya
  /// sebagai unicode (protokol TEXT 0x06, bebas layout keyboard).
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
    // Batasi 32 KB per kiriman agar data channel tidak tersedak.
    final clipped = text.length > 32768 ? text.substring(0, 32768) : text;
    _transport.sendInput(InputCodec.text(clipped));
    _showUnavailable('Clipboard terkirim ke PC.');
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

  void _setExperience(SessionExperience experience) {
    setState(() => _settings = _settings.copyWith(experience: experience));
    _wake();
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
                        // Saat live, tap adalah klik kiri murni — overlay
                        // dibuka lewat _EdgeHandle, bukan tap layar.
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
              if (!_keyboardVisible &&
                  !_panelVisible &&
                  _settings.experience == SessionExperience.desktop)
                _DesktopControls(compact: compact),
              if (!_keyboardVisible && !_panelVisible) ...[
                Positioned(
                  left: 0,
                  top: constraints.maxHeight / 2 - 44,
                  child: _EdgePanelHandle(
                    icon: LucideIcons.chevronRight,
                    tooltip: 'Buka kontrol',
                    visible: _overlayVisible,
                    onTap: () => _openPanel(SessionPanelSection.controls),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: constraints.maxHeight / 2 - 44,
                  child: _EdgePanelHandle(
                    icon: LucideIcons.chevronLeft,
                    tooltip: 'Buka pengaturan',
                    visible: _overlayVisible,
                    onTap: () => _openPanel(SessionPanelSection.stream),
                  ),
                ),
              ],
              _fadePositioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 12,
                right: 12,
                child: _TopBar(
                  deviceName: widget.deviceName,
                  experience: _settings.experience,
                  compact: compact,
                  live: _transport.state.live,
                  onExperienceChanged: _setExperience,
                  onBack: _leaveSession,
                ),
              ),
              if (!_keyboardVisible)
                _fadePositioned(
                  left: 12,
                  right: 12,
                  bottom: MediaQuery.paddingOf(context).bottom + 10,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _QuickDock(
                      experience: _settings.experience,
                      audioRequested: _settings.pcAudioRequested,
                      microphoneRequested: _settings.microphoneRequested,
                      onAudio: () => _openPanel(SessionPanelSection.audio),
                      onMicrophone: () => _openPanel(SessionPanelSection.audio),
                      onKeyboard: _showKeyboard,
                      onClipboard: _sendClipboard,
                      onSettings: () => _openPanel(),
                      onDisconnect: _confirmDisconnect,
                    ),
                  ),
                ),
              // Handle kecil di tepi kanan-tengah: satu-satunya kontrol yang
              // selalu terlihat (redup) saat HUD tersembunyi. Mobile-friendly:
              // tidak menutupi area game/kerja di tengah, atas, atau bawah.
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_overlayVisible) {
                        setState(() => _overlayVisible = false);
                        _idleTimer?.cancel();
                      } else {
                        _wake();
                      }
                    },
                    child: AnimatedOpacity(
                      duration: D.fade,
                      opacity: _overlayVisible ? 0.9 : 0.28,
                      child: Container(
                        width: 22,
                        height: 64,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xC818191D),
                          borderRadius: BorderRadius.circular(R.pill),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Icon(
                          _overlayVisible
                              ? LucideIcons.chevronRight
                              : LucideIcons.chevronLeft,
                          size: 15,
                          color: Colors.white70,
                        ),
                      ),
                    ),
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

  Widget _fadePositioned({
    double? left,
    double? top,
    double? right,
    double? bottom,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: AnimatedOpacity(
        opacity: _overlayVisible ? 1 : 0,
        duration: D.fade,
        child: IgnorePointer(ignoring: !_overlayVisible, child: child),
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

class _EdgePanelHandle extends StatelessWidget {
  const _EdgePanelHandle({
    required this.icon,
    required this.tooltip,
    required this.visible,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 0.72 : 0,
      duration: D.fast,
      child: IgnorePointer(
        ignoring: !visible,
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(R.sm),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(R.sm),
              child: SizedBox(
                width: 34,
                height: 88,
                child: Icon(icon, size: 21, color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.deviceName,
    required this.experience,
    required this.compact,
    required this.live,
    required this.onExperienceChanged,
    required this.onBack,
  });

  final String deviceName;
  final SessionExperience experience;
  final bool compact;
  final bool live;
  final ValueChanged<SessionExperience> onExperienceChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        height: compact ? 48 : 54,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xE818191D),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Kembali',
              onPressed: onBack,
              icon: const Icon(
                LucideIcons.arrowLeft,
                size: 19,
                color: Colors.white70,
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: live ? AppColors.success : AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    live
                        ? 'Live • end-to-end WebRTC'
                        : 'Preview • tanpa telemetry',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: compact ? 200 : 230,
              child: ExperienceSelector(
                value: experience,
                compact: true,
                onChanged: onExperienceChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDock extends StatelessWidget {
  const _QuickDock({
    required this.experience,
    required this.audioRequested,
    required this.microphoneRequested,
    required this.onAudio,
    required this.onMicrophone,
    required this.onKeyboard,
    required this.onClipboard,
    required this.onSettings,
    required this.onDisconnect,
  });

  final SessionExperience experience;
  final bool audioRequested;
  final bool microphoneRequested;
  final VoidCallback onAudio;
  final VoidCallback onMicrophone;
  final VoidCallback onKeyboard;
  final VoidCallback onClipboard;
  final VoidCallback onSettings;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xEB18191D),
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DockButton(
            icon: LucideIcons.volume2,
            label: 'Audio',
            requested: audioRequested,
            pending:
                audioRequested &&
                !SessionMediaCapabilities.currentBuild.pcSystemAudio.isActive,
            onTap: onAudio,
          ),
          _DockButton(
            icon: LucideIcons.mic,
            label: 'Mik',
            requested: microphoneRequested,
            pending:
                microphoneRequested &&
                !SessionMediaCapabilities.currentBuild.phoneMicrophone.isActive,
            onTap: onMicrophone,
          ),
          _DockButton(
            icon: LucideIcons.keyboard,
            label: 'Keyboard',
            onTap: onKeyboard,
          ),
          if (experience == SessionExperience.desktop)
            _DockButton(
              icon: LucideIcons.clipboard,
              label: 'Clipboard',
              onTap: onClipboard,
            ),
          _DockButton(
            icon: LucideIcons.settings,
            label: 'Atur',
            onTap: onSettings,
          ),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            color: Colors.white.withValues(alpha: 0.12),
          ),
          _DockButton(
            icon: LucideIcons.power,
            label: 'Putus',
            danger: true,
            onTap: onDisconnect,
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.requested = false,
    this.pending = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool requested;
  final bool pending;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.danger
        : pending
        ? AppColors.warning
        : requested
        ? AppColors.accentDark
        : Colors.white70;
    return Tooltip(
      message: pending ? '$label belum aktif • ketuk untuk detail' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.sm),
        child: SizedBox(
          width: 62,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19, color: color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (pending)
                const Positioned(
                  top: 8,
                  right: 10,
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

class _DesktopControls extends StatelessWidget {
  const _DesktopControls({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: compact ? 78 : 90,
      child: IgnorePointer(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HudIcon(HudGlyph.trackpad, size: 25, color: Colors.white54),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Seret untuk pointer • ketuk untuk klik • dua jari untuk gulir',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
