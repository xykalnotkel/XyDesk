import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/devlog.dart';
import '../../core/l10n_bridge.dart';
import '../../core/responsive.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/seamless.dart';
import '../auth/legal_page.dart';
import 'billing_page.dart';
import 'permissions_page.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final s = ref.watch(settingsProvider);
    final user = ref.watch(authProvider);
    final lang = ref.watch(langProvider);

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 56,
        bottom: 110,
      ),
      children: [
        // ── Identitas ──
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.raised,
                shape: BoxShape.circle,
              ),
              child: Text(
                user.initial,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.textMid,
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.isGuest
                        ? context.tr('account_guest')
                        : (user.name ?? context.tr('account_user')),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textHi,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email ?? context.tr('account_local_data'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: c.textLow),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Tampilan ──
        SectionLabel(context.tr('settings_appearance')),
        _ThemeSelector(current: s.themeMode),
        ListRow(
          title: context.tr('settings_language'),
          icon: LucideIcons.languages,
          value: lang.nativeName,
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => _pickLanguage(context, ref),
        ),

        // ── Perilaku ──
        SectionLabel(context.tr('settings_behavior')),
        _SwitchRow(
          title: context.tr('behavior_vibration'),
          icon: LucideIcons.vibrate,
          value: s.haptics,
          onChanged: ref.read(settingsProvider.notifier).setHaptics,
        ),
        _SwitchRow(
          title: context.tr('behavior_high_refresh'),
          subtitle: context
              .tr('behavior_high_refresh_sub')
              .replaceAll('{hz}', '${DisplayMode.current.round()}'),
          icon: LucideIcons.zap,
          value: s.highRefresh,
          onChanged: ref.read(settingsProvider.notifier).setHighRefresh,
        ),
        _SwitchRow(
          title: context.tr('behavior_reduce_motion'),
          subtitle: context.tr('behavior_reduce_motion_sub'),
          icon: LucideIcons.accessibility,
          value: s.reduceMotion,
          onChanged: ref.read(settingsProvider.notifier).setReduceMotion,
        ),
        _SwitchRow(
          title: context.tr('behavior_devlog'),
          subtitle: context.tr('behavior_devlog_sub'),
          icon: LucideIcons.bug,
          value: s.showDevLog,
          onChanged: ref.read(settingsProvider.notifier).setShowDevLog,
        ),

        // ── Langganan ──
        const SectionLabel('Langganan'),
        ListRow(
          title: 'XyDesk Premium',
          subtitle: 'Paket, benefit, dan billing',
          icon: LucideIcons.crown,
          value: 'Free',
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BillingPage()),
          ),
        ),

        // ── Mesin Streaming & Kualitas (DXGI + NVENC / AMF) ──
        const SectionLabel('Mesin Streaming (DXGI + NVENC / AMF)'),
        ListRow(
          title: 'Codec Video (GPU Hardware)',
          subtitle: 'Pengodean akselerasi perangkat keras',
          icon: LucideIcons.cpu,
          value: s.codec,
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => _pickCodec(context, ref),
        ),
        ListRow(
          title: 'Resolusi & Target FPS',
          subtitle: 'Kualitas video stream dari Host',
          icon: LucideIcons.monitor,
          value: s.resolution,
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => _pickResolution(context, ref),
        ),
        ListRow(
          title: 'Bitrate Maksimal',
          subtitle: 'Alokasi bandwidth jaringan',
          icon: LucideIcons.gauge,
          value: '${s.bitrateMbps} Mbps',
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => _pickBitrate(context, ref),
        ),
        _SwitchRow(
          title: 'Mode FPS / Trackpad Relatif',
          subtitle: 'Kunci kursor mouse di tengah untuk game FPS',
          icon: LucideIcons.crosshair,
          value: s.relativeMouseMode,
          onChanged: ref.read(settingsProvider.notifier).setRelativeMouseMode,
        ),
        _SwitchRow(
          title: 'Audio PC Host Streaming',
          subtitle: 'Putar suara komputer remote di perangkat ini',
          icon: LucideIcons.volume2,
          value: s.audioEnabled,
          onChanged: ref.read(settingsProvider.notifier).setAudioEnabled,
        ),
        _SwitchRow(
          title: 'Microphone Passthrough',
          subtitle: 'Kirim audio mikrofon untuk voice-chat di PC',
          icon: LucideIcons.mic,
          value: s.micPassthrough,
          onChanged: ref.read(settingsProvider.notifier).setMicPassthrough,
        ),
        _SwitchRow(
          title: 'Sinkronisasi Papan Klip',
          subtitle: 'Copy-paste teks & gambar lintas perangkat',
          icon: LucideIcons.clipboard,
          value: s.clipboardSync,
          onChanged: ref.read(settingsProvider.notifier).setClipboardSync,
        ),

        // ── Sistem ──
        SectionLabel(context.tr('settings_system')),
        ListRow(
          title: context.tr('settings_permissions'),
          icon: LucideIcons.shield,
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PermissionsPage())),
        ),
        ListRow(
          title: context.tr('settings_devlog'),
          icon: LucideIcons.fileText,
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => DevLog.openPage(context),
        ),

        // ── Legal ──
        SectionLabel(context.tr('settings_legal')),
        ListRow(
          title: context.tr('legal_terms'),
          icon: LucideIcons.scale,
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => LegalPage.open(context, LegalDoc.terms),
        ),
        ListRow(
          title: context.tr('legal_privacy'),
          icon: LucideIcons.lock,
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => LegalPage.open(context, LegalDoc.privacy),
        ),
        ListRow(
          title: context.tr('legal_licenses'),
          icon: LucideIcons.code,
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => LegalPage.open(context, LegalDoc.licenses),
        ),
        ListRow(
          title: context.tr('settings_about'),
          icon: LucideIcons.info,
          value: 'v1.0.0',
          trailing: Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
        ),

        const SizedBox(height: Gap.md),
        ListRow(
          title: context.tr('sign_out'),
          icon: LucideIcons.logOut,
          danger: true,
          onTap: () => ref.read(authProvider.notifier).signOut(),
        ),
      ],
    );
  }

  void _pickLanguage(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final current = ref.read(settingsProvider).langCode;
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
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textLow.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(
              ctx.tr('settings_language'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: Gap.sm),
            for (final l in AppLang.all)
              ListTile(
                dense: true,
                title: Text(
                  l.nativeName,
                  style: TextStyle(fontSize: 14, color: c.textHi),
                ),
                subtitle: Text(
                  l.name,
                  style: TextStyle(fontSize: 11, color: c.textLow),
                ),
                trailing: l.code == current
                    ? Icon(LucideIcons.check, size: 17, color: c.accent)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setLang(l.code);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  void _pickCodec(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final current = ref.read(settingsProvider).codec;
    final options = [
      ('AV1 (NVENC / AMF GPU)', 'Latensi Terendah & Bandwidth Efisien (Rekomendasi Gaming)'),
      ('HEVC / H.265 (10-bit)', 'Warna Visual & HDR'),
      ('H.264 (AVC Universal)', 'Kompatibilitas Maksimal Semua GPU'),
    ];
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
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textLow.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Codec Video Engine',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: Gap.sm),
            for (final opt in options)
              ListTile(
                dense: true,
                title: Text(
                  opt.$1,
                  style: TextStyle(fontSize: 14, color: c.textHi),
                ),
                subtitle: Text(
                  opt.$2,
                  style: TextStyle(fontSize: 11, color: c.textLow),
                ),
                trailing: opt.$1 == current
                    ? Icon(LucideIcons.check, size: 17, color: c.accent)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setCodec(opt.$1);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  void _pickResolution(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final current = ref.read(settingsProvider).resolution;
    final options = [
      ('720p60 (HD)', '1280×720 • 60 FPS • Hemat Data'),
      ('1080p60 (FHD)', '1920×1080 • 60 FPS • Rekomendasi Gaming'),
      ('1440p120 (QHD 2K)', '2560×1440 • 120 FPS • Esport Low Latency'),
      ('4K60 (UHD)', '3840×2160 • 60 FPS • Kualitas Studio'),
    ];
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
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textLow.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Resolusi & Target FPS',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: Gap.sm),
            for (final opt in options)
              ListTile(
                dense: true,
                title: Text(
                  opt.$1,
                  style: TextStyle(fontSize: 14, color: c.textHi),
                ),
                subtitle: Text(
                  opt.$2,
                  style: TextStyle(fontSize: 11, color: c.textLow),
                ),
                trailing: opt.$1 == current
                    ? Icon(LucideIcons.check, size: 17, color: c.accent)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setResolution(opt.$1);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  void _pickBitrate(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final current = ref.read(settingsProvider).bitrateMbps;
    final options = [
      (10, '10 Mbps', 'Hemat Bandwidth (LAN / Wi-Fi Standar)'),
      (25, '25 Mbps', 'Kualitas Seimbang (Rekomendasi)'),
      (50, '50 Mbps', 'Tanpa Kompresi (LAN Gigabit)'),
    ];
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
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.textLow.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Bitrate Maksimal',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: Gap.sm),
            for (final opt in options)
              ListTile(
                dense: true,
                title: Text(
                  opt.$2,
                  style: TextStyle(fontSize: 14, color: c.textHi),
                ),
                subtitle: Text(
                  opt.$3,
                  style: TextStyle(fontSize: 11, color: c.textLow),
                ),
                trailing: opt.$1 == current
                    ? Icon(LucideIcons.check, size: 17, color: c.accent)
                    : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setBitrateMbps(opt.$1);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }
}

/// Pemilih tema tiga pilihan.
class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final items = <(ThemeMode, String, IconData)>[
      (ThemeMode.dark, context.tr('settings_theme_dark'), LucideIcons.moon),
      (ThemeMode.light, context.tr('settings_theme_light'), LucideIcons.sun),
      (
        ThemeMode.system,
        context.tr('settings_theme_system'),
        LucideIcons.smartphone,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Row(
        children: [
          for (final (mode, label, icon) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => ref.read(settingsProvider.notifier).setTheme(mode),
                child: AnimatedContainer(
                  duration: D.tab,
                  curve: D.curve,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: current == mode ? c.raised : Colors.transparent,
                    borderRadius: BorderRadius.circular(R.sm),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: current == mode ? c.textHi : c.textLow,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: current == mode ? c.textHi : c.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: c.textMid),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.textHi,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: c.textLow,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// Halaman Tentang.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(context.tr('settings_about')),
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
          const Center(child: BrandLockup(size: 72)),
          const SizedBox(height: Gap.md),
          Center(
            child: Text(
              'Versi 1.0.0 · Build 2',
              style: TextStyle(fontSize: 11.5, color: c.textLow),
            ),
          ),
          const SizedBox(height: Gap.xl),
          ListRow(
            title: context.tr('about_release_notes'),
            subtitle: 'Apa yang baru di 1.0.0',
            icon: LucideIcons.list,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Catatan rilis akan hadir.')),
            ),
          ),
          ListRow(
            title: context.tr('about_check_updates'),
            subtitle: 'Kamu memakai versi terbaru',
            icon: LucideIcons.refreshCw,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kamu memakai versi terbaru.')),
            ),
          ),
          const SectionLabel('Diagnostik'),
          ListRow(
            title: 'Salin ID diagnostik',
            subtitle: 'a7f3-9c21-4e88',
            icon: LucideIcons.key,
            trailing: Icon(LucideIcons.copy, size: 15, color: c.textLow),
            onTap: () {
              Clipboard.setData(const ClipboardData(text: 'a7f3-9c21-4e88'));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(context.tr('copied'))));
            },
          ),
          ListRow(
            title: context.tr('settings_devlog'),
            icon: LucideIcons.bug,
            trailing: Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: c.textLow,
            ),
            onTap: () => DevLog.openPage(context),
          ),
        ],
      ),
    );
  }
}
