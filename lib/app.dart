import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'core/devlog.dart';
import 'core/l10n_bridge.dart';
import 'core/responsive.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'core/tokens.dart';
import 'features/account/account_page.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/connect/connect_page.dart';
import 'features/devices/history_page.dart';
import 'features/home/home_page.dart';
import 'features/notifications/app_update_details.dart';
import 'features/notifications/notification_preferences_page.dart';
import 'features/notifications/notification_service.dart';
import 'features/notifications/update_page.dart';
import 'features/notifications/update_state.dart';
import 'features/splash/splash_page.dart';
import 'widgets/seamless.dart';

class XyDeskApp extends ConsumerWidget {
  const XyDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final lang = ref.watch(langProvider);

    return MaterialApp(
      title: 'XyDesk',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,

      // Lokalisasi
      locale: Locale(lang.code),
      supportedLocales: [for (final l in AppLang.all) Locale(l.code)],
      localizationsDelegates: [
        LDelegate(lang),
        // Delegate bawaan Material/Cupertino wajib ikut, kalau tidak
        // AppBar dan dialog akan gagal dibangun.
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) {
        NotificationService.instance.flushPendingNavigation();
        // Arah teks mengikuti bahasa (Arab = kanan ke kiri).
        final dir = lang.rtl ? TextDirection.rtl : TextDirection.ltr;
        return Directionality(
          textDirection: dir,
          // Batasi skala teks sistem agar tata letak padat tidak rusak
          // di HP dengan "Ukuran font" sangat besar.
          child: TextScaleGuard(
            child: Stack(
              children: [
                if (child != null) child,
                if (settings.showDevLog)
                  Positioned(
                    right: 8,
                    bottom: MediaQuery.paddingOf(context).bottom + 78,
                    child: const SafeArea(child: DevLogFab()),
                  ),
              ],
            ),
          ),
        );
      },

      // Splash animasi dulu, lalu lanjut ke gate (auth / shell).
      home: const _Boot(),
    );
  }
}

/// Tampilkan SplashPage sejenak, kemudian ganti dengan gate aplikasi.
class _Boot extends ConsumerStatefulWidget {
  const _Boot();

  @override
  ConsumerState<_Boot> createState() => _BootState();
}

class _BootState extends ConsumerState<_Boot> {
  bool _splashDone = false;
  bool _sessionChecked = false;
  late final bool _reduceMotion;

  @override
  void initState() {
    super.initState();
    // Splash Flutter menyelesaikan intro premium setelah frame native. Durasi
    // tetap singkat, tetapi memberi ruang untuk logo besar, blur, dan wordmark
    // berhenti pada keadaan tajam sebelum halaman berikutnya muncul.
    final platformReduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _reduceMotion = ref.read(settingsProvider).reduceMotion || platformReduce;
    // 2450 ms koreografi SplashPage + 250 ms jeda tenang di lockup akhir.
    Future<void>.delayed(Duration(milliseconds: _reduceMotion ? 0 : 2700), () {
      if (!mounted) return;
      _splashDone = true;
      _revealWhenReady();
    });
    _validateRestoredSession();
  }

  Future<void> _validateRestoredSession() async {
    final session = ref.read(authProvider);
    final token = session.token;
    if (!session.isGuest && token != null) {
      try {
        final user = await ref.read(authServiceProvider).me(token);
        await ref
            .read(authProvider.notifier)
            .refreshAuthenticatedProfile(
              email: user.email,
              name: user.name,
              picture: user.picture,
            );
        DevLog.ok('auth', 'Sesi dipastikan oleh server', user.email);
      } on AuthException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 404) {
          // Token kedaluwarsa/tidak dikenali bersifat definitif.
          await ref.read(authProvider.notifier).signOut();
          DevLog.w('auth', 'Sesi tersimpan dibuang', error.code);
        } else {
          // Timeout, jaringan putus, dan 5xx tidak boleh mengeluarkan pengguna.
          DevLog.w('auth', 'Validasi sesi ditunda', error.code);
        }
      } catch (error, stack) {
        // Error platform/jaringan yang tidak terduga juga dianggap sementara.
        DevLog.e('auth', 'Validasi sesi gagal sementara', error, stack);
      }
    }
    _sessionChecked = true;
    _revealWhenReady();
  }

  void _revealWhenReady() {
    if (mounted && _splashDone && _sessionChecked) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ready = _splashDone && _sessionChecked;
    return AnimatedSwitcher(
      duration: _reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: _reduceMotion
          ? (child, _) => child
          : (child, animation) =>
                _BlurFadeTransition(animation: animation, child: child),
      child: ready
          ? const _Gate(key: ValueKey('boot-gate'))
          : const SplashPage(key: ValueKey('boot-splash')),
    );
  }
}

/// Fade lembut dengan blur tipis saat splash berpindah ke aplikasi. Nilai blur
/// kecil menjaga transisi terasa cepat tanpa mengaburkan konten setelah diam.
class _BlurFadeTransition extends StatelessWidget {
  const _BlurFadeTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.985 + (0.015 * value),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 3.5 * (1 - value),
                sigmaY: 3.5 * (1 - value),
              ),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

/// Menentukan layar awal: masuk dulu, atau langsung ke aplikasi.
class _Gate extends ConsumerWidget {
  const _Gate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    return AnimatedSwitcher(
      duration: D.panel,
      child: session.signedIn
          ? const AppShell(key: ValueKey('shell'))
          : const AuthScreen(key: ValueKey('auth')),
    );
  }
}

/// Shell dengan bottom-nav seamless.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerNotifications());
  }

  Future<void> _offerNotifications() async {
    final service = NotificationService.instance;
    if (!mounted || !service.supported) return;
    final store = ref.read(storeProvider);
    if (store.getBool('notification_offer_seen')) return;
    await store.setBool('notification_offer_seen', true);
    await service.refresh();
    if (!mounted || service.active) return;

    final enable = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aktifkan notifikasi pembaruan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'XyDesk hanya mengirim notifikasi rilis dan keamanan penting. '
                'Push tetap diterima saat aplikasi ditutup.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: context.c.textMid,
                ),
              ),
              const SizedBox(height: Gap.xl),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Nanti'),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Aktifkan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (enable == true) await service.enableUpdates();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr('home_devices'),
      context.tr('nav_connect'),
      context.tr('nav_account'),
    ];

    return SeamlessScaffold(
      title: titles[_index],
      actions: _actions(context),
      body: IndexedStack(
        index: _index,
        children: const [HomePage(), ConnectPage(), AccountPage()],
      ),
      bottomNav: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Image.asset(
              'assets/libraryicons/nav_home_inactive.webp',
              width: 26,
              height: 26,
            ),
            selectedIcon: Image.asset(
              'assets/libraryicons/nav_home_active.webp',
              width: 26,
              height: 26,
            ),
            label: context.tr('nav_home'),
          ),
          NavigationDestination(
            icon: Image.asset(
              'assets/libraryicons/nav_connect_inactive.webp',
              width: 26,
              height: 26,
            ),
            selectedIcon: Image.asset(
              'assets/libraryicons/nav_connect_active.webp',
              width: 26,
              height: 26,
            ),
            label: context.tr('nav_connect'),
          ),
          NavigationDestination(
            icon: Image.asset(
              'assets/libraryicons/nav_account_inactive.webp',
              width: 26,
              height: 26,
            ),
            selectedIcon: Image.asset(
              'assets/libraryicons/nav_account_active.webp',
              width: 26,
              height: 26,
            ),
            label: context.tr('nav_account'),
          ),
        ],
      ),
    );
  }

  /// Aksi topbar per tab.
  ///
  /// Sebelumnya ada tombol Cari dan Tambah yang tidak melakukan apa-apa.
  /// Sekarang diganti aksi yang benar-benar berguna: Riwayat di Beranda,
  /// dan tombol Log di Akun.
  List<Widget> _actions(BuildContext context) {
    final c = context.c;
    final update = ref.watch(updateAvailabilityProvider).asData?.value;
    final hasUpdate = update?.updateAvailable ?? false;
    final actions = <Widget>[
      _DotIconButton(
        icon: LucideIcons.bell,
        tooltip: 'Notifikasi',
        showDot: hasUpdate || !NotificationService.instance.active,
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NotificationPreferencesPage(),
            ),
          );
          await NotificationService.instance.refresh();
          if (mounted) setState(() {});
        },
      ),
      _DotIconButton(
        icon: LucideIcons.circleArrowUp,
        tooltip: 'Pusat pembaruan',
        showDot: hasUpdate,
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  UpdatePage(details: AppUpdateDetails.updateCenter()),
            ),
          );
          ref.invalidate(updateAvailabilityProvider);
        },
      ),
    ];

    if (_index == 0) {
      actions.insert(
        0,
        IconButton(
          tooltip: context.tr('connect_history'),
          icon: Icon(LucideIcons.history, size: 19, color: c.textMid),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HistoryPage())),
        ),
      );
    } else if (_index == 2) {
      actions.insert(
        0,
        IconButton(
          tooltip: context.tr('settings_devlog'),
          icon: Icon(LucideIcons.bug, size: 19, color: c.textMid),
          onPressed: () => DevLog.openPage(context),
        ),
      );
    }
    return actions;
  }
}

class _DotIconButton extends StatelessWidget {
  const _DotIconButton({
    required this.icon,
    required this.tooltip,
    required this.showDot,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool showDot;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 19, color: c.textMid),
          if (showDot)
            Positioned(
              top: -3,
              right: -4,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: c.dangerText,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.dangerText.withValues(alpha: 0.32),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
