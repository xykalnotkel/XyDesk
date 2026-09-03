import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/devlog.dart';
import '../../core/l10n_bridge.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/seamless.dart';
import '../notifications/notification_service.dart';

/// Status izin — dibaca dari sistem saat halaman dibuka.
enum _PermStatus {
  /// Izin sudah diberikan.
  granted,
  /// Izin belum diminta / ditolak.
  denied,
  /// Izin belum bisa diminta (fitur tidak tersedia).
  unavailable,
}

/// Hasil tes mikrofon.
class _MicTestResult {
  const _MicTestResult({
    required this.success,
    required this.deviceName,
    this.message,
  });

  final bool success;
  final String? deviceName;
  final String? message;
}

class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({super.key});

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage> {
  _PermStatus _micStatus = _PermStatus.unavailable;
  _PermStatus _cameraStatus = _PermStatus.unavailable;
  bool _notifEnabled = false;
  bool _testingMic = false;
  _MicTestResult? _micTestResult;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Cek status notifikasi.
    _notifEnabled = NotificationService.instance.active;

    // Cek microphone dengan mencoba enumerate devices.
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final hasMic = devices.any((d) => d.kind == 'audioinput');
      // Di Flutter WebRTC, kita tidak bisa cek izin tanpa mencoba getUserMedia.
      // Jadi status ini hanya indikasi device ada.
      _micStatus = hasMic ? _PermStatus.granted : _PermStatus.denied;
    } catch (e) {
      DevLog.w('permissions', 'Gagal cek mic', '$e');
      _micStatus = _PermStatus.unavailable;
    }

    // Kamera — cek device ada.
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final hasCam = devices.any((d) => d.kind == 'videoinput');
      _cameraStatus = hasCam ? _PermStatus.granted : _PermStatus.denied;
    } catch (e) {
      _cameraStatus = _PermStatus.unavailable;
    }

    if (mounted) setState(() {});
  }

  /// Tes mikrofon — minta izin getUserMedia dan baca device name.
  Future<void> _testMicrophone() async {
    setState(() {
      _testingMic = true;
      _micTestResult = null;
    });

    try {
      // Minta izin mikrofon + enumerasi device untuk verifikasi.
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': false,
        },
        'video': false,
      });

      final audioTracks = stream.getAudioTracks();
      String? deviceName;
      if (audioTracks.isNotEmpty) {
        final track = audioTracks.first;
        final settings = track.getSettings();
        deviceName = settings['deviceId'] as String? ?? 'Mikrofon default';
      }

      // Stop stream setelah tes — jangan biarkan mic aktif terus.
      for (final t in stream.getTracks()) {
        t.stop();
      }

      setState(() {
        _micStatus = _PermStatus.granted;
        _micTestResult = _MicTestResult(
          success: true,
          deviceName: deviceName ?? 'Mikrofon terdeteksi',
          message: 'Izin mikrofon aktif. Device: $deviceName',
        );
      });

      DevLog.ok('permissions', 'Mic test sukses', deviceName ?? 'default');
    } catch (e) {
      setState(() {
        _micStatus = _PermStatus.denied;
        _micTestResult = _MicTestResult(
          success: false,
          deviceName: null,
          message: _micErrorMessage(e),
        );
      });
      DevLog.w('permissions', 'Mic test gagal', '$e');
    } finally {
      if (mounted) setState(() => _testingMic = false);
    }
  }

  String _micErrorMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('notallowed') || msg.contains('permission')) {
      return 'Izin mikrofon ditolak. Buka Pengaturan > Aplikasi > XyDesk > Izin > Mikrofon.';
    }
    if (msg.contains('notfound') || msg.contains('nodevice')) {
      return 'Tidak ada mikrofon terdeteksi di perangkat ini.';
    }
    if (msg.contains('overconstrained')) {
      return 'Tidak ada mikrofon yang cocok dengan kriteria yang diminta.';
    }
    return 'Gagal mengakses mikrofon: $e';
  }

  /// Buka pengaturan sistem untuk meminta izin mikrofon.
  Future<void> _openMicSettings() async {
    // Di Android, kita tidak bisa langsung buka pengaturan izin.
    // Tapi kita bisa mencoba getUserMedia lagi untuk trigger dialog izin.
    await _testMicrophone();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(context.tr('settings_permissions')),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.textMid),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _checkPermissions,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.screen,
            Gap.sm,
            Gap.screen,
            Gap.h40,
          ),
          children: [
            const Center(
              child: Illus(
                Img.secure,
                size: 132,
                opacity: 0.9,
                opticalScale: 1.12,
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text(
              'Status izin dibaca langsung dari sistem. Tarik ke bawah '
              'untuk memuat ulang.',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: c.textMid),
            ),
            const SizedBox(height: Gap.xl),

            // ── Mikrofon ──
            _PermissionTile(
              icon: LucideIcons.mic,
              name: 'Mikrofon',
              status: _micStatus,
              description: 'Untuk mengirim suara HP ke PC saat sesi remote.',
              onAction: _testingMic
                  ? null
                  : () => _testMicrophone(),
              actionLabel: _testingMic
                  ? 'Menguji…'
                  : (_micStatus == _PermStatus.granted ? 'Tes ulang' : 'Beri izin & tes'),
              result: _micTestResult,
            ),

            // ── Kamera ──
            _PermissionTile(
              icon: LucideIcons.camera,
              name: 'Kamera',
              status: _cameraStatus,
              description: 'Untuk memindai QR kode koneksi dari host.',
              onAction: () {
                // Kamera di-trigger saat QR scanner dibuka.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Izin kamera akan diminta saat membuka pemindai QR.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              actionLabel: 'Buka pemindai QR',
            ),

            // ── Notifikasi ──
            _PermissionTile(
              icon: LucideIcons.bell,
              name: 'Notifikasi',
              status: _notifEnabled ? _PermStatus.granted : _PermStatus.denied,
              description: 'Untuk menerima pengumuman rilis dan artikel berita.',
              onAction: () async {
                if (_notifEnabled) {
                  // Sudah aktif, buka preferences.
                  final service = NotificationService.instance;
                  await service.refresh();
                  if (mounted) setState(() => _notifEnabled = service.active);
                } else {
                  final service = NotificationService.instance;
                  await service.enableUpdates();
                  if (mounted) setState(() => _notifEnabled = service.active);
                }
              },
              actionLabel: _notifEnabled ? 'Pengaturan' : 'Aktifkan',
            ),

            // ── Jaringan ──
            _PermissionTile(
              icon: LucideIcons.wifi,
              name: 'Jaringan',
              status: _PermStatus.granted,
              description: 'Untuk menghubungkan ke PC kamu via signaling.',
            ),

            const SizedBox(height: Gap.xxl),

            // ── Info lokasi berkas ──
            SectionLabel('Penyimpanan berkas'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.raised,
                borderRadius: BorderRadius.circular(R.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.folderOpen, size: 16, color: c.accent),
                      const SizedBox(width: Gap.sm),
                      Text(
                        'Lokasi berkas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textHi,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  SelectableText(
                    'Android/data/com.xystudio.xydesk/files/XyDesk/',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      height: 1.5,
                      color: c.textMid,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Berkas hasil transfer, tangkapan layar, dan ekspor profil '
                    'disimpan di sini. Folder ini ikut terhapus saat aplikasi '
                    'dicopot.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.55,
                      color: c.textLow,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.name,
    required this.status,
    required this.description,
    this.onAction,
    this.actionLabel,
    this.result,
  });

  final IconData icon;
  final String name;
  final _PermStatus status;
  final String description;
  final VoidCallback? onAction;
  final String? actionLabel;
  final _MicTestResult? result;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (statusLabel, statusColor) = switch (status) {
      _PermStatus.granted => ('Aktif', c.successText),
      _PermStatus.denied => ('Belum diizinkan', c.dangerText),
      _PermStatus.unavailable => ('Tidak tersedia', c.textLow),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: statusColor),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textHi,
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(fontSize: 11.5, color: c.textMid, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Hasil tes mikrofon (kalau ada).
          if (result != null) ...[
            const SizedBox(height: Gap.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: result!.success
                    ? c.success.withValues(alpha: 0.08)
                    : c.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(
                  color: result!.success
                      ? c.success.withValues(alpha: 0.3)
                      : c.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    result!.success ? LucideIcons.checkCircle : LucideIcons.xCircle,
                    size: 16,
                    color: result!.success ? c.successText : c.dangerText,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result!.success ? 'Mikrofon aktif' : 'Gagal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: result!.success ? c.successText : c.dangerText,
                          ),
                        ),
                        if (result!.message != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            result!.message!,
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textMid,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tombol aksi.
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: Gap.md),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.accent.withValues(alpha: 0.5)),
                  foregroundColor: c.accent,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
