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

          // ── Info Dasar ──
          const SectionLabel('Informasi Perangkat', top: 0),
          _spec(context, LucideIcons.hash, 'ID', device.prettyId, copy: true),
          _spec(
            context,
            LucideIcons.monitor,
            'Sistem operasi',
            _orUnknown(device.os),
          ),
          _spec(
            context,
            LucideIcons.maximize,
            'Resolusi utama',
            _orUnknown(device.resolution),
          ),
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

          // ── Spesifikasi Hardware ──
          // Ditampilkan bila host MELAPORKAN spesifikasinya (host >= 6.7.0)
          // atau sudah ada data monitor tersimpan. Di dalam seksi, semua baris
          // selalu muncul: host yang gagal membaca satu nilai menulis "Tidak
          // terdeteksi", dan itu informasi — bukan lubang yang disembunyikan.
          //
          // Host versi lama tidak pernah ditanya, jadi seksinya tidak muncul
          // sama sekali; menulis "Tidak terdeteksi" di situ akan menuduh mesin
          // pengguna atas keterbatasan aplikasi.
          if (device.specsReported || device.displays.isNotEmpty) ...[
            const SizedBox(height: Gap.xl),
            const SectionLabel('Spesifikasi Hardware'),

            _spec(
              context,
              LucideIcons.cpu,
              'Motherboard',
              _orUnknown(device.motherboard),
            ),
            _spec(context, LucideIcons.cpu, 'Prosesor', _orUnknown(device.cpu)),
            _spec(
              context,
              LucideIcons.gpu,
              'Kartu grafis',
              _orUnknown(device.gpu),
            ),
            _spec(
              context,
              LucideIcons.memoryStick,
              'RAM',
              _orUnknown(device.ram),
            ),
            _spec(
              context,
              LucideIcons.hardDrive,
              'Penyimpanan',
              _orUnknown(device.storage),
            ),

            // ── Daftar Monitor ──
            if (device.displays.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.c.raised,
                  borderRadius: BorderRadius.circular(R.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.monitor,
                          size: 16,
                          color: context.c.textLow,
                        ),
                        const SizedBox(width: Gap.sm),
                        Text(
                          'Monitor tersambung (${device.displays.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.c.textHi,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    for (final display in device.displays) ...[
                      _DisplayCard(display: display),
                      if (display != device.displays.last)
                        const SizedBox(height: Gap.sm),
                    ],
                  ],
                ),
              ),
            ],
          ],
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
            // Timestamp kapan screenshot diambil
            if (preview != null)
              Positioned(
                right: 12,
                top: 12,
                child: _Chip(text: _formatTimestamp(context), color: c.textLow),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(BuildContext context) {
    final now = DateTime.now();
    final lastSeen = DateTime(now.year, now.month, now.day - 1);
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}j lalu';
    } else {
      return '${diff.inDays}h lalu';
    }
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

class _DisplayCard extends StatelessWidget {
  const _DisplayCard({required this.display});

  final DisplayInfo display;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.input.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(
          color: display.isPrimary
              ? c.accent.withValues(alpha: 0.3)
              : c.textLow.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                display.isPrimary
                    ? LucideIcons.monitor
                    : LucideIcons.monitorDot,
                size: 16,
                color: display.isPrimary ? c.accent : c.textLow,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  display.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                  ),
                ),
              ),
              if (display.isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'UTAMA',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: c.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: _DisplaySpec(
                  icon: LucideIcons.maximize,
                  value: display.resolution,
                ),
              ),
              if (display.refreshRate != null)
                Expanded(
                  child: _DisplaySpec(
                    icon: LucideIcons.zap,
                    value: display.refreshRateLabel,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DisplaySpec extends StatelessWidget {
  const _DisplaySpec({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Icon(icon, size: 13, color: c.textLow),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            color: c.textMid,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Nilai spesifikasi yang tidak/belum terbaca dari host.
///
/// Ditulis eksplisit supaya layar detail perangkat tidak pernah menampilkan
/// angka karangan. Host yang tidak melaporkan motherboard lebih baik terlihat
/// sebagai "Tidak terdeteksi" daripada disembunyikan (pengguna tidak bisa
/// membedakan "host tidak menjawab" dari "aplikasi tidak bertanya") atau diisi
/// tebakan yang kelihatan meyakinkan.
String _orUnknown(String? value) {
  final v = value?.trim() ?? '';
  return v.isEmpty ? 'Tidak terdeteksi' : v;
}
