import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n_bridge.dart';
import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../devices/device_detail_page.dart';
import '../devices/device_model.dart';
import '../host/host_mode_page.dart';
import '../session/session_page.dart';

/// Beranda menampilkan daftar perangkat langsung dari penyimpanan lokal —
/// tanpa jeda tiruan. Penyimpanan dibaca sinkron saat repo dibuat, jadi
/// tidak ada kondisi memuat yang perlu dipalsukan; state kosong jujur
/// ditampilkan bila memang belum ada perangkat.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isWindows) return const HostModePage();

    final devices = ref.watch(deviceRepoProvider);
    final topPad = MediaQuery.paddingOf(context).top + 60;

    if (devices.isEmpty) {
      return IllustrationState(
        asset: Img.empty,
        title: context.tr('home_empty_title'),
        message: context.tr('home_empty_msg'),
      );
    }

    // Tablet mendapat dua kolom agar ruang tidak terbuang.
    final cols = Responsive.isTablet(context) ? 2 : 1;

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(deviceRepoProvider.notifier).reloadFromStore();
      },
      child: cols == 1
          ? ListView.builder(
              padding: EdgeInsets.only(top: topPad, bottom: 110),
              itemCount: devices.length,
              itemBuilder: (_, i) => _DeviceCard(device: devices[i]),
            )
          : GridView.builder(
              padding: EdgeInsets.only(top: topPad, bottom: 110),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 116,
              ),
              itemCount: devices.length,
              itemBuilder: (_, i) => _DeviceCard(device: devices[i]),
            ),
    );
  }
}

/// Kartu perangkat dengan ilustrasi status online / offline.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final online = device.isOnline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.raised,
        borderRadius: BorderRadius.circular(R.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeviceDetailPage(deviceId: device.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                // Ilustrasi PC berbeda untuk online dan offline — lebih cepat
                // dikenali daripada sekadar titik warna.
                Opacity(
                  opacity: online ? 1 : 0.45,
                  child: Illus(online ? Img.pcOnline : Img.pcOffline, size: 48),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: online ? c.textHi : c.textMid,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        device.gpu == null
                            ? device.os
                            : '${device.os} · ${device.gpu}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: c.textLow),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.sm),
                _StatusPill(device: device),
                if (online) ...[
                  const SizedBox(width: Gap.sm),
                  IconButton(
                    icon: Icon(LucideIcons.play, size: 18, color: c.accent),
                    tooltip: 'Mulai Sesi Langsung',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionPage(
                          deviceName: device.name,
                          deviceId: device.id,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (text, color) = switch (device.status) {
      DeviceStatus.online => ('${device.pingMs} ms', AppColors.success),
      DeviceStatus.busy => ('${device.pingMs} ms', AppColors.warning),
      DeviceStatus.offline => (context.tr('status_offline'), c.textLow),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 11, color: c.textMid)),
        const SizedBox(width: 2),
        Icon(LucideIcons.chevronRight, size: 15, color: c.textLow),
      ],
    );
  }
}
