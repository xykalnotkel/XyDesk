import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import 'app_update_details.dart';
import 'update_download_service.dart';
import 'update_repository.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, required this.details});

  final AppUpdateDetails details;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> with WidgetsBindingObserver {
  static final Uri _officialReleasesUri = Uri.parse(
    'https://github.com/xykalnotkel/XyDesk/releases/latest',
  );

  final _repository = const OfficialUpdateRepository();
  final _downloader = const AndroidUpdateDownloader();

  UpdateCheckResult? _checkResult;
  UpdateDownloadStatus _downloadStatus = const UpdateDownloadStatus.idle();
  Timer? _pollTimer;
  bool _checking = true;
  bool _acting = false;
  bool _refreshingDownload = false;
  String? _checkError;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdates();
    _refreshDownloadStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDownloadStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    if (mounted) {
      setState(() {
        _checking = true;
        _checkError = null;
      });
    }
    try {
      final result = await _repository.check();
      if (!mounted) return;
      setState(() {
        _checkResult = result;
        _checking = false;
      });
      await _refreshDownloadStatus();
    } on UpdateCheckException catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _checkError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _checkError = 'Pemeriksaan update belum dapat diselesaikan.';
      });
    }
  }

  Future<void> _refreshDownloadStatus() async {
    if (!_downloader.isSupported || _refreshingDownload) return;
    _refreshingDownload = true;
    try {
      final status = await _downloader.status();
      if (!mounted) return;
      _applyDownloadStatus(status);
    } on UpdateDownloadException catch (error) {
      if (!mounted) return;
      setState(() => _actionError = error.message);
    } finally {
      _refreshingDownload = false;
    }
  }

  void _applyDownloadStatus(UpdateDownloadStatus status) {
    setState(() {
      _downloadStatus = status;
      if (status.phase != UpdateDownloadPhase.failed) _actionError = null;
    });
    if (status.isActive) {
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => _refreshDownloadStatus(),
      );
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _startDownload() async {
    final manifest = _checkResult?.manifest;
    if (manifest == null || _acting) return;
    setState(() {
      _acting = true;
      _actionError = null;
    });
    try {
      final status = await _downloader.start(manifest);
      if (!mounted) return;
      _applyDownloadStatus(status);
    } on UpdateDownloadException catch (error) {
      if (!mounted) return;
      setState(() => _actionError = error.message);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _installUpdate() async {
    if (_acting) return;
    setState(() {
      _acting = true;
      _actionError = null;
    });
    try {
      final status = await _downloader.install();
      if (!mounted) return;
      _applyDownloadStatus(status);
    } on UpdateDownloadException catch (error) {
      if (!mounted) return;
      if (error.needsInstallPermission) {
        await _showInstallPermissionDialog();
      } else {
        setState(() => _actionError = error.message);
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _showInstallPermissionDialog() async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izinkan pemasangan update'),
        content: const Text(
          'Android memerlukan izin “Instal aplikasi yang tidak dikenal” untuk '
          'XyDesk. Anda tetap harus meninjau dan mengonfirmasi pemasangan di '
          'installer Android.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Buka pengaturan'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await _downloader.openInstallPermissionSettings();
    }
  }

  Future<void> _openOfficialRelease() async {
    final uri = _checkResult?.manifest.releasePageUri ?? _officialReleasesUri;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub Release tidak dapat dibuka.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final result = _checkResult;
    final details = result?.manifest.details ?? widget.details;
    final latest = result != null && !result.updateAvailable;

    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppBar(
        backgroundColor: context.c.bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Row(
          children: [
            BrandLogo(size: 31),
            SizedBox(width: 10),
            Text(
              'Pusat Update',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/img/xydesk_update_banner.jpg',
                fit: BoxFit.cover,
                semanticLabel: 'Banner update resmi XyDesk',
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  icon: latest ? LucideIcons.circleCheck : LucideIcons.sparkles,
                  label: latest ? 'Versi terbaru' : details.version,
                  color: latest ? const Color(0xFF178B57) : colors.primary,
                ),
                const _StatusChip(
                  icon: LucideIcons.shieldCheck,
                  label: 'Release resmi',
                  color: Color(0xFF49627C),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              latest ? 'XyDesk sudah terbaru' : details.title,
              style: TextStyle(
                color: context.c.textHi,
                fontSize: 24,
                height: 1.18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              latest
                  ? 'Build yang terpasang sudah sama atau lebih baru dari '
                        'Release resmi saat ini.'
                  : details.message,
              style: TextStyle(
                color: context.c.textMid,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            _VersionCard(result: result, checking: _checking),
            if (_checkError != null) ...[
              const SizedBox(height: 12),
              _MessageCard(
                icon: LucideIcons.wifiOff,
                message: _checkError!,
                color: const Color(0xFFA76200),
              ),
            ],
            if (details.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Yang disiapkan',
                style: TextStyle(
                  color: context.c.textHi,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...details.releaseNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _NoteRow(note: note),
                ),
              ),
            ],
            if (_downloadStatus.phase != UpdateDownloadPhase.idle) ...[
              const SizedBox(height: 10),
              _DownloadCard(status: _downloadStatus),
            ],
            if (_actionError != null) ...[
              const SizedBox(height: 12),
              _MessageCard(
                icon: LucideIcons.triangleAlert,
                message: _actionError!,
                color: const Color(0xFFB23B35),
              ),
            ],
            const SizedBox(height: 18),
            _buildPrimaryAction(result),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openOfficialRelease,
              icon: const Icon(LucideIcons.externalLink, size: 18),
              label: const Text('Lihat GitHub Release resmi'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _SafetyNotice(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryAction(UpdateCheckResult? result) {
    if (_checking) {
      return const FilledButton(
        onPressed: null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Memeriksa Release resmi…'),
          ],
        ),
      );
    }
    if (result == null) {
      return FilledButton.icon(
        onPressed: _checkForUpdates,
        icon: const Icon(LucideIcons.refreshCw, size: 18),
        label: const Text('Coba cek lagi'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      );
    }
    if (!result.updateAvailable) {
      return FilledButton.icon(
        onPressed: _checkForUpdates,
        icon: const Icon(LucideIcons.circleCheck, size: 18),
        label: const Text('Anda memakai versi terbaru'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: const Color(0xFF178B57),
        ),
      );
    }
    if (!result.isAndroid) {
      return FilledButton.icon(
        onPressed: _openOfficialRelease,
        icon: const Icon(LucideIcons.externalLink, size: 18),
        label: const Text('Buka download resmi'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      );
    }

    return switch (_downloadStatus.phase) {
      UpdateDownloadPhase.ready => FilledButton.icon(
        onPressed: _acting ? null : _installUpdate,
        icon: const Icon(LucideIcons.packageCheck, size: 18),
        label: Text(_acting ? 'Menyiapkan installer…' : 'Pasang update'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: const Color(0xFF178B57),
        ),
      ),
      UpdateDownloadPhase.queued ||
      UpdateDownloadPhase.running ||
      UpdateDownloadPhase.paused ||
      UpdateDownloadPhase.verifying => FilledButton.icon(
        onPressed: null,
        icon: const Icon(LucideIcons.download, size: 18),
        label: const Text('Download berjalan di latar belakang'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
      _ => FilledButton.icon(
        onPressed: _acting ? null : _startDownload,
        icon: const Icon(LucideIcons.download, size: 18),
        label: Text(
          _acting
              ? 'Menyiapkan download…'
              : _downloadStatus.phase == UpdateDownloadPhase.failed
              ? 'Coba unduh lagi'
              : 'Unduh update',
        ),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
    };
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.result, required this.checking});

  final UpdateCheckResult? result;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final installed = result == null
        ? checking
              ? 'Memuat…'
              : 'Belum diketahui'
        : '${result!.installedVersion}+${result!.installedBuildNumber}';
    final release = result == null
        ? checking
              ? 'Memeriksa…'
              : 'Belum diketahui'
        : '${result!.manifest.version}+${result!.manifest.buildNumber}';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EBF0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VersionValue(label: 'Terpasang', value: installed),
          ),
          const SizedBox(width: 1, height: 40),
          Expanded(
            child: _VersionValue(label: 'Release resmi', value: release),
          ),
        ],
      ),
    );
  }
}

class _VersionValue extends StatelessWidget {
  const _VersionValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.c.textMid,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.c.textHi,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.status});

  final UpdateDownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final ready = status.phase == UpdateDownloadPhase.ready;
    final failed = status.phase == UpdateDownloadPhase.failed;
    final color = ready
        ? const Color(0xFF178B57)
        : failed
        ? const Color(0xFFB23B35)
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready
                    ? LucideIcons.shieldCheck
                    : failed
                    ? LucideIcons.triangleAlert
                    : LucideIcons.download,
                color: color,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  status.message ?? 'Memproses update…',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (status.isActive) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: status.progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(20),
            ),
            const SizedBox(height: 7),
            Text(
              _progressLabel(status),
              style: TextStyle(
                color: context.c.textMid,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _progressLabel(UpdateDownloadStatus status) {
    if (status.totalBytes <= 0) {
      return 'Progress juga terlihat di notifikasi sistem Android.';
    }
    final percent = ((status.progress ?? 0) * 100).round();
    return '$percent%  •  ${_formatBytes(status.downloadedBytes)} dari '
        '${_formatBytes(status.totalBytes)}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EBEF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.check,
              size: 14,
              color: Color(0xFF178B57),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                color: context.c.textHi,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.shieldCheck, size: 19, color: Color(0xFF49627C)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'APK diunduh oleh Android di latar belakang. Sebelum tombol '
              '“Pasang update” aktif, XyDesk memeriksa checksum SHA-256, '
              'package ID, nomor build, dan sertifikat signing. Pemasangan '
              'tetap memerlukan konfirmasi Anda di installer Android.',
              style: TextStyle(
                color: Color(0xFF49627C),
                fontSize: 11.5,
                height: 1.48,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
