import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n_bridge.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/hud_glyphs.dart';
import '../../widgets/seamless.dart';

/// Profil pemetaan kontrol yang tersimpan.
class ControlProfile {
  const ControlProfile({
    required this.id,
    required this.name,
    required this.elements,
    this.autoSwitch = false,
    this.gameHint,
  });

  final String id;
  final String name;
  final int elements;
  final bool autoSwitch;
  final String? gameHint;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'el': elements,
        'auto': autoSwitch,
        'hint': gameHint,
      };

  factory ControlProfile.fromJson(Map<String, dynamic> j) => ControlProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        elements: j['el'] as int? ?? 0,
        autoSwitch: j['auto'] as bool? ?? false,
        gameHint: j['hint'] as String?,
      );
}

class ProfileRepo extends StateNotifier<List<ControlProfile>> {
  ProfileRepo(this._s) : super(const []) {
    final raw = _s.getList(_key);
    state = raw.isEmpty ? _seed : raw.map(ControlProfile.fromJson).toList();
    if (raw.isEmpty) _persist();
  }

  final Store _s;
  static const _key = 'profiles';

  static const _seed = [
    ControlProfile(
        id: 'p1',
        name: 'Valorant',
        elements: 18,
        autoSwitch: true,
        gameHint: 'VALORANT.exe'),
    ControlProfile(
        id: 'p2',
        name: 'Photoshop',
        elements: 12,
        autoSwitch: true,
        gameHint: 'Photoshop.exe'),
    ControlProfile(id: 'p3', name: 'Desktop umum', elements: 6),
  ];

  Future<void> _persist() =>
      _s.setList(_key, state.map((p) => p.toJson()).toList());

  Future<void> add(ControlProfile p) async {
    state = [...state, p];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _persist();
  }
}

final profileRepoProvider =
    StateNotifierProvider<ProfileRepo, List<ControlProfile>>((ref) {
  return ProfileRepo(ref.watch(storeProvider));
});

/// Halaman Kontrol: daftar profil + galeri elemen HUD.
class ControlPage extends ConsumerWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final profiles = ref.watch(profileRepoProvider);
    final topPad = MediaQuery.paddingOf(context).top + 56;

    return ListView(
      padding: EdgeInsets.only(top: topPad, bottom: 110),
      children: [
        const SectionLabel('Profil saya', top: 0),
        for (final p in profiles)
          ListRow(
            title: p.name,
            subtitle: '${p.elements} elemen'
                '${p.autoSwitch ? " · ganti otomatis" : ""}',
            icon: LucideIcons.gamepad2,
            trailing:
                Icon(LucideIcons.chevronRight, size: 16, color: c.textLow),
            onTap: () => _openEditor(context, p),
          ),
        const SizedBox(height: Gap.sm),
        OutlinedButtonLike(
          icon: LucideIcons.plus,
          label: 'Buat profil baru',
          onTap: () => _newProfile(context, ref),
        ),
        const SectionLabel('Elemen yang tersedia'),
        Text(
          'Semua elemen ini bisa ditaruh di layar saat sesi berjalan.',
          style: TextStyle(fontSize: 12, color: c.textLow, height: 1.5),
        ),
        const SizedBox(height: Gap.md),
        const _GlyphGallery(),
      ],
    );
  }

  void _openEditor(BuildContext context, ControlProfile p) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editor "${p.name}" — segera hadir')),
    );
  }

  void _newProfile(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profil baru', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama profil'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.tr('cancel'))),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await ref.read(profileRepoProvider.notifier).add(
                    ControlProfile(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      elements: 0,
                    ),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(ctx.tr('save')),
          ),
        ],
      ),
    );
  }
}

/// Galeri seluruh glyph HUD — memperlihatkan apa saja yang bisa dipakai.
class _GlyphGallery extends StatelessWidget {
  const _GlyphGallery();

  static const _items = <(HudGlyph, String)>[
    (HudGlyph.mouseLeft, 'Klik kiri'),
    (HudGlyph.mouseRight, 'Klik kanan'),
    (HudGlyph.mouseMiddle, 'Klik tengah'),
    (HudGlyph.scrollUp, 'Gulir naik'),
    (HudGlyph.scrollDown, 'Gulir turun'),
    (HudGlyph.scrollBoth, 'Gulir bebas'),
    (HudGlyph.switchHold, 'Tahan klik'),
    (HudGlyph.dropdownUpDown, 'Pilih ▲▼'),
    (HudGlyph.arrowUp, 'Atas'),
    (HudGlyph.arrowDown, 'Bawah'),
    (HudGlyph.arrowLeft, 'Kiri'),
    (HudGlyph.arrowRight, 'Kanan'),
    (HudGlyph.dpad, 'D-Pad'),
    (HudGlyph.stick, 'Stik analog'),
    (HudGlyph.wasd, 'Tracker WASD'),
    (HudGlyph.trackpad, 'Trackpad'),
    (HudGlyph.keypad, 'Keypad'),
    (HudGlyph.keycap, 'Tombol'),
    (HudGlyph.combo4, 'Kombinasi'),
    (HudGlyph.ptt, 'PTT mik'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 96,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.92,
      ),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final (glyph, label) = _items[i];
        return Container(
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(R.md),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HudIcon(glyph, size: 24, color: c.textHi, strokeWidth: 1.5),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(fontSize: 9, height: 1.2, color: c.textLow),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
