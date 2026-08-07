import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              icon: const Icon(Icons.search_rounded, size: 19),
              visualDensity: VisualDensity.compact),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded, size: 20),
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
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
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
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.link_outlined),
              selectedIcon: Icon(Icons.link_rounded),
              label: 'Connect'),
          NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: 'Control'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
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
            icon: Icons.sports_esports_outlined,
            trailing:
                Icon(Icons.chevron_right_rounded, size: 16, color: c.textLow)),
        ListRow(
            title: 'Photoshop',
            subtitle: '12 elemen · ganti otomatis',
            icon: Icons.tune_rounded,
            trailing:
                Icon(Icons.chevron_right_rounded, size: 16, color: c.textLow)),
        ListRow(
            title: 'Desktop umum',
            subtitle: '6 elemen · bawaan',
            icon: Icons.mouse_outlined,
            trailing:
                Icon(Icons.chevron_right_rounded, size: 16, color: c.textLow)),
      ],
    );
  }
}
