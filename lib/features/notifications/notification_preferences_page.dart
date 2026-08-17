import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tokens.dart';
import '../../widgets/seamless.dart';
import 'notification_service.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> with WidgetsBindingObserver {
  final _service = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_rebuild);
    unawaited(_service.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_rebuild);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_service.refresh());
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (_service.active) {
      await _service.pauseUpdates();
      return;
    }

    final enabled = await _service.enableUpdates();
    if (!mounted || enabled) return;
    final message = _service.lastError ??
        'Notifikasi belum aktif. Jika izin pernah ditolak, aktifkan melalui '
            'pengaturan notifikasi Android.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final status = _status;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Notifikasi pembaruan'),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.textMid),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.xl,
          Gap.screen,
          Gap.h40,
        ),
        children: [
          Center(
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.accent.withValues(alpha: 0.28),
                    c.raised,
                  ],
                ),
                borderRadius: BorderRadius.circular(R.xl),
              ),
              child: Icon(
                _service.active ? LucideIcons.bell : LucideIcons.bellOff,
                size: 34,
                color: c.accent,
              ),
            ),
          ),
          const SizedBox(height: Gap.xl),
          Text(
            'Tahu saat XyDesk diperbarui',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: c.textHi,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'XyDesk hanya mengirim pengumuman versi baru sesekali. '
            'Tidak ada promosi rutin dan izin ini selalu opsional.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.6, color: c.textMid),
          ),
          const SectionLabel('Status'),
          SurfaceCard(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(status.icon, size: 17, color: status.color),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textHi,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status.description,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: c.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('Cara kerjanya'),
          const _InfoRow(
            icon: LucideIcons.smartphone,
            title: 'Kamu yang memutuskan',
            body: 'Dialog izin Android baru muncul setelah tombol Aktifkan '
                'ditekan, bukan saat aplikasi pertama dibuka.',
          ),
          const _InfoRow(
            icon: LucideIcons.packageOpen,
            title: 'Masuk ke halaman internal',
            body: 'Mengetuk notifikasi membuka detail update di XyDesk lebih '
                'dahulu, bukan langsung memasang APK.',
          ),
          const _InfoRow(
            icon: LucideIcons.shieldCheck,
            title: 'Unduhan resmi',
            body: 'Aksi unduh pada halaman update hanya menuju GitHub Releases '
                'resmi XyDesk.',
          ),
          const SizedBox(height: Gap.xl),
          FilledButton.icon(
            onPressed: !_service.supported || _service.busy ? null : _toggle,
            icon: _service.busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _service.active ? LucideIcons.bellOff : LucideIcons.bell,
                    size: 17,
                  ),
            label: Text(
              _service.busy
                  ? 'Menyiapkan…'
                  : _service.active
                      ? 'Jeda notifikasi update'
                      : !_service.permissionGranted &&
                              !_service.canRequestPermission &&
                              _service.initialized
                          ? 'Buka pengaturan notifikasi'
                          : 'Aktifkan notifikasi update',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(R.md),
              ),
            ),
          ),
          if (_service.active) ...[
            const SizedBox(height: Gap.sm),
            Text(
              'Menjeda di sini tidak mengubah izin sistem; kamu bisa '
              'mengaktifkannya kembali kapan saja.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, height: 1.5, color: c.textLow),
            ),
          ],
        ],
      ),
    );
  }

  _NotificationStatus get _status {
    final c = context.c;
    if (!_service.supported) {
      return _NotificationStatus(
        title: 'Tidak tersedia di platform ini',
        description: 'Push update saat ini disiapkan untuk aplikasi Android.',
        icon: LucideIcons.info,
        color: c.textLow,
      );
    }
    if (_service.lastError != null && !_service.initialized) {
      return _NotificationStatus(
        title: 'Belum terhubung',
        description: _service.lastError!,
        icon: LucideIcons.info,
        color: AppColors.warning,
      );
    }
    if (_service.active) {
      return const _NotificationStatus(
        title: 'Aktif',
        description: 'Perangkat ini dapat menerima pengumuman versi baru.',
        icon: LucideIcons.check,
        color: AppColors.success,
      );
    }
    if (_service.permissionGranted && !_service.optedIn) {
      return _NotificationStatus(
        title: 'Dijeda',
        description: 'Izin Android ada, tetapi langganan XyDesk sedang dijeda.',
        icon: LucideIcons.bellOff,
        color: c.textLow,
      );
    }
    return _NotificationStatus(
      title: 'Belum diaktifkan',
      description: 'Tekan Aktifkan bila kamu ingin menerima info update.',
      icon: LucideIcons.bellOff,
      color: c.textLow,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: c.accent),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: c.textLow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationStatus {
  const _NotificationStatus({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}
