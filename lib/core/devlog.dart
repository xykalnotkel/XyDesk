import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';

/// Tingkat kepentingan catatan.
enum LogLevel {
  debug('DBG', Color(0xFF6B6B73)),
  info('INF', Color(0xFFA0A0A8)),
  success('OK ', Color(0xFF4FA97A)),
  warning('WRN', Color(0xFFC9963F)),
  error('ERR', Color(0xFFD9646E)),
  fatal('FTL', Color(0xFFFF4D5E));

  const LogLevel(this.tag, this.color);
  final String tag;
  final Color color;
}

/// Satu baris catatan.
@immutable
class LogEntry {
  LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    this.detail,
    this.stack,
  }) : time = DateTime.now();

  final LogLevel level;
  final String tag;
  final String message;
  final String? detail;
  final StackTrace? stack;
  final DateTime time;

  String get clock =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}.'
      '${time.millisecond.toString().padLeft(3, '0')}';

  String toPlainText() {
    final b = StringBuffer('[$clock] ${level.tag} [$tag] $message');
    if (detail != null) b.write('\n    $detail');
    if (stack != null) {
      final lines = stack.toString().split('\n').take(12);
      for (final l in lines) {
        if (l.trim().isNotEmpty) b.write('\n    $l');
      }
    }
    return b.toString();
  }
}

/// Perekam log dalam aplikasi.
///
/// Menangkap tiga sumber sekaligus:
///  1. `DevLog.i/w/e(...)` yang dipanggil manual dari kode
///  2. `FlutterError.onError` — error framework (overflow, build gagal, dll)
///  3. `PlatformDispatcher.onError` — error async yang tidak tertangkap
///
/// Semua tersimpan di memori (dibatasi agar tidak membengkak) dan bisa
/// disalin ke papan klip lewat panel DevLog di aplikasi.
class DevLog {
  DevLog._();

  static const _maxEntries = 800;
  static final _entries = ListQueue<LogEntry>();

  /// Dipakai widget panel agar ikut memperbarui saat ada log baru.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// Jumlah error + fatal, untuk lencana merah di tombol DevLog.
  static final ValueNotifier<int> errorCount = ValueNotifier(0);

  static List<LogEntry> get entries => List.unmodifiable(_entries);

  static void _add(LogEntry e) {
    _entries.addLast(e);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    if (e.level == LogLevel.error || e.level == LogLevel.fatal) {
      errorCount.value++;
    }
    revision.value++;
    if (kDebugMode) debugPrint(e.toPlainText());
  }

  static void d(String tag, String msg, [String? detail]) => _add(
    LogEntry(level: LogLevel.debug, tag: tag, message: msg, detail: detail),
  );

  static void i(String tag, String msg, [String? detail]) => _add(
    LogEntry(level: LogLevel.info, tag: tag, message: msg, detail: detail),
  );

  static void ok(String tag, String msg, [String? detail]) => _add(
    LogEntry(level: LogLevel.success, tag: tag, message: msg, detail: detail),
  );

  static void w(String tag, String msg, [String? detail]) => _add(
    LogEntry(level: LogLevel.warning, tag: tag, message: msg, detail: detail),
  );

  static void e(String tag, String msg, [Object? err, StackTrace? st]) => _add(
    LogEntry(
      level: LogLevel.error,
      tag: tag,
      message: msg,
      detail: err?.toString(),
      stack: st,
    ),
  );

  static void fatal(String tag, String msg, [Object? err, StackTrace? st]) =>
      _add(
        LogEntry(
          level: LogLevel.fatal,
          tag: tag,
          message: msg,
          detail: err?.toString(),
          stack: st,
        ),
      );

  static void clear() {
    _entries.clear();
    errorCount.value = 0;
    revision.value++;
  }

  /// Seluruh log sebagai teks, siap disalin dan dikirim ke pengembang.
  static String export({String? deviceInfo}) {
    final b = StringBuffer()
      ..writeln('===== XyDesk DevLog =====')
      ..writeln('Dibuat : ${DateTime.now()}')
      ..writeln(
        'Mode   : ${kReleaseMode
            ? "release"
            : kProfileMode
            ? "profile"
            : "debug"}',
      )
      ..writeln('Baris  : ${_entries.length}  (error: ${errorCount.value})');
    if (deviceInfo != null) b.writeln(deviceInfo);
    b.writeln('=========================');
    for (final e in _entries) {
      b.writeln(e.toPlainText());
    }
    return b.toString();
  }

  /// Buka DevLog sebagai halaman penuh — lebih nyaman untuk membaca
  /// stack trace panjang daripada lembar setengah layar.
  static Future<void> openPage(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DevLogScreen()));
  }

  /// Ekspor hanya baris error & fatal — inilah yang biasanya perlu
  /// dikirim ke pengembang saat melapor bug.
  static String exportErrors() {
    final errs = _entries.where(
      (e) => e.level == LogLevel.error || e.level == LogLevel.fatal,
    );
    if (errs.isEmpty) return 'Tidak ada error tercatat.';
    final b = StringBuffer()
      ..writeln('===== XyDesk — Error Log =====')
      ..writeln('Dibuat : ${DateTime.now()}')
      ..writeln('Jumlah : ${errs.length}')
      ..writeln('==============================');
    for (final e in errs) {
      b.writeln(e.toPlainText());
      b.writeln('');
    }
    return b.toString();
  }

  /// Pasang penangkap error global. Panggil sekali dari `main()`.
  static void install() {
    final prevFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      DevLog.e(
        'flutter',
        details.exceptionAsString(),
        details.library == null ? null : 'library: ${details.library}',
        details.stack,
      );
      prevFlutter?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      DevLog.fatal('async', 'Error tak tertangkap', error, stack);
      return true;
    };

    // Ganti layar merah bawaan dengan tampilan yang tidak menakutkan,
    // dan yang lebih penting: tidak menampilkan layar putih kosong.
    ErrorWidget.builder = (details) => _ErrorBox(details: details);
  }
}

/// Widget pengganti layar error merah.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF131315),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.alertTriangle,
                color: Color(0xFFC9963F),
                size: 28,
              ),
              const SizedBox(height: 10),
              const Text(
                'Bagian ini gagal ditampilkan',
                style: TextStyle(
                  color: Color(0xFFEDEDEF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B6B73),
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Detail tercatat di DevLog',
                style: TextStyle(color: Color(0xFF5B7FE8), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel DevLog — daftar log dengan filter dan tombol salin.
class DevLogPanel extends StatefulWidget {
  const DevLogPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DevLogPanel(),
    );
  }

  @override
  State<DevLogPanel> createState() => _DevLogPanelState();
}

class _DevLogPanelState extends State<DevLogPanel> {
  LogLevel? _filter;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF17171A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B6B73),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _header(),
              _filterBar(),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: DevLog.revision,
                  builder: (context, _, __) {
                    final list = DevLog.entries
                        .where((e) => _filter == null || e.level == _filter)
                        .toList()
                        .reversed
                        .toList();
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada catatan',
                          style: TextStyle(
                            color: Color(0xFF6B6B73),
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: list.length,
                      itemBuilder: (context, i) => _row(list[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Row(
        children: [
          const Text(
            'DevLog',
            style: TextStyle(
              color: Color(0xFFEDEDEF),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<int>(
            valueListenable: DevLog.revision,
            builder: (_, __, ___) => Text(
              '${DevLog.entries.length} baris',
              style: const TextStyle(color: Color(0xFF6B6B73), fontSize: 11),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Salin semua',
            icon: const Icon(
              LucideIcons.copy,
              size: 17,
              color: Color(0xFFA0A0A8),
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: DevLog.export()));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log disalin ke papan klip')),
              );
            },
          ),
          IconButton(
            tooltip: 'Bersihkan',
            icon: const Icon(
              LucideIcons.trash2,
              size: 17,
              color: Color(0xFFA0A0A8),
            ),
            onPressed: () => setState(DevLog.clear),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final items = <(String, LogLevel?)>[
      ('Semua', null),
      ('Error', LogLevel.error),
      ('Peringatan', LogLevel.warning),
      ('Info', LogLevel.info),
      ('Debug', LogLevel.debug),
    ];
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final (label, lv) in items)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _filter = lv),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _filter == lv
                        ? const Color(0x1F5B7FE8)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: _filter == lv
                          ? const Color(0xFFEDEDEF)
                          : const Color(0xFF6B6B73),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(LogEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                e.level.tag,
                style: TextStyle(
                  color: e.level.color,
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                e.clock,
                style: const TextStyle(
                  color: Color(0xFF5C5C64),
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  '[${e.tag}]',
                  style: const TextStyle(
                    color: Color(0xFF6B6B73),
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            e.message,
            style: const TextStyle(color: Color(0xFFEDEDEF), fontSize: 11.5),
          ),
          if (e.detail != null) ...[
            const SizedBox(height: 3),
            Text(
              e.detail!,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8A8A93),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tombol bulat kecil untuk membuka DevLog, mengambang di atas semua layar.
class DevLogFab extends StatelessWidget {
  const DevLogFab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: DevLog.errorCount,
      builder: (context, errors, _) {
        return Material(
          color: errors > 0
              ? const Color(0xFF3A1F24)
              : const Color(0xFF1B1B1E).withValues(alpha: 0.9),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => DevLogPanel.show(context),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    LucideIcons.bug,
                    size: 17,
                    color: errors > 0
                        ? const Color(0xFFD9646E)
                        : const Color(0xFF8A8A93),
                  ),
                  if (errors > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD9646E),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// DevLog sebagai halaman penuh.
///
/// Dipakai dari menu Akun. Berbeda dari lembar bawah, halaman ini punya
/// ruang cukup untuk membaca stack trace dan punya tombol khusus untuk
/// menyalin **hanya error** — yang paling sering dibutuhkan saat melapor.
class DevLogScreen extends StatefulWidget {
  const DevLogScreen({super.key});

  @override
  State<DevLogScreen> createState() => _DevLogScreenState();
}

class _DevLogScreenState extends State<DevLogScreen> {
  LogLevel? _filter;

  Future<void> _copy(String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131315),
      appBar: AppBar(
        title: const Text('Log pengembang'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: DevLog.errorCount,
            builder: (context, errors, _) => IconButton(
              tooltip: 'Salin error saja',
              icon: Badge(
                isLabelVisible: errors > 0,
                label: Text('$errors'),
                backgroundColor: const Color(0xFFD9646E),
                child: const Icon(Icons.bug_report_outlined, size: 19),
              ),
              onPressed: () => _copy(
                DevLog.exportErrors(),
                errors > 0
                    ? '$errors error disalin'
                    : 'Tidak ada error tercatat',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Salin semua',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => _copy(DevLog.export(), 'Semua log disalin'),
          ),
          IconButton(
            tooltip: 'Bersihkan',
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            onPressed: () => setState(DevLog.clear),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                for (final (label, lv) in <(String, LogLevel?)>[
                  ('Semua', null),
                  ('Error', LogLevel.error),
                  ('Peringatan', LogLevel.warning),
                  ('Info', LogLevel.info),
                  ('Debug', LogLevel.debug),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = lv),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _filter == lv
                              ? const Color(0x1F5B7FE8)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            color: _filter == lv
                                ? const Color(0xFFEDEDEF)
                                : const Color(0xFF6B6B73),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: DevLog.revision,
              builder: (context, _, __) {
                final list = DevLog.entries
                    .where((e) => _filter == null || e.level == _filter)
                    .toList()
                    .reversed
                    .toList();
                if (list.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada catatan',
                      style: TextStyle(
                        color: Color(0xFF6B6B73),
                        fontSize: 12.5,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
                    return GestureDetector(
                      onLongPress: () =>
                          _copy(e.toPlainText(), 'Baris log disalin'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  e.level.tag,
                                  style: TextStyle(
                                    color: e.level.color,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  e.clock,
                                  style: const TextStyle(
                                    color: Color(0xFF5C5C64),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '[${e.tag}]',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF6B6B73),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              e.message,
                              style: const TextStyle(
                                color: Color(0xFFEDEDEF),
                                fontSize: 12,
                              ),
                            ),
                            if (e.detail != null) ...[
                              const SizedBox(height: 4),
                              SelectableText(
                                e.detail!,
                                style: const TextStyle(
                                  color: Color(0xFF8A8A93),
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
