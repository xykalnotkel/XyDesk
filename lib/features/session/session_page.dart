import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/devlog.dart';
import '../../core/l10n_bridge.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
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
  });

  final String deviceName;
  final String deviceId;

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

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(settingsProvider);
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
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final reduceMotion = preferences.reduceMotion || platformReduce;
    _connectTimer = Timer(Duration(milliseconds: reduceMotion ? 0 : 450), () {
      if (!mounted) return;
      setState(() => _connecting = false);
      DevLog.i('sesi', 'Preview UI siap — transport belum aktif');
      _restartIdleTimer();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _connectTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    DevLog.i('sesi', 'Menutup sesi');
    super.dispose();
  }

  void _leaveSession() {
    // Offline previews are deliberately not added to remote-session history.
    // History should begin only after a real negotiated transport is active.
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
          final panelWidth =
              (constraints.maxWidth * 0.46).clamp(340.0, 410.0).toDouble();
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _wake,
                  child: _RemoteScreenPlaceholder(
                    experience: _settings.experience,
                  ),
                ),
              ),
              if (!_keyboardVisible &&
                  !_panelVisible &&
                  _settings.experience == SessionExperience.gaming &&
                  _settings.showGamingControls)
                _GamingControls(compact: compact),
              if (!_keyboardVisible &&
                  !_panelVisible &&
                  _settings.experience == SessionExperience.desktop)
                _DesktopControls(compact: compact),
              _fadePositioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 12,
                right: 12,
                child: _TopBar(
                  deviceName: widget.deviceName,
                  experience: _settings.experience,
                  compact: compact,
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
                      onClipboard: () =>
                          _showUnavailable('Clipboard transport belum aktif.'),
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
                  onKey: (_) {},
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
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
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

class _RemoteScreenPlaceholder extends StatelessWidget {
  const _RemoteScreenPlaceholder({required this.experience});

  final SessionExperience experience;

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
          Positioned.fill(
            child: CustomPaint(painter: const _AmbientGridPainter()),
          ),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    child: const Text(
                      'PREVIEW • TRANSPORT OFFLINE',
                      style: TextStyle(
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
                  const Text(
                    'HUD dapat dipreview, tetapi belum mengirim input atau audio.',
                    style: TextStyle(fontSize: 10.5, color: Color(0x66FFFFFF)),
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.deviceName,
    required this.experience,
    required this.compact,
    required this.onExperienceChanged,
    required this.onBack,
  });

  final String deviceName;
  final SessionExperience experience;
  final bool compact;
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
              decoration: const BoxDecoration(
                color: AppColors.warning,
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
                  const Text(
                    'Preview • tanpa telemetry',
                    style: TextStyle(fontSize: 10.5, color: Colors.white38),
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
            pending: audioRequested &&
                !SessionMediaCapabilities.currentBuild.pcSystemAudio.isActive,
            onTap: onAudio,
          ),
          _DockButton(
            icon: LucideIcons.mic,
            label: 'Mik',
            requested: microphoneRequested,
            pending: microphoneRequested &&
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
  const _GamingControls({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bottom = compact ? 76.0 : 88.0;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            Positioned(
              left: 24,
              bottom: bottom,
              child: _TouchControl(
                size: compact ? 82 : 98,
                glyph: HudGlyph.dpad,
                label: 'Gerak',
              ),
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
                      child: _ActionButton(label: 'B', compact: compact),
                    ),
                    Positioned(
                      right: compact ? 52 : 62,
                      top: 0,
                      child: _ActionButton(label: 'Y', compact: compact),
                    ),
                    Positioned(
                      right: compact ? 52 : 62,
                      bottom: 0,
                      child: _ActionButton(label: 'A', compact: compact),
                    ),
                    Positioned(
                      left: 0,
                      top: 22,
                      child: _ActionButton(label: 'X', compact: compact),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 50.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
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
