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
import '../auth/auth_service.dart';
import '../auth/legal_page.dart';
import '../notifications/app_update_details.dart';
import '../notifications/notification_preferences_page.dart';
import '../notifications/update_page.dart';
import '../session/media_capabilities.dart';
import 'billing_page.dart';
import 'permissions_page.dart';

/// Ringkasan akun. Pengaturan tidak lagi ditumpuk di halaman profil; setiap
/// kategori membuka layar fokusnya sendiri agar lebih mudah dipindai.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = ref.watch(authProvider);

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 64,
        bottom: 112,
      ),
      children: [
        _ProfileHero(
          initial: user.initial,
          name: user.isGuest
              ? context.tr('account_guest')
              : (user.name ?? context.tr('account_user')),
          email: user.email ?? context.tr('account_local_data'),
          badge: user.isGuest ? 'MODE TAMU' : 'AKUN AKTIF',
        ),
        const SectionLabel('Preferensi'),
        _CategoryRow(
          title: 'Tampilan & bahasa',
          subtitle: 'Tema, bahasa, dan kenyamanan visual',
          icon: LucideIcons.palette,
          onTap: () => _open(context, const AppearanceSettingsPage()),
        ),
        _CategoryRow(
          title: 'Perilaku & aksesibilitas',
          subtitle: 'Getaran, refresh rate, dan reduksi gerakan',
          icon: LucideIcons.slidersHorizontal,
          onTap: () => _open(context, const BehaviorSettingsPage()),
        ),
        _CategoryRow(
          title: 'Streaming & kontrol',
          subtitle: 'Codec, resolusi, bitrate, audio, dan input',
          icon: LucideIcons.monitorCog,
          onTap: () => _open(context, const StreamingSettingsPage()),
        ),
        _CategoryRow(
          title: 'Notifikasi',
          subtitle: 'Izin dan langganan pembaruan aplikasi',
          icon: LucideIcons.bell,
          onTap: () => _open(context, const NotificationPreferencesPage()),
        ),
        _CategoryRow(
          title: 'Sistem & privasi',
          subtitle: 'Izin perangkat, update, dan diagnostik',
          icon: LucideIcons.shieldCheck,
          onTap: () => _open(context, const SystemSettingsPage()),
        ),
        const SectionLabel('Akun & informasi'),
        _CategoryRow(
          title: 'XyDesk Premium',
          subtitle: 'Paket, benefit, dan billing',
          icon: LucideIcons.crown,
          value: 'Free',
          onTap: () => _open(context, const BillingPage()),
        ),
        _CategoryRow(
          title: 'Legal & tentang XyDesk',
          subtitle: 'Ketentuan, privasi, lisensi, dan versi aplikasi',
          icon: LucideIcons.info,
          onTap: () => _open(context, const LegalSettingsPage()),
        ),
        const SizedBox(height: Gap.lg),
        ListRow(
          title: context.tr('sign_out'),
          icon: LucideIcons.logOut,
          danger: true,
          onTap: () async {
            await ref.read(googleAuthServiceProvider).signOut();
            await ref.read(authProvider.notifier).signOut();
          },
        ),
        const SizedBox(height: Gap.sm),
        Center(
          child: Text(
            'XyDesk 1.2.0 · Build 4',
            style: TextStyle(fontSize: 10.5, color: c.textLow),
          ),
        ),
      ],
    );
  }
}

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final lang = ref.watch(langProvider);
    return _SettingsScaffold(
      title: 'Tampilan & bahasa',
      description: 'Atur tampilan XyDesk agar nyaman di perangkat ini.',
      children: [
        const SectionLabel('Tema', top: 0),
        _ThemeSelector(current: settings.themeMode),
        const SectionLabel('Bahasa'),
        ListRow(
          title: context.tr('settings_language'),
          subtitle: 'Bahasa antarmuka aplikasi',
          icon: LucideIcons.languages,
          value: lang.nativeName,
          trailing: _chevron(context),
          onTap: () => _showLanguagePicker(context, ref),
        ),
      ],
    );
  }
}

class BehaviorSettingsPage extends ConsumerWidget {
  const BehaviorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return _SettingsScaffold(
      title: 'Perilaku & aksesibilitas',
      description: 'Respons sentuhan, animasi, dan informasi pengembang.',
      children: [
        _SwitchRow(
          title: context.tr('behavior_vibration'),
          subtitle: 'Umpan balik sentuhan untuk tindakan penting',
          icon: LucideIcons.vibrate,
          value: s.haptics,
          onChanged: notifier.setHaptics,
        ),
        _SwitchRow(
          title: context.tr('behavior_high_refresh'),
          subtitle: context
              .tr('behavior_high_refresh_sub')
              .replaceAll('{hz}', '${DisplayMode.current.round()}'),
          icon: LucideIcons.zap,
          value: s.highRefresh,
          onChanged: notifier.setHighRefresh,
        ),
        _SwitchRow(
          title: context.tr('behavior_reduce_motion'),
          subtitle: context.tr('behavior_reduce_motion_sub'),
          icon: LucideIcons.accessibility,
          value: s.reduceMotion,
          onChanged: notifier.setReduceMotion,
        ),
        const SectionLabel('Pengembang'),
        _SwitchRow(
          title: context.tr('behavior_devlog'),
          subtitle: context.tr('behavior_devlog_sub'),
          icon: LucideIcons.bug,
          value: s.showDevLog,
          onChanged: notifier.setShowDevLog,
        ),
      ],
    );
  }
}

class StreamingSettingsPage extends ConsumerWidget {
  const StreamingSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return _SettingsScaffold(
      title: 'Streaming & kontrol',
      description: 'Kualitas sesi dapat disesuaikan dengan GPU dan jaringan.',
      children: [
        const SectionLabel('Video', top: 0),
        ListRow(
          title: 'Codec video',
          subtitle: 'Pengodean akselerasi perangkat keras',
          icon: LucideIcons.cpu,
          value: _shortCodec(s.codec),
          trailing: _chevron(context),
          onTap: () => _pickCodec(context, ref),
        ),
        ListRow(
          title: 'Resolusi & target FPS',
          subtitle: 'Kualitas video dari perangkat Host',
          icon: LucideIcons.monitor,
          value: s.resolution,
          trailing: _chevron(context),
          onTap: () => _pickResolution(context, ref),
        ),
        ListRow(
          title: 'Bitrate maksimal',
          subtitle: 'Alokasi bandwidth jaringan',
          icon: LucideIcons.gauge,
          value: '${s.bitrateMbps} Mbps',
          trailing: _chevron(context),
          onTap: () => _pickBitrate(context, ref),
        ),
        const SectionLabel('Input & media'),
        _SwitchRow(
          title: 'Mode FPS / trackpad relatif',
          subtitle: 'Kunci kursor di tengah untuk kontrol game FPS',
          icon: LucideIcons.crosshair,
          value: s.relativeMouseMode,
          onChanged: notifier.setRelativeMouseMode,
        ),
        _SwitchRow(
          title: 'Audio PC',
          subtitle:
              'Preferensi tersimpan • '
              '${SessionMediaCapabilities.currentBuild.pcSystemAudio.summary}',
          icon: LucideIcons.volume2,
          value: s.audioEnabled,
          onChanged: notifier.setAudioEnabled,
        ),
        _SwitchRow(
          title: 'Mikrofon HP',
          subtitle:
              'Preferensi tersimpan • '
              '${SessionMediaCapabilities.currentBuild.phoneMicrophone.summary}',
          icon: LucideIcons.mic,
          value: s.micPassthrough,
          onChanged: notifier.setMicPassthrough,
        ),
        _SwitchRow(
          title: 'Sinkronisasi papan klip',
          subtitle: 'Copy-paste teks dan gambar lintas perangkat',
          icon: LucideIcons.clipboard,
          value: s.clipboardSync,
          onChanged: notifier.setClipboardSync,
        ),
      ],
    );
  }
}

class SystemSettingsPage extends StatelessWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Sistem & privasi',
      description: 'Kelola akses sistem dan periksa kondisi aplikasi.',
      children: [
        const SectionLabel('Akses perangkat', top: 0),
        ListRow(
          title: context.tr('settings_permissions'),
          subtitle: 'Tinjau fungsi yang membutuhkan izin sistem',
          icon: LucideIcons.shield,
          trailing: _chevron(context),
          onTap: () => _open(context, const PermissionsPage()),
        ),
        ListRow(
          title: 'Notifikasi pembaruan',
          subtitle: 'Izin dan status subscription OneSignal',
          icon: LucideIcons.bell,
          trailing: _chevron(context),
          onTap: () => _open(context, const NotificationPreferencesPage()),
        ),
        const SectionLabel('Aplikasi'),
        ListRow(
          title: 'Pusat pembaruan',
          subtitle: 'Bandingkan build dengan Release resmi',
          icon: LucideIcons.refreshCw,
          trailing: _chevron(context),
          onTap: () => _open(
            context,
            UpdatePage(details: AppUpdateDetails.updateCenter()),
          ),
        ),
        ListRow(
          title: context.tr('settings_devlog'),
          subtitle: 'Informasi teknis tanpa data kredensial',
          icon: LucideIcons.fileText,
          trailing: _chevron(context),
          onTap: () => DevLog.openPage(context),
        ),
      ],
    );
  }
}

class LegalSettingsPage extends StatelessWidget {
  const LegalSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Legal & tentang',
      description: 'Dokumen penggunaan dan informasi resmi XyDesk.',
      children: [
        const SectionLabel('Legal', top: 0),
        ListRow(
          title: context.tr('legal_terms'),
          icon: LucideIcons.scale,
          trailing: _chevron(context),
          onTap: () => LegalPage.open(context, LegalDoc.terms),
        ),
        ListRow(
          title: context.tr('legal_privacy'),
          icon: LucideIcons.lock,
          trailing: _chevron(context),
          onTap: () => LegalPage.open(context, LegalDoc.privacy),
        ),
        ListRow(
          title: context.tr('legal_licenses'),
          icon: LucideIcons.code,
          trailing: _chevron(context),
          onTap: () => LegalPage.open(context, LegalDoc.licenses),
        ),
        const SectionLabel('Aplikasi'),
        ListRow(
          title: context.tr('settings_about'),
          subtitle: 'Versi, catatan rilis, dan diagnostik',
          icon: LucideIcons.info,
          value: 'v1.2.0',
          trailing: _chevron(context),
          onTap: () => _open(context, const AboutPage()),
        ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(context.tr('settings_about')),
        leading: _backButton(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.xl,
          Gap.screen,
          Gap.h40,
        ),
        children: [
          const Center(child: BrandLockup(size: 76)),
          const SizedBox(height: Gap.md),
          Center(
            child: Text(
              'Versi 1.2.0 · Build 4',
              style: TextStyle(fontSize: 11.5, color: c.textLow),
            ),
          ),
          const SizedBox(height: Gap.xl),
          ListRow(
            title: context.tr('about_release_notes'),
            subtitle: 'Pusat pembaruan dan catatan rilis',
            icon: LucideIcons.list,
            trailing: _chevron(context),
            onTap: () => _open(
              context,
              UpdatePage(details: AppUpdateDetails.updateCenter()),
            ),
          ),
          ListRow(
            title: context.tr('about_check_updates'),
            subtitle: 'Bandingkan dengan Release resmi',
            icon: LucideIcons.refreshCw,
            trailing: _chevron(context),
            onTap: () => _open(
              context,
              UpdatePage(details: AppUpdateDetails.updateCenter()),
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
            trailing: _chevron(context),
            onTap: () => DevLog.openPage(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(title), leading: _backButton(context)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.sm,
          Gap.screen,
          Gap.h40,
        ),
        children: [
          Text(
            description,
            style: TextStyle(fontSize: 12, height: 1.5, color: c.textLow),
          ),
          const SizedBox(height: Gap.xl),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.initial,
    required this.name,
    required this.email,
    required this.badge,
  });

  final String initial;
  final String name;
  final String email;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SurfaceCard(
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.accent, const Color(0xFF8A5CF6)],
              ),
              borderRadius: BorderRadius.circular(R.md),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: c.textHi,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: c.textLow),
                ),
                const SizedBox(height: 8),
                Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: c.accent,
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.value,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: title,
      subtitle: subtitle,
      icon: icon,
      value: value,
      trailing: _chevron(context),
      onTap: onTap,
    );
  }
}

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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Row(
        children: [
          for (final (mode, label, icon) in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(settingsProvider.notifier).setTheme(mode),
                child: AnimatedContainer(
                  duration: D.tab,
                  curve: D.curve,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: current == mode ? c.raised : Colors.transparent,
                    borderRadius: BorderRadius.circular(R.md),
                    boxShadow: current == mode
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 17,
                        color: current == mode ? c.textHi : c.textLow,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: current == mode
                              ? FontWeight.w600
                              : FontWeight.w400,
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
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
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

class _Choice<T> {
  const _Choice(this.value, this.title, this.subtitle);

  final T value;
  final String title;
  final String subtitle;
}

Future<void> _showChoice<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<_Choice<T>> choices,
  required ValueChanged<T> onSelected,
}) {
  final c = context.c;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.overlay,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Gap.screen,
          Gap.sm,
          Gap.screen,
          Gap.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: c.textLow.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.textHi,
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
            for (final choice in choices)
              ListRow(
                title: choice.title,
                subtitle: choice.subtitle,
                trailing: choice.value == current
                    ? Icon(LucideIcons.check, size: 17, color: c.accent)
                    : const SizedBox(width: 17),
                onTap: () {
                  onSelected(choice.value);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(settingsProvider).langCode;
  return _showChoice<String>(
    context,
    title: context.tr('settings_language'),
    current: current,
    choices: [
      for (final language in AppLang.all)
        _Choice(language.code, language.nativeName, language.name),
    ],
    onSelected: ref.read(settingsProvider.notifier).setLang,
  );
}

Future<void> _pickCodec(BuildContext context, WidgetRef ref) {
  final current = ref.read(settingsProvider).codec;
  return _showChoice<String>(
    context,
    title: 'Codec video',
    current: current,
    choices: const [
      _Choice(
        'AV1 (NVENC / AMF GPU)',
        'AV1 (NVENC / AMF GPU)',
        'Latensi rendah dan bandwidth efisien',
      ),
      _Choice(
        'HEVC / H.265 (10-bit)',
        'HEVC / H.265 (10-bit)',
        'Warna visual dan dukungan HDR',
      ),
      _Choice(
        'H.264 (AVC Universal)',
        'H.264 (AVC Universal)',
        'Kompatibilitas GPU paling luas',
      ),
    ],
    onSelected: ref.read(settingsProvider.notifier).setCodec,
  );
}

Future<void> _pickResolution(BuildContext context, WidgetRef ref) {
  final current = ref.read(settingsProvider).resolution;
  return _showChoice<String>(
    context,
    title: 'Resolusi & target FPS',
    current: current,
    choices: const [
      _Choice('720p60 (HD)', '720p60 (HD)', 'Hemat data'),
      _Choice('1080p60 (FHD)', '1080p60 (FHD)', 'Seimbang untuk gaming'),
      _Choice(
        '1440p120 (QHD 2K)',
        '1440p120 (QHD 2K)',
        'Esport latensi rendah',
      ),
      _Choice('4K60 (UHD)', '4K60 (UHD)', 'Kualitas visual tertinggi'),
    ],
    onSelected: ref.read(settingsProvider.notifier).setResolution,
  );
}

Future<void> _pickBitrate(BuildContext context, WidgetRef ref) {
  final current = ref.read(settingsProvider).bitrateMbps;
  return _showChoice<int>(
    context,
    title: 'Bitrate maksimal',
    current: current,
    choices: const [
      _Choice(10, '10 Mbps', 'Hemat bandwidth'),
      _Choice(25, '25 Mbps', 'Kualitas seimbang'),
      _Choice(50, '50 Mbps', 'LAN gigabit'),
    ],
    onSelected: ref.read(settingsProvider.notifier).setBitrateMbps,
  );
}

String _shortCodec(String value) {
  if (value.startsWith('AV1')) return 'AV1';
  if (value.startsWith('HEVC')) return 'H.265';
  return 'H.264';
}

Widget _chevron(BuildContext context) =>
    Icon(LucideIcons.chevronRight, size: 16, color: context.c.textLow);

Widget _backButton(BuildContext context) => IconButton(
  icon: Icon(LucideIcons.arrowLeft, size: 20, color: context.c.textMid),
  onPressed: () => Navigator.pop(context),
);

void _open(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}
