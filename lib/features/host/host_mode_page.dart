import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/store.dart';
import '../../core/tokens.dart';
import '../auth/auth_service.dart';

@immutable
class HostModeState {
  const HostModeState({
    this.deviceId,
    this.password,
    this.running = false,
    this.busy = false,
    this.error,
    this.logs = const [],
  });

  final String? deviceId;
  final String? password;
  final bool running;
  final bool busy;
  final String? error;
  final List<String> logs;

  HostModeState copyWith({
    String? deviceId,
    String? password,
    bool? running,
    bool? busy,
    String? error,
    bool clearError = false,
    List<String>? logs,
  }) => HostModeState(
    deviceId: deviceId ?? this.deviceId,
    password: password ?? this.password,
    running: running ?? this.running,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
    logs: logs ?? this.logs,
  );
}

final hostModeProvider =
    StateNotifierProvider.autoDispose<HostModeController, HostModeState>((ref) {
      final controller = HostModeController(ref);
      ref.onDispose(controller.shutdown);
      unawaited(controller.loadIdentity());
      return controller;
    });

class HostModeController extends StateNotifier<HostModeState> {
  HostModeController(this.ref) : super(const HostModeState());

  final Ref ref;
  Process? _process;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;

  File? get _hostExecutable {
    if (!Platform.isWindows) return null;
    final root = File(Platform.resolvedExecutable).parent;
    for (final path in [
      '${root.path}\\Host\\XyDesk-Host.exe',
      '${root.path}\\XyDesk-Host.exe',
      '${root.path}\\Host\\xydesk-host.exe',
    ]) {
      final file = File(path);
      if (file.existsSync()) return file;
    }
    return null;
  }

  Future<void> loadIdentity() async {
    if (!Platform.isWindows) return;
    state = state.copyWith(busy: true, clearError: true);
    final executable = _hostExecutable;
    if (executable == null) {
      state = state.copyWith(
        busy: false,
        error: 'Komponen Host belum ada di paket Windows ini.',
      );
      return;
    }
    try {
      final result = await Process.run(executable.path, const [
        '--identity-json',
      ]);
      if (result.exitCode != 0) {
        throw StateError(result.stderr.toString().trim());
      }
      final value = jsonDecode(result.stdout.toString().trim());
      if (value is! Map<String, dynamic>) throw const FormatException();
      final id = value['deviceId'];
      final password = value['password'];
      if (id is! String || password is! String) throw const FormatException();
      state = state.copyWith(
        deviceId: id,
        password: password,
        busy: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'Identitas Host tidak dapat dibaca.',
      );
    }
  }

  Future<void> start() async {
    if (state.busy || state.running) return;
    final executable = _hostExecutable;
    final id = state.deviceId;
    final password = state.password;
    final session = ref.read(authProvider);
    if (executable == null || id == null || password == null) {
      state = state.copyWith(error: 'Komponen atau identitas Host belum siap.');
      return;
    }
    if (session.isGuest || session.token == null) {
      state = state.copyWith(
        error: 'Masuk dengan akun XyDesk untuk mengaktifkan mode Host.',
      );
      return;
    }

    state = state.copyWith(busy: true, clearError: true, logs: const []);
    try {
      final signalToken = await ref
          .read(authServiceProvider)
          .hostSignalToken(
            token: session.token!,
            deviceId: id,
            password: password,
          );
      final process = await Process.start(executable.path, [
        '--url',
        'wss://signal.xystudio.my.id/ws',
        '--id',
        id,
        '--name',
        Platform.localHostname,
        '--token',
        signalToken,
      ]);
      _process = process;
      _stdout = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_appendLog);
      _stderr = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_appendLog);
      state = state.copyWith(running: true, busy: false);
      unawaited(
        process.exitCode.then((code) {
          if (!mounted) return;
          state = state.copyWith(
            running: false,
            busy: false,
            error: code == 0 ? null : 'Host berhenti dengan kode $code.',
          );
          _process = null;
        }),
      );
    } on AuthException catch (error) {
      state = state.copyWith(busy: false, error: error.message);
    } catch (_) {
      state = state.copyWith(
        busy: false,
        running: false,
        error: 'Engine Host tidak dapat dijalankan.',
      );
    }
  }

  Future<void> stop() async {
    _process?.kill();
    _process = null;
    state = state.copyWith(running: false, busy: false);
  }

  Future<void> setPassword(String password) async {
    if (password.length < 6 || state.running) return;
    final executable = _hostExecutable;
    if (executable == null) return;
    state = state.copyWith(busy: true, clearError: true);
    final result = await Process.run(executable.path, [
      '--set-password',
      password,
    ]);
    if (result.exitCode != 0) {
      state = state.copyWith(
        busy: false,
        error: 'Password Host gagal diperbarui.',
      );
      return;
    }
    await loadIdentity();
  }

  void _appendLog(String line) {
    if (!mounted || line.trim().isEmpty) return;
    state = state.copyWith(
      logs: [...state.logs, line.trim()].takeLast(8).toList(growable: false),
    );
  }

  void shutdown() {
    _stdout?.cancel();
    _stderr?.cancel();
    _process?.kill();
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final values = toList(growable: false);
    return values.skip(values.length > count ? values.length - count : 0);
  }
}

class HostModePage extends ConsumerStatefulWidget {
  const HostModePage({super.key});

  @override
  ConsumerState<HostModePage> createState() => _HostModePageState();
}

class _HostModePageState extends ConsumerState<HostModePage> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final state = ref.watch(hostModeProvider);
    final controller = ref.read(hostModeProvider.notifier);
    final top = MediaQuery.paddingOf(context).top + 66;

    return ListView(
      padding: EdgeInsets.fromLTRB(0, top, 0, 120),
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: state.running ? c.successText : c.textLow,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Text(
              state.running ? 'PC siap menerima koneksi' : 'Mode Host berhenti',
              style: TextStyle(fontSize: 12, color: c.textMid),
            ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        Text(
          'Bagikan PC ini',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'Gunakan ID dan password ini dari Android, Windows lain, atau Connect Web.',
          style: TextStyle(fontSize: 13, height: 1.55, color: c.textMid),
        ),
        const SizedBox(height: Gap.xxl),
        _CredentialCard(
          label: 'ID perangkat',
          value: _formatId(state.deviceId),
          onCopy: state.deviceId == null
              ? null
              : () => Clipboard.setData(ClipboardData(text: state.deviceId!)),
        ),
        const SizedBox(height: Gap.md),
        _CredentialCard(
          label: 'Password pairing',
          value: state.password == null
              ? 'Belum tersedia'
              : _showPassword
              ? state.password!
              : List.filled(state.password!.length, '•').join(),
          trailing: IconButton(
            tooltip: _showPassword ? 'Sembunyikan password' : 'Lihat password',
            onPressed: state.password == null
                ? null
                : () => setState(() => _showPassword = !_showPassword),
            icon: Icon(
              _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
              size: 18,
            ),
          ),
          onCopy: state.password == null
              ? null
              : () => Clipboard.setData(ClipboardData(text: state.password!)),
        ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: state.busy
                    ? null
                    : state.running
                    ? controller.stop
                    : controller.start,
                icon: Icon(
                  state.running ? LucideIcons.square : LucideIcons.play,
                  size: 17,
                ),
                label: Text(state.running ? 'Hentikan Host' : 'Aktifkan Host'),
              ),
            ),
            const SizedBox(width: Gap.sm),
            IconButton(
              tooltip: 'Ganti password',
              onPressed: state.busy || state.running
                  ? null
                  : () => _changePassword(controller),
              icon: const Icon(LucideIcons.keyRound, size: 19),
            ),
          ],
        ),
        if (state.error != null) ...[
          const SizedBox(height: Gap.md),
          Text(
            state.error!,
            style: TextStyle(color: c.dangerText, fontSize: 12),
          ),
        ],
        if (state.logs.isNotEmpty) ...[
          const SizedBox(height: Gap.xl),
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: c.input,
              borderRadius: BorderRadius.circular(R.md),
            ),
            child: Text(
              state.logs.join('\n'),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                height: 1.45,
                color: c.textMid,
              ),
            ),
          ),
        ],
        const SizedBox(height: Gap.h32),
        Text(
          'Akses cepat',
          style: TextStyle(color: c.textHi, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Gap.sm),
        _QuickLink(
          icon: LucideIcons.globe,
          title: 'Connect Web',
          subtitle: 'Kendalikan PC ini dari browser atau iPhone',
          onTap: () => launchUrl(
            Uri.parse('https://app.xystudio.my.id/connect'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: Gap.sm),
        _QuickLink(
          icon: LucideIcons.heart,
          title: 'Dukung kami di saluran WhatsApp',
          subtitle: 'Info rilis, panduan, dan perkembangan XyDesk',
          onTap: () => launchUrl(
            Uri.parse('https://whatsapp.com/channel/0029VbB7nwuJZg3ym6UQ4Z1L'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }

  Future<void> _changePassword(HostModeController controller) async {
    final field = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti password Host'),
        content: TextField(
          controller: field,
          autofocus: true,
          obscureText: true,
          maxLength: 64,
          decoration: const InputDecoration(hintText: 'Minimal 6 karakter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    field.dispose();
    if (value != null && value.length >= 6) await controller.setPassword(value);
  }
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({
    required this.label,
    required this.value,
    this.trailing,
    this.onCopy,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, color: c.textLow)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: c.textHi,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          IconButton(
            tooltip: 'Salin',
            onPressed: onCopy,
            icon: const Icon(LucideIcons.copy, size: 18),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.raised,
      borderRadius: BorderRadius.circular(R.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(R.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.accent),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textHi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: c.textLow),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.arrowUpRight, size: 17, color: c.textLow),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatId(String? value) {
  if (value == null || value.length != 9) return 'Menyiapkan…';
  return '${value.substring(0, 3)} ${value.substring(3, 6)} ${value.substring(6)}';
}
