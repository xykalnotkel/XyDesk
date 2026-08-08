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
import 'features/connect/connect_page.dart';
import 'features/control/control_page.dart';
import 'features/devices/history_page.dart';
import 'features/home/home_page.dart';
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
  const _Boot({super.key});

  @override
  ConsumerState<_Boot> createState() => _BootState();
}

class _BootState extends ConsumerState<_Boot> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    // "Kurangi animasi" aktif -> langsung ke app, tanpa splash beriak.
    final reduce = ref.read(settingsProvider).reduceMotion;
    Future.delayed(Duration(milliseconds: reduce ? 0 : 1900), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _revealed ? const _Gate() : const SplashPage();
  }
}

/// Menentukan layar awal: masuk dulu, atau langsung ke aplikasi.
class _Gate extends ConsumerWidget {
  const _Gate();

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
  Widget build(BuildContext context) {
    final titles = [
      context.tr('home_devices'),
      context.tr('nav_connect'),
      context.tr('nav_control'),
      context.tr('nav_account'),
    ];

    return SeamlessScaffold(
      title: titles[_index],
      actions: _actions(context),
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          ConnectPage(),
          ControlPage(),
          AccountPage(),
        ],
      ),
      bottomNav: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Image.asset('assets/libraryicons/nav_home_inactive.png',
                width: 26, height: 26),
            selectedIcon: Image.asset('assets/libraryicons/nav_home_active.png',
                width: 26, height: 26),
            label: context.tr('nav_home'),
          ),
          NavigationDestination(
            icon: Image.asset('assets/libraryicons/nav_connect_inactive.png',
                width: 26, height: 26),
            selectedIcon: Image.asset(
                'assets/libraryicons/nav_connect_active.png',
                width: 26,
                height: 26),
            label: context.tr('nav_connect'),
          ),
          NavigationDestination(
            icon: Image.asset('assets/libraryicons/nav_control_inactive.png',
                width: 26, height: 26),
            selectedIcon: Image.asset(
                'assets/libraryicons/nav_control_active.png',
                width: 26,
                height: 26),
            label: context.tr('nav_control'),
          ),
          NavigationDestination(
            icon: Image.asset('assets/libraryicons/nav_account_inactive.png',
                width: 26, height: 26),
            selectedIcon: Image.asset(
                'assets/libraryicons/nav_account_active.png',
                width: 26,
                height: 26),
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
    switch (_index) {
      case 0:
        return [
          IconButton(
            tooltip: context.tr('connect_history'),
            icon: Icon(LucideIcons.history, size: 19, color: c.textMid),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
        ];
      case 3:
        return [
          IconButton(
            tooltip: context.tr('settings_devlog'),
            icon: Icon(LucideIcons.bug, size: 19, color: c.textMid),
            onPressed: () => DevLog.openPage(context),
          ),
        ];
      default:
        return const [];
    }
  }
}
