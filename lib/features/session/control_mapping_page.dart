import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tokens.dart';
import 'control_mapping.dart';

/// Halaman pengaturan control mapping.
class ControlMappingPage extends ConsumerStatefulWidget {
  const ControlMappingPage({super.key});

  @override
  ConsumerState<ControlMappingPage> createState() => _ControlMappingPageState();
}

class _ControlMappingPageState extends ConsumerState<ControlMappingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _editingProfileId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(controlMappingManagerProvider);
    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: c.textHi),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Control Mapping',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: c.textHi,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: c.accent),
            onPressed: () => _showAddProfileDialog(),
            tooltip: 'Profil baru',
          ),
          IconButton(
            icon: Icon(LucideIcons.rotateCcw, color: c.textMid),
            onPressed: () => _showResetDialog(),
            tooltip: 'Reset ke default',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: c.accent,
          labelColor: c.accent,
          unselectedLabelColor: c.textMid,
          tabs: const [
            Tab(text: 'Daftar Mapping'),
            Tab(text: 'Preview'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MappingListView(
            profiles: profiles,
            onEdit: (profile) => _editProfile(profile),
            onDelete: (profileId) => _confirmDelete(profileId),
            onSetDefault: (profileId) => _setDefault(profileId),
          ),
          _MappingPreviewTab(profiles: profiles),
        ],
      ),
    );
  }

  void _editProfile(ControlProfile profile) {
    setState(() => _editingProfileId = profile.id);
    _tabController.animateTo(1);
  }

  void _confirmDelete(String profileId) {
    final c = context.c;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.overlay,
        title: Text('Hapus profil?', style: TextStyle(color: c.textHi)),
        content: Text(
          'Profil ini akan dihapus permanen.',
          style: TextStyle(color: c.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: c.textMid)),
          ),
          FilledButton(
            onPressed: () {
              ref.read(controlMappingManagerProvider.notifier).deleteProfile(
                profileId,
              );
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: c.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _setDefault(String profileId) {
    ref.read(controlMappingManagerProvider.notifier).setDefault(profileId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil default diperbarui'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAddProfileDialog() {
    final c = context.c;
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.overlay,
        title: Text('Profil baru', style: TextStyle(color: c.textHi)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: c.textHi),
          decoration: InputDecoration(
            hintText: 'Nama profil',
            hintStyle: TextStyle(color: c.textLow),
            filled: true,
            fillColor: c.input,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: c.textMid)),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final profile = ControlProfile(
                  id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  mappings: [],
                  createdAt: DateTime.now(),
                );
                ref
                    .read(controlMappingManagerProvider.notifier)
                    .addProfile(profile);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    final c = context.c;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.overlay,
        title: Text('Reset mapping?', style: TextStyle(color: c.textHi)),
        content: Text(
          'Semua profil custom akan dihapus dan diganti dengan profil '
          'default (Gaming & Desktop).',
          style: TextStyle(color: c.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: c.textMid)),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(controlMappingManagerProvider.notifier)
                  .resetToDefaults();
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _MappingListView extends StatelessWidget {
  const _MappingListView({
    required this.profiles,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final List<ControlProfile> profiles;
  final ValueChanged<ControlProfile> onEdit;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onSetDefault;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.gamepad2, size: 48, color: c.textLow),
            const SizedBox(height: 12),
            Text(
              'Belum ada profil',
              style: TextStyle(fontSize: 15, color: c.textMid),
            ),
            const SizedBox(height: 4),
            Text(
              'Ketuk + untuk membuat profil baru',
              style: TextStyle(fontSize: 12, color: c.textLow),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return _ProfileCard(
          profile: profile,
          onEdit: () => onEdit(profile),
          onDelete: () => onDelete(profile.id),
          onSetDefault: () => onSetDefault(profile.id),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final ControlProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(
          color: profile.isDefault
              ? c.accent.withValues(alpha: 0.5)
              : c.textLow.withValues(alpha: 0.12),
          width: profile.isDefault ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: profile.isDefault
                    ? c.accentSoft
                    : c.textLow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Icon(
                _profileIcon(profile),
                color: profile.isDefault ? c.accent : c.textMid,
                size: 22,
              ),
            ),
            title: Row(
              children: [
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                  ),
                ),
                if (profile.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DEFAULT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: c.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${profile.mappings.length} mapping'
                '${profile.createdAt != null ? " • ${_fmtDate(profile.createdAt!)}" : ""}',
                style: TextStyle(fontSize: 12, color: c.textLow),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!profile.isDefault)
                  IconButton(
                    icon: Icon(
                      LucideIcons.star,
                      size: 18,
                      color: c.textLow,
                    ),
                    onPressed: onSetDefault,
                    tooltip: 'Jadikan default',
                  ),
                IconButton(
                  icon: Icon(LucideIcons.pencil, size: 18, color: c.accent),
                  onPressed: onEdit,
                  tooltip: 'Edit mapping',
                ),
                if (!profile.isDefault)
                  IconButton(
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 18,
                      color: c.danger,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Hapus profil',
                  ),
              ],
            ),
          ),
          if (profile.mappings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: profile.mappings.take(6).map((m) {
                  return _MappingChip(mapping: m);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  IconData _profileIcon(ControlProfile profile) {
    final name = profile.name.toLowerCase();
    if (name.contains('gaming') || name.contains('game')) {
      return LucideIcons.gamepad2;
    }
    if (name.contains('desktop') || name.contains('kerja')) {
      return LucideIcons.monitor;
    }
    return LucideIcons.layoutGrid;
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}h lalu';
    if (diff.inHours > 0) return '${diff.inHours}j lalu';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m lalu';
    return 'Baru saja';
  }
}

class _MappingChip extends StatelessWidget {
  const _MappingChip({required this.mapping});

  final ControlMapping mapping;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.textLow.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _inputIcon(mapping.inputType),
            size: 12,
            color: c.textLow,
          ),
          const SizedBox(width: 4),
          Text(
            '${mapping.inputKey}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c.textHi,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '→ ${mapping.name}',
            style: TextStyle(fontSize: 10, color: c.textMid),
          ),
        ],
      ),
    );
  }

  IconData _inputIcon(InputType type) {
    return switch (type) {
      InputType.keyboard => LucideIcons.keyboard,
      InputType.mouse => LucideIcons.mouse,
      InputType.joystick => LucideIcons.gamepad2,
      InputType.touch => LucideIcons.hand,
    };
  }
}

class _MappingPreviewTab extends ConsumerStatefulWidget {
  const _MappingPreviewTab({required this.profiles});

  final List<ControlProfile> profiles;

  @override
  ConsumerState<_MappingPreviewTab> createState() => _MappingPreviewTabState();
}

class _MappingPreviewTabState extends ConsumerState<_MappingPreviewTab> {
  ControlProfile? _selectedProfile;

  @override
  void initState() {
    super.initState();
    _selectedProfile = widget.profiles.isNotEmpty ? widget.profiles.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final profiles = ref.watch(controlMappingManagerProvider);
    final profile = _selectedProfile ??
        (profiles.isNotEmpty ? profiles.first : null);

    if (profile == null) {
      return Center(
        child: Text(
          'Tidak ada profil',
          style: TextStyle(color: c.textMid),
        ),
      );
    }

    return Column(
      children: [
        // Profile selector
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                'Profil:',
                style: TextStyle(fontSize: 13, color: c.textMid),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: profile.id,
                  isExpanded: true,
                  dropdownColor: c.overlay,
                  style: TextStyle(color: c.textHi, fontSize: 14),
                  underline: Container(
                    height: 1,
                    color: c.accent.withValues(alpha: 0.5),
                  ),
                  onChanged: (id) {
                    setState(() {
                      _selectedProfile = profiles.firstWhere((p) => p.id == id);
                    });
                  },
                  items: profiles.map((p) {
                    return DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Mapping list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: profile.mappings.length,
            itemBuilder: (context, index) {
              final mapping = profile.mappings[index];
              return _MappingDetailCard(mapping: mapping);
            },
          ),
        ),
      ],
    );
  }
}

class _MappingDetailCard extends StatelessWidget {
  const _MappingDetailCard({required this.mapping});

  final ControlMapping mapping;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: c.textLow.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Input key badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(R.sm),
              border: Border.all(color: c.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              mapping.inputKey,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Arrow
          Icon(LucideIcons.arrowRight, size: 16, color: c.textLow),
          const SizedBox(width: 12),
          // Action info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mapping.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                  ),
                ),
                if (mapping.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    mapping.description!,
                    style: TextStyle(fontSize: 11, color: c.textLow),
                  ),
                ],
              ],
            ),
          ),
          // Input type icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.textLow.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              switch (mapping.inputType) {
                InputType.keyboard => LucideIcons.keyboard,
                InputType.mouse => LucideIcons.mouse,
                InputType.joystick => LucideIcons.gamepad2,
                InputType.touch => LucideIcons.hand,
              },
              size: 16,
              color: c.textMid,
            ),
          ),
        ],
      ),
    );
  }
}
