import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n_bridge.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/seamless.dart';
import 'device_model.dart';

/// Riwayat sesi yang tersimpan di perangkat.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final items = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(context.tr('connect_history')),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.textMid),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: c.textMid),
              onPressed: () => ref.read(historyProvider.notifier).clear(),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: items.isEmpty
          ? IllustrationState(
              asset: Img.connect,
              title: context.tr('history_empty'),
              message: context.tr('history_empty_msg'),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                Gap.screen,
                Gap.sm,
                Gap.screen,
                Gap.h40,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                return ListRow(
                  title: r.deviceName,
                  subtitle: '${_fmt(r.at)} · ${r.path} · ${r.quality}',
                  icon: LucideIcons.monitor,
                  value: '${r.durationMin} m',
                );
              },
            ),
    );
  }

  String _fmt(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? 'Hari ini $h:$m' : '${t.day}/${t.month} $h:$m';
  }
}
