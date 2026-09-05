import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_version.dart';
import '../../core/cloudinary_upload.dart';
import '../../core/devlog.dart';
import '../../core/l10n_bridge.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/seamless.dart';
import '../auth/auth_service.dart';
import '../auth/legal_page.dart';
import '../notifications/app_update_details.dart';
import '../notifications/notification_preferences_page.dart';
import '../notifications/update_page.dart';
import '../session/media_capabilities.dart';
import '../session/control_mapping_page.dart';
import 'permissions_page.dart';
import 'subscription_page.dart';
import '../../core/display_control.dart';
import '../../core/haptics.dart';

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
        InkWell(
          onTap: user.isGuest ? null : () => _editProfile(context, ref, user),
          borderRadius: BorderRadius.circular(R.lg),
          child: _ProfileHero(
            initial: user.initial,
            name: user.isGuest
                ? context.tr('account_guest')
                : (user.name ?? context.tr('account_user')),
            email: user.email ?? context.tr('account_local_data'),
            badge: user.isGuest
                ? 'MODE TAMU'
                : 'AKUN AKTIF · ketuk untuk ganti nama & foto',
            pictureUrl: user.picture,
          ),
        ),
        const SectionLabel('Preferensi'),
        _CategoryRow(
          title: 'Tampilan & bahasa',
          subtitle: 'Bahasa tampilan aplikasi',
          icon: LucideIcons.palette,
          onTap: () => _open(context, const AppearanceSettingsPage()),
        ),
        _CategoryRow(
          title: 'Perilaku & aksesibilitas',
          subtitle: 'Getaran, kehalusan layar, dan animasi',
          icon: LucideIcons.slidersHorizontal,
          onTap: () => _open(context, const BehaviorSettingsPage()),
        ),
        _CategoryRow(
          title: 'Streaming & kontrol',
          subtitle: 'Kualitas gambar, suara, dan cara mengontrol',
          icon: LucideIcons.monitorCog,
          onTap: () => _open(context, const StreamingSettingsPage()),
        ),
        _CategoryRow(
          title: 'Notifikasi',
          subtitle: 'Atur pemberitahuan dari XyDesk',
          icon: LucideIcons.bell,
          onTap: () => _open(context, const NotificationPreferencesPage()),
        ),
        _CategoryRow(
          title: 'Sistem & privasi',
          subtitle: 'Izin aplikasi, pembaruan, dan catatan teknis',
          icon: LucideIcons.shieldCheck,
          onTap: () => _open(context, const SystemSettingsPage()),
        ),
        const SectionLabel('Akun & informasi'),
        _CategoryRow(
          title: 'Langganan',
          subtitle: 'Status keanggotaan & riwayat sewa',
          icon: LucideIcons.crown,
          value: 'Free',
          onTap: () => _open(context, const SubscriptionPage()),
        ),
        _CategoryRow(
          title: 'Control Mapping',
          subtitle: 'Keyboard, joystick, mouse — mapping & profil kontrol',
          icon: LucideIcons.gamepad2,
          onTap: () => _open(context, const ControlMappingPage()),
        ),
        _CategoryRow(
          title: 'Legal & tentang XyDesk',
          subtitle: 'Ketentuan, privasi, dan lisensi',
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
        if (!user.isGuest && user.token != null)
          ListRow(
            title: 'Hapus akun',
            subtitle: 'Akun dan semua datanya hilang, tidak bisa dibalikkan',
            icon: LucideIcons.trash2,
            danger: true,
            onTap: () => _deleteAccount(context, ref),
          ),
        const SizedBox(height: Gap.sm),
        Center(
          child: Text(
            AppVersion.labeled,
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
    final lang = ref.watch(langProvider);
    return _SettingsScaffold(
      title: 'Tampilan & bahasa',
      description:
          'XyDesk cuma punya satu tampilan terang. Mode gelap memang tidak '
          'disediakan — bukan belum jadi.',
      children: [
        const SectionLabel('Bahasa', top: 0),
        ListRow(
          title: context.tr('settings_language'),
          subtitle: 'Ganti bahasa tampilan',
          icon: LucideIcons.languages,
          value: lang.nativeName,
          trailing: _chevron(context),
          onTap: () => _showLanguagePicker(context, ref),
        ),
      ],
    );
  }
}

/// Menjelaskan refresh rate memakai angka nyata dari panel, bukan janji.
String _refreshRateSubtitle() {
  final now = '${DisplayControl.current.round()} Hz';
  if (!DisplayControl.canSwitch) return 'Layar berjalan di $now';
  final list = DisplayControl.supported
      .map((e) => '${e.round()}')
      .join(' dan ');
  return 'Sekarang $now · layar HP ini bisa $list Hz';
}

class BehaviorSettingsPage extends ConsumerWidget {
  const BehaviorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return _SettingsScaffold(
      title: 'Perilaku & aksesibilitas',
      description: 'Atur getaran, animasi, dan catatan teknis.',
      children: [
        _SwitchRow(
          title: context.tr('behavior_vibration'),
          subtitle: 'HP bergetar tiap kali kamu menekan tombol',
          icon: LucideIcons.vibrate,
          value: s.haptics,
          onChanged: notifier.setHaptics,
        ),
        _SwitchRow(
          title: context.tr('behavior_high_refresh'),
          subtitle: _refreshRateSubtitle(),
          icon: LucideIcons.zap,
          value: s.highRefresh,
          onChanged: notifier.setHighRefresh,
          // Perangkat 60 Hz tidak punya apa pun untuk dipilih. Menampilkan
          // sakelar aktif di situ adalah kebohongan kecil yang gratis
          // dihindari.
          unavailable: DisplayControl.canSwitch
              ? null
              : 'Layar HP ini cuma ${DisplayControl.current.round()} Hz, '
                    'jadi tidak ada yang bisa diubah',
        ),
        _SwitchRow(
          title: 'Layar tetap menyala saat sesi',
          subtitle:
              'Layar tidak akan mati selama kamu tersambung ke PC. '
              'Matikan kalau mau hemat baterai.',
          icon: LucideIcons.sun,
          value: s.keepScreenOn,
          onChanged: notifier.setKeepScreenOn,
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
          subtitle: 'Cara PC memproses gambar sebelum dikirim',
          icon: LucideIcons.cpu,
          value: _shortCodec(s.codec),
          trailing: _chevron(context),
          onTap: () => _pickCodec(context, ref),
        ),
        ListRow(
          title: 'Resolusi & target FPS',
          subtitle: 'Makin tinggi makin jernih, tapi makin berat',
          icon: LucideIcons.monitor,
          value: s.resolution,
          trailing: _chevron(context),
          onTap: () => _pickResolution(context, ref),
        ),
        ListRow(
          title: 'Bitrate maksimal',
          subtitle: 'Batas pemakaian internet selama sesi',
          icon: LucideIcons.gauge,
          value: '${s.bitrateMbps} Mbps',
          trailing: _chevron(context),
          onTap: () => _pickBitrate(context, ref),
        ),
        const SectionLabel('Input & media'),
        _SwitchRow(
          title: 'Mode FPS / trackpad relatif',
          subtitle: 'Buat main game FPS — kursor dikunci di tengah layar',
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
          subtitle:
              'Salin di HP, lalu tekan Ctrl+V di PC. Arah sebaliknya lewat '
              'tombol ambil di layar sesi.',
          icon: LucideIcons.clipboard,
          value: s.clipboardSync,
          onChanged: notifier.setClipboardSync,
          // Protokol host belum punya kanal papan klip sama sekali — bukan
          // "belum diuji", memang belum ada kodenya. Sakelar ini sebelumnya
          // menyala secara bawaan dan tidak pernah mengirim apa pun.
          unavailable:
              'Belum bisa dipakai. Aplikasi XyDesk di PC belum '
              'mendukung fitur ini.',
        ),
      ],
    );
  }
}

class SystemSettingsPage extends ConsumerWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsScaffold(
      title: 'Sistem & privasi',
      description: 'Izin aplikasi, pembaruan, dan catatan teknis.',
      children: [
        const SectionLabel('Akses perangkat', top: 0),
        ListRow(
          title: context.tr('settings_permissions'),
          subtitle: 'Lihat izin yang dipakai XyDesk dan alasannya',
          icon: LucideIcons.shield,
          trailing: _chevron(context),
          onTap: () => _open(context, const PermissionsPage()),
        ),
        const SectionLabel('Aplikasi'),
        ListRow(
          title: 'Pusat pembaruan',
          subtitle: 'Cek dan pasang versi terbaru',
          icon: LucideIcons.refreshCw,
          trailing: _chevron(context),
          onTap: () => _open(
            context,
            UpdatePage(details: AppUpdateDetails.updateCenter()),
          ),
        ),
        ListRow(
          title: context.tr('settings_devlog'),
          subtitle: 'Catatan teknis untuk melaporkan masalah',
          icon: LucideIcons.fileText,
          trailing: _chevron(context),
          onTap: () => DevLog.openPage(context),
        ),
        const SectionLabel('Pemulihan'),
        ListRow(
          title: 'Reset pengaturan ke bawaan',
          subtitle:
              'Semua pengaturan kembali seperti baru dipasang. Akun, bahasa, '
              'dan daftar PC tidak ikut hilang.',
          icon: LucideIcons.rotateCcw,
          trailing: _chevron(context),
          onTap: () => _confirmReset(context, ref),
        ),
      ],
    );
  }
}

/// Reset selalu lewat konfirmasi: pengaturan streaming yang sudah dicocokkan
/// dengan jaringan pengguna tidak sepele untuk disusun ulang.
Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Reset pengaturan?', style: TextStyle(fontSize: 16)),
      content: const Text(
        'Kualitas gambar, suara, dan cara mengontrol kembali ke setelan '
        'awal.\n\n'
        'Akun, bahasa, dan daftar PC kamu tidak berubah.',
        style: TextStyle(fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Reset'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(settingsProvider.notifier).resetToDefaults();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Pengaturan dikembalikan ke bawaan')),
  );
}

class LegalSettingsPage extends StatelessWidget {
  const LegalSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Legal & tentang',
      description: 'Ketentuan pakai, privasi, dan lisensi.',
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
          subtitle: 'Versi aplikasi dan apa saja yang berubah',
          icon: LucideIcons.info,
          value: AppVersion.short,
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
              AppVersion.versiFull,
              style: TextStyle(fontSize: 11.5, color: c.textLow),
            ),
          ),
          const SizedBox(height: Gap.xl),
          const SectionLabel('Diagnostik'),
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

Future<void> _editName(
  BuildContext context,
  WidgetRef ref,
  UserSession user,
) async {
  final controller = TextEditingController(text: user.name ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ganti nama tampilan', style: TextStyle(fontSize: 16)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        decoration: const InputDecoration(hintText: 'Nama baru'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  if (name == null || name.length < 2) return;
  final token = user.token;
  if (token == null) return;
  try {
    final updated = await ref.read(authServiceProvider).updateName(token, name);
    await ref
        .read(authProvider.notifier)
        .refreshAuthenticatedProfile(
          email: updated.email,
          name: updated.name,
          picture: updated.picture,
        );
  } on AuthException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// Menu edit profil: ganti nama (via [_editName]) dan ganti foto (via
/// [_editAvatar]). Dipisah supaya tiap aksi jelas dan tidak berubah jadi
/// satu dialog yang menumpuk.
Future<void> _editProfile(
  BuildContext context,
  WidgetRef ref,
  UserSession user,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.c.overlay,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EditorHeader(
              title: 'Edit profil',
              onClose: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: Gap.md),
            ListTile(
              leading: Icon(LucideIcons.user, size: 18, color: ctx.c.textMid),
              title: Text(
                'Ganti nama',
                style: TextStyle(fontSize: 14, color: ctx.c.textHi),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () async {
                Navigator.pop(ctx);
                await _editName(context, ref, user);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.camera, size: 18, color: ctx.c.textMid),
              title: Text(
                'Ganti foto profil',
                style: TextStyle(fontSize: 14, color: ctx.c.textHi),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () async {
                Navigator.pop(ctx);
                await _editAvatar(context, ref);
              },
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    ),
  );
}

/// Pilih foto profil: dari preset DiceBear atau masukkan URL gambar sendiri.
Future<void> _editAvatar(BuildContext context, WidgetRef ref) async {
  final store = ref.read(storeProvider);
  final current = loadAvatar(store);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.c.overlay,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EditorHeader(
              title: 'Ganti foto profil',
              onClose: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Pilih dari preset',
              style: TextStyle(fontSize: 12.5, color: ctx.c.textMid),
            ),
            const SizedBox(height: Gap.sm),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final seed in profileAvatarSeeds)
                    Padding(
                      padding: const EdgeInsets.only(right: Gap.md),
                      child: GestureDetector(
                        onTap: () async {
                          await saveAvatar(store, 'preset:$seed');
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Column(
                          children: [
                            ProfileAvatar(
                              name: seed,
                              initial: seed[0],
                              size: 62,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              seed,
                              style: TextStyle(
                                fontSize: 10,
                                color: ctx.c.textLow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            ListTile(
              leading: Icon(
                LucideIcons.imageUp,
                size: 18,
                color: ctx.c.textMid,
              ),
              title: Text(
                'Unggah dari galeri',
                style: TextStyle(fontSize: 14, color: ctx.c.textHi),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () async {
                Navigator.pop(ctx);
                await _uploadAvatar(context, ref);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.link, size: 18, color: ctx.c.textMid),
              title: Text(
                'Pakai URL gambar sendiri',
                style: TextStyle(fontSize: 14, color: ctx.c.textHi),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () async {
                final url = await _askUrl(ctx);
                if (url != null && url.isNotEmpty) {
                  await saveAvatar(store, 'url:${Uri.encodeComponent(url)}');
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
            if (current != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: ctx.c.textLow,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () async {
                  await saveAvatar(store, '');
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text(
                  'Kembalikan ke inisial',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _askUrl(BuildContext context) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('URL gambar', style: TextStyle(fontSize: 16)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'https://…'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

/// Pilih foto dari galeri, unggah ke Cloudinary (unsigned preset), lalu
/// simpan URL-nya sebagai avatar. Kalau preset belum dikonfigurasi, tampilkan
/// pesan yang jelas (bukan gagal senyap).
Future<void> _uploadAvatar(BuildContext context, WidgetRef ref) async {
  final store = ref.read(storeProvider);

  // Tangkap messenger SEBELUM `await` apa pun, supaya tidak memakai
  // `BuildContext` di seberang async gap (bukan hal yang bisa aman).
  final messenger = ScaffoldMessenger.of(context);
  void toast(String message) =>
      messenger.showSnackBar(SnackBar(content: Text(message)));

  // Kalau preset belum diisi operator, jangan buka galeri — beri tahu dulu.
  if (cloudinaryUploadPreset.isEmpty) {
    toast('Unggah foto belum aktif (preset Cloudinary belum diisi).');
    return;
  }

  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return; // dibatalkan pengguna

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      toast('Gambar tidak terbaca. Coba pilih yang lain.');
      return;
    }

    toast('Mengunggah foto…');

    final url = await uploadProfileImage(bytes, filename: picked.name);

    await saveAvatar(store, 'url:${Uri.encodeComponent(url)}');
    messenger.clearSnackBars();
    toast('Foto profil terpasang.');
  } on CloudinaryUploadException catch (e) {
    toast(e.message);
  } catch (e) {
    toast('Gagal memilih/unggah foto: $e');
  }
}

/// Judul modal + tombol tutup, dipakai oleh lembar edit profil & avatar.
class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: onClose,
        ),
      ],
    );
  }
}

Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus akun?', style: TextStyle(fontSize: 16)),
      content: const Text(
        'Akun dan data profil di server dihapus permanen. Tindakan ini '
        'tidak dapat dibatalkan.',
        style: TextStyle(fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Hapus permanen',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final token = ref.read(authProvider).token;
  if (token == null) return;
  try {
    await ref.read(authServiceProvider).deleteAccount(token);
    await ref.read(googleAuthServiceProvider).signOut();
    await ref.read(authProvider.notifier).signOut();
  } on AuthException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.initial,
    required this.name,
    required this.email,
    required this.badge,
    this.pictureUrl,
  });

  final String initial;
  final String name;
  final String email;
  final String badge;
  final String? pictureUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SurfaceCard(
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        children: [
          ProfileAvatar(
            name: name,
            initial: initial,
            size: 52,
            bordered: false,
            pictureUrl: pictureUrl,
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.unavailable,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Bila diisi, sakelar dinonaktifkan dan alasannya ditampilkan.
  ///
  /// Sakelar yang bisa digeser, mengingat pilihanmu, dan tidak melakukan
  /// apa-apa lebih buruk daripada sakelar yang jujur mengaku belum siap.
  final String? unavailable;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final off = unavailable != null;
    return Opacity(
      opacity: off ? 0.55 : 1,
      child: Padding(
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
                  if (subtitle != null || off) ...[
                    const SizedBox(height: 3),
                    Text(
                      unavailable ?? subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: off ? c.warningText : c.textLow,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                value: off ? false : value,
                onChanged: off
                    ? null
                    : (v) {
                        AppHaptics.impact();
                        onChanged(v);
                      },
              ),
            ),
          ],
        ),
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
