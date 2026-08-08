import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_bridge.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

import '../../core/devlog.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../devices/device_model.dart';
import '../../widgets/hud_glyphs.dart';
import 'session_panels.dart';
import 'virtual_keyboard.dart';

/// Layar sesi aktif.
///
/// Urutan penting: orientasi dikunci ke landscape **lebih dulu**, baru layar
/// loading ditampilkan. Kalau dibalik akan ada kedipan orientasi yang membuat
/// aplikasi terasa murah.
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
  bool _keyboard = false;
  bool _leftRail = false;
  PanelCat? _panel;
  Timer? _idle;
  SessionSettings _settings = const SessionSettings();
  KbLayout _kbLayout = KbLayout.split;
  double _keyboardOpacity = 0.95;
  late DateTime _startedAt;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // edgeToEdge, bukan immersiveSticky: immersive menyembunyikan status
    // bar lalu memunculkannya lagi saat disentuh, membuat tata letak
    // melompat-lompat dan sempat terlihat kosong.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    DevLog.i(
      'sesi',
      'Membuka sesi ke ${widget.deviceName}',
      'id=${widget.deviceId}',
    );
    // Simulasi tahap koneksi.
    Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() => _connecting = false);
      DevLog.ok('sesi', 'Terhubung — placeholder aktif');
      _restartIdle();
    });
  }

  @override
  void dispose() {
    DevLog.i('sesi', 'Menutup sesi');
    _idle?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _recordSession() async {
    if (_recorded) return;
    _recorded = true;
    final elapsed = DateTime.now().difference(_startedAt);
    final minutes = elapsed.inMinutes < 1 ? 1 : elapsed.inMinutes;
    await ref.read(historyProvider.notifier).add(
          SessionRecord(
            deviceId: widget.deviceId,
            deviceName: widget.deviceName,
            at: _startedAt,
            durationMin: minutes,
            path: 'P2P',
            quality: '1080p60',
          ),
        );
  }

  Future<void> _leaveSession() async {
    await _recordSession();
    if (mounted) Navigator.of(context).maybePop();
  }

  void _restartIdle() {
    _idle?.cancel();
    _idle = Timer(D.idleHide, () {
      if (mounted && _panel == null && !_keyboard && !_leftRail) {
        setState(() => _overlayVisible = false);
      }
    });
  }

  void _wake() {
    if (!_overlayVisible) setState(() => _overlayVisible = true);
    _restartIdle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.bg,
      body: _connecting
          ? _ConnectingView(name: widget.deviceName)
          : Stack(
              children: [
                // Layar remote (placeholder untuk RTCVideoView)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _wake,
                    child: const _RemoteScreenPlaceholder(),
                  ),
                ),

                // Statistik kiri atas
                _fade(
                  top: 10,
                  left: _leftRail ? 72 : 12,
                  child: _StatsOverlay(name: widget.deviceName),
                ),

                // Panah kiri-atas → buka bilah kiri
                _fade(
                  top: 6,
                  left: 0,
                  child: _OverlayIcon(
                    icon: _leftRail
                        ? LucideIcons.chevronLeft
                        : LucideIcons.chevronRight,
                    active: _leftRail,
                    tooltip: 'Menu cepat',
                    onTap: () {
                      setState(() => _leftRail = !_leftRail);
                      _wake();
                    },
                  ),
                ),

                // Panah kanan-atas → buka panel kategori
                _fade(
                  top: 6,
                  right: 0,
                  child: _OverlayIcon(
                    icon: _panel == null
                        ? LucideIcons.chevronLeft
                        : LucideIcons.chevronRight,
                    onTap: () {
                      setState(
                        () => _panel = _panel == null ? PanelCat.info : null,
                      );
                      _wake();
                    },
                  ),
                ),

                // Contoh elemen HUD border-only
                if (!_keyboard && _panel == null) ...[
                  const Positioned(
                    left: 24,
                    bottom: 22,
                    child: HudIcon(HudGlyph.dpad, size: 74, strokeWidth: 1.5),
                  ),
                  const Positioned(
                    right: 120,
                    bottom: 26,
                    child: HudButton(
                      glyph: HudGlyph.mouseLeft,
                      label: 'Kiri',
                      size: Size(50, 54),
                    ),
                  ),
                  const Positioned(
                    right: 64,
                    bottom: 26,
                    child: HudButton(
                      glyph: HudGlyph.mouseRight,
                      label: 'Kanan',
                      size: Size(50, 54),
                    ),
                  ),
                  const Positioned(
                    right: 64,
                    bottom: 88,
                    child: HudButton(
                      glyph: HudGlyph.scrollBoth,
                      label: 'Gulir',
                      size: Size(50, 54),
                    ),
                  ),
                ],

                // FAB keyboard kanan bawah
                if (!_keyboard)
                  _fade(
                    right: 12,
                    bottom: 12,
                    child: _KeyboardFab(
                      onTap: () {
                        setState(() => _keyboard = true);
                        _idle?.cancel();
                      },
                    ),
                  ),

                // Bilah ikon kiri
                AnimatedPositioned(
                  duration: D.panel,
                  curve: D.curve,
                  left: _leftRail ? 0 : -72,
                  top: 0,
                  bottom: 0,
                  child: LeftRail(
                    active: _panel ?? PanelCat.info,
                    onClose: () => setState(() => _leftRail = false),
                    onSelect: (cat) => setState(() {
                      // Ketuk kategori yang sama = tutup panel.
                      _panel = (_panel == cat) ? null : cat;
                    }),
                    onRestart: () {},
                    onBack: _leaveSession,
                    onDisconnect: _confirmDisconnect,
                  ),
                ),

                // Panel kategori kanan
                AnimatedPositioned(
                  duration: D.panel,
                  curve: D.curve,
                  right: _panel != null ? 0 : -260,
                  top: 0,
                  bottom: 0,
                  child: RightPanel(
                    cat: _panel ?? PanelCat.info,
                    deviceName: widget.deviceName,
                    state: _settings,
                    onChanged: (s) => setState(() => _settings = s),
                    onBackToHub: () => setState(() => _panel = PanelCat.info),
                    onSelectCat: (cat) => setState(() => _panel = cat),
                    onClose: () {
                      setState(() => _panel = null);
                      _restartIdle();
                    },
                  ),
                ),

                // Keyboard virtual
                AnimatedPositioned(
                  duration: D.sheet,
                  curve: D.curve,
                  left: 0,
                  right: 0,
                  bottom: _keyboard ? 0 : -320,
                  child: VirtualKeyboard(
                    layout: _kbLayout,
                    opacity: _keyboardOpacity,
                    onLayoutChanged: (l) => setState(() => _kbLayout = l),
                    onOpacityChanged: (v) =>
                        setState(() => _keyboardOpacity = v),
                    onKey: (_) {},
                    onDismiss: () {
                      setState(() => _keyboard = false);
                      _restartIdle();
                    },
                  ),
                ),
              ],
            ),
    );
  }

  /// Membungkus isi overlay dengan animasi pudar.
  ///
  /// PENTING: `Positioned` harus tetap menjadi anak LANGSUNG dari `Stack`.
  /// Versi sebelumnya membungkus `Positioned` dengan `AnimatedOpacity`,
  /// yang membuat Flutter melempar "Incorrect use of ParentDataWidget"
  /// dan seluruh layar sesi gagal dirender (tampak putih/kosong).
  Widget _fade({
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

  Future<void> _confirmDisconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.tr('session_disconnect_confirm'),
          style: const TextStyle(fontSize: 14),
        ),
        content: const Text(
          'Sesi akan diakhiri. PC host tetap menyala dan bisa dihubungi lagi '
          'kapan saja.',
          style: TextStyle(fontSize: 11.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.tr('session_disconnect_action'),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _recordSession();
      if (mounted) Navigator.of(context).pop();
    }
  }
}

/// Layar loading connect — 5 langkah dengan waktunya masing-masing.
class _ConnectingView extends StatelessWidget {
  const _ConnectingView({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: c.bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(height: Gap.lg),
              Text(
                '${context.tr('session_connecting')} $name',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.textHi,
                ),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Menyiapkan koneksi aman',
                style: TextStyle(fontSize: 11.5, color: c.textMid),
              ),
              const SizedBox(height: Gap.lg),
              LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: c.textLow.withValues(alpha: 0.18),
                color: c.accent,
              ),
              const SizedBox(height: Gap.md),
              Text(
                context.tr('session_landscape_locked'),
                style: TextStyle(fontSize: 10, color: c.textLow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteScreenPlaceholder extends StatelessWidget {
  const _RemoteScreenPlaceholder();

  @override
  Widget build(BuildContext context) {
    // Placeholder yang JELAS terbaca sebagai placeholder, bukan layar kosong.
    // Sebelumnya hanya gradient gelap sehingga terlihat seperti aplikasi hang.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1C22), Color(0xFF101116), Color(0xFF16181D)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.55,
              child: Image.asset(
                Img.gaming,
                width: 96,
                height: 96,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox(height: 96),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Layar remote akan tampil di sini',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'WebRTC belum tersambung — ini mode demo.\n'
              'Panel, keyboard, dan HUD tetap bisa dicoba.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsOverlay extends StatelessWidget {
  const _StatsOverlay({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Opacity(
      opacity: 0.72,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            name,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: c.textHi,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            '24 ms  60 fps  12 Mbps',
            style: TextStyle(
              fontSize: 9.5,
              fontFamily: 'monospace',
              color: c.textMid,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayIcon extends StatelessWidget {
  const _OverlayIcon({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final edge = active ? c.accent : c.textHi.withValues(alpha: 0.48);
    // Kontrol buka/tutup panel sengaja kotak: lebih cepat terbaca di atas
    // video remote dan tidak terlihat seperti tombol UI biasa.
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: active
            ? c.accent.withValues(alpha: 0.88)
            : c.overlay.withValues(alpha: 0.94),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: edge, width: active ? 1.4 : 1),
            ),
            child: Icon(
              icon,
              size: 25,
              color: active ? Colors.white : c.textHi,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyboardFab extends StatelessWidget {
  const _KeyboardFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.88,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 50,
            height: 50,
            child: Icon(
              LucideIcons.keyboard,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
