import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n_bridge.dart';
import '../../core/session_preview.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/seamless.dart';
import '../session/session_page.dart';
import 'device_model.dart';

/// Halaman detail sebuah PC: pratinjau layar, spesifikasi, dan aksi.
class DeviceDetailPage extends ConsumerWidget {
  const DeviceDetailPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final device = ref.watch(
      deviceRepoProvider.select(
        (list) => list.where((d) => d.id == deviceId).firstOrNull,
      ),
    );

    if (device == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.textMid),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            context.tr('device_not_found'),
            style: TextStyle(color: c.textMid),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(device.name),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.textMid),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              LucideIcons.ellipsisVertical,
              size: 19,
              color: c.textMid,
            ),
            onPressed: () => _menu(context, ref, device),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.screen, 0, Gap.screen, 120),
        children: [
          _ScreenPreview(device: device),
          const SizedBox(height: Gap.xl),
          _StatusBar(device: device),
          const SizedBox(height: Gap.xl),
          SectionLabel(context.tr('device_detail'), top: 0),
          _spec(context, LucideIcons.hash, 'ID', device.prettyId, copy: true),
          _spec(context, LucideIcons.monitor, 'Sistem operasi', device.os),
          if (device.gpu != null)
            _spec(context, LucideIcons.cpu, 'GPU', device.gpu!),
          _spec(context, LucideIcons.maximize, 'Resolusi', device.resolution),
          _spec(
            context,
            LucideIcons.clock,
            'Terakhir aktif',
            _ago(context, device.lastSeen),
          ),
          if (device.pingMs != null)
            _spec(
              context,
              LucideIcons.activity,
              'Latensi',
              '${device.pingMs} ms',
            ),
          _spec(
            context,
            LucideIcons.shieldCheck,
            'Perangkat tepercaya',
            device.remembered ? 'Ya' : 'Tidak',
          ),
        ],
      ),
      bottomNavigationBar: _BottomActions(device: device),
    );
  }

  Widget _spec(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool copy = false,
  }) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.textLow),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: c.textMid),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.textHi,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (copy) ...[
            const SizedBox(width: Gap.sm),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(context.tr('copied'))));
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.copy, size: 14, color: c.textLow),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _ago(BuildContext context, DateTime? t) {
    if (t == null) return '—';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    return '${d.inDays} hari lalu';
  }

  void _menu(BuildContext context, WidgetRef ref, Device d) {
    final c = context.c;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.overlay,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.sm),
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: c.textLow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: Gap.md),
            ListTile(
              leading: Icon(LucideIcons.pencil, size: 18, color: c.textMid),
              title: Text(
                ctx.tr('device_rename'),
                style: TextStyle(fontSize: 14, color: c.textHi),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _rename(context, ref, d);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, size: 18, color: c.danger),
              title: Text(
                ctx.tr('device_remove'),
                style: TextStyle(fontSize: 14, color: c.danger),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(deviceRepoProvider.notifier).remove(d.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  void _rename(BuildContext context, WidgetRef ref, Device d) {
    final ctrl = TextEditingController(text: d.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          ctx.tr('device_rename'),
          style: const TextStyle(fontSize: 15),
        ),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(deviceRepoProvider.notifier)
                  .rename(d.id, ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(ctx.tr('save')),
          ),
        ],
      ),
    );
  }
}

/// Pratinjau layar PC.
///
/// Kalau perangkat pernah dipakai di sesi remote, tampilkan **cuplikan
/// layar terakhir** yang ditangkap saat sesi (via [saveSessionPreview]),
/// bukan ilustrasi. Kalau belum ada cuplikan, tampilkan keterangan jujur
/// (bukan ilustrasi khayalan) agar pengguna tidak mengira layar ini asli.
class _ScreenPreview extends ConsumerWidget {
  const _ScreenPreview({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final store = ref.watch(storeProvider);
    final preview = loadSessionPreview(store, device.id);

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        decoration: BoxDecoration(
          color: c.raised,
          borderRadius: BorderRadius.circular(R.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (preview != null)
              Image.memory(
                preview,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox(),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      device.isOnline
                          ? LucideIcons.monitor
                          : LucideIcons.monitorOff,
                      size: 34,
                      color: c.textLow,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada cuplikan layar',
                      style: TextStyle(fontSize: 12, color: c.textLow),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: _Chip(
                text: preview != null
                    ? 'Cuplikan terakhir'
                    : (device.isOnline
                          ? context.tr('device_preview')
                          : context.tr('status_offline')),
                color: preview != null
                    ? c.accent
                    : (device.isOnline ? AppColors.success : c.textLow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, color) = switch (device.status) {
      DeviceStatus.online => (context.tr('status_online'), AppColors.success),
      DeviceStatus.busy => ('Sedang dipakai', AppColors.warning),
      DeviceStatus.offline => (context.tr('status_offline'), c.textLow),
    };

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: c.textHi,
          ),
        ),
        const Spacer(),
        if (device.pingMs != null)
          Text(
            '${device.pingMs} ms',
            style: TextStyle(fontSize: 12, color: c.textMid),
          ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.fromLTRB(
        Gap.screen,
        Gap.md,
        Gap.screen,
        Gap.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [c.bg, c.bg.withValues(alpha: 0)],
          stops: const [0.55, 1],
        ),
      ),
      child: FilledButton(
        onPressed: device.isOnline
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SessionPage(deviceName: device.name, deviceId: device.id),
                ),
              )
            : null,
        child: Text(
          device.isOnline
              ? context.tr('device_connect')
              : context.tr('status_offline'),
        ),
      ),
    );
  }
}
