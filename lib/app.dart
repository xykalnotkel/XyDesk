import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/devlog.dart';
import 'core/theme.dart';
import 'core/tokens.dart';
import 'features/account/account_page.dart';
import 'features/connect/connect_page.dart';
import 'features/home/home_page.dart';
import 'widgets/seamless.dart';

final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.dark);

class XyDeskApp extends ConsumerWidget {
  const XyDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'XyDesk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      // builder membungkus SELURUH rute, jadi tombol DevLog tetap ada
      // saat masuk SessionPage sekalipun.
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          Positioned(
            right: 8,
            bottom: MediaQuery.paddingOf(context).bottom + 78,
            child: const SafeArea(child: DevLogFab()),
          ),
        ],
      ),
      home: const AppShell(),
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

  static const _titles = ['Perangkat', 'Connect', 'Kontrol', 'Akun'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const ConnectPage(),
      const _ControlPlaceholder(),
      const AccountPage(),
    ];

    return SeamlessScaffold(
      title: _titles[_index],
      actions: [
        if (_index == 0) ...[
          IconButton(
              onPressed: () {},
              icon: const Icon(LucideIcons.search, size: 19),
              visualDensity: VisualDensity.compact),
          IconButton(
              onPressed: () {},
              icon: const Icon(LucideIcons.plus, size: 20),
              visualDensity: VisualDensity.compact),
        ],
        if (_index == 3)
          IconButton(
            tooltip: 'Ganti tema',
            onPressed: () {
              final m = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  m == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? LucideIcons.sun
                  : LucideIcons.moon,
              size: 19,
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
      body: IndexedStack(index: _index, children: pages),
      bottomNav: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(LucideIcons.home),
              selectedIcon: Icon(LucideIcons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(LucideIcons.link2),
              selectedIcon: Icon(LucideIcons.link2),
              label: 'Connect'),
          NavigationDestination(
              icon: Icon(LucideIcons.slidersHorizontal),
              selectedIcon: Icon(LucideIcons.slidersHorizontal),
              label: 'Control'),
          NavigationDestination(
              icon: Icon(LucideIcons.user),
              selectedIcon: Icon(LucideIcons.user),
              label: 'Akun'),
        ],
      ),
    );
  }
}

class _ControlPlaceholder extends StatelessWidget {
  const _ControlPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 56,
        bottom: 110,
      ),
      children: [
        const SectionLabel('Profil saya', top: 0),
        ListRow(
            title: 'Valorant',
            subtitle: '18 elemen · ganti otomatis',
            icon: LucideIcons.gamepad2,
            trailing:
                Icon(LucideIcons.chevronRight, size: 16, color: c.textLow)),
        ListRow(
            title: 'Photoshop',
            subtitle: '12 elemen · ganti otomatis',
            icon: LucideIcons.slidersHorizontal,
            trailing:
                Icon(LucideIcons.chevronRight, size: 16, color: c.textLow)),
        ListRow(
            title: 'Desktop umum',
            subtitle: '6 elemen · bawaan',
            icon: LucideIcons.mouse,
            trailing:
                Icon(LucideIcons.chevronRight, size: 16, color: c.textLow)),
      ],
    );
  }
}
