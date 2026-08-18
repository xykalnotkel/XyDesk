import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/devlog.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/hud_glyphs.dart';
import 'control_page.dart';

/// Mode penekanan tombol pada kontrol kustom.
enum PressMode {
  normal('Normal', 'Tekan biasa / satu ketukan instan'),
  hold('Tekan Lama', 'Tahan untuk mengulang perintah terus-menerus'),
  toggle('Toggle (Kunci)', '1-Klik kunci aktif, ketuk lagi untuk melepas'),
  turbo('Turbo Rapid', 'Klik otomatis berkecepatan tinggi (Auto Fire)');

  const PressMode(this.label, this.description);
  final String label;
  final String description;
}

/// Satu elemen kontrol kustom pada layar mapping.
class MappedElement {
  MappedElement({
    required this.id,
    required this.label,
    required this.glyph,
    this.x = 0.5, // 0.0 - 1.0 (proporsi layar)
    this.y = 0.5,
    this.scale = 1.0, // 0.6 - 2.0
    this.opacity = 0.85, // 0.2 - 1.0
    this.mode = PressMode.normal,
    this.shortcut = 'F1',
  });

  final String id;
  String label;
  final HudGlyph glyph;
  double x;
  double y;
  double scale;
  double opacity;
  PressMode mode;
  String shortcut;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'glyph': glyph.name,
    'x': x,
    'y': y,
    'scale': scale,
    'opacity': opacity,
    'mode': mode.name,
    'shortcut': shortcut,
  };

  factory MappedElement.fromJson(Map<String, dynamic> j) => MappedElement(
    id: j['id'] as String? ?? 'btn_${DateTime.now().millisecondsSinceEpoch}',
    label: j['label'] as String? ?? 'BTN',
    glyph: HudGlyph.values.firstWhere(
      (g) => g.name == j['glyph'],
      orElse: () => HudGlyph.combo4,
    ),
    x: (j['x'] as num? ?? 0.5).toDouble(),
    y: (j['y'] as num? ?? 0.5).toDouble(),
    scale: (j['scale'] as num? ?? 1.0).toDouble(),
    opacity: (j['opacity'] as num? ?? 0.85).toDouble(),
    mode: PressMode.values.firstWhere(
      (m) => m.name == j['mode'],
      orElse: () => PressMode.normal,
    ),
    shortcut: j['shortcut'] as String? ?? j['label'] as String? ?? 'F1',
  );
}

/// Halaman Editor Mapping Kontrol (Drag & Drop, Atur Size, Opacity, Mode Tekan).
class ControlMappingEditorPage extends ConsumerStatefulWidget {
  const ControlMappingEditorPage({super.key, required this.profile});

  final ControlProfile profile;

  @override
  ConsumerState<ControlMappingEditorPage> createState() =>
      _ControlMappingEditorPageState();
}

class _ControlMappingEditorPageState
    extends ConsumerState<ControlMappingEditorPage> {
  late List<MappedElement> _elements;
  MappedElement? _selected;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _loadMapping();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _loadMapping() {
    final store = ref.read(storeProvider);
    final key = 'mapping_${widget.profile.id}';
    final raw = store.getList(key);
    if (raw.isEmpty) {
      // Default seed mapping untuk profil ini
      _elements = [
        MappedElement(
          id: 'btn_dpad',
          label: 'D-Pad',
          glyph: HudGlyph.dpad,
          x: 0.14,
          y: 0.74,
          scale: 1.2,
        ),
        MappedElement(
          id: 'btn_a',
          label: 'A',
          glyph: HudGlyph.combo4,
          x: 0.85,
          y: 0.74,
          scale: 1.1,
        ),
        MappedElement(
          id: 'btn_l1',
          label: 'L1',
          glyph: HudGlyph.switchHold,
          x: 0.15,
          y: 0.18,
          scale: 1.0,
          mode: PressMode.toggle,
        ),
        MappedElement(
          id: 'btn_r1',
          label: 'R1',
          glyph: HudGlyph.keycap,
          x: 0.85,
          y: 0.18,
          scale: 1.0,
          mode: PressMode.hold,
        ),
      ];
    } else {
      _elements = raw.map(MappedElement.fromJson).toList();
    }
  }

  Future<void> _saveMapping() async {
    final store = ref.read(storeProvider);
    final key = 'mapping_${widget.profile.id}';
    await store.setList(key, _elements.map((e) => e.toJson()).toList());
    DevLog.ok('control_editor', 'Mapping disimpan', widget.profile.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pemetaan "${widget.profile.name}" berhasil disimpan (${_elements.length} tombol)',
        ),
      ),
    );
  }

  void _addElement() {
    setState(() {
      final newElem = MappedElement(
        id: 'btn_${DateTime.now().millisecondsSinceEpoch}',
        label: 'F1',
        glyph: HudGlyph.keycap,
        shortcut: 'F1',
        x: 0.5,
        y: 0.5,
      );
      _elements.add(newElem);
      _selected = newElem;
    });
    HapticFeedback.lightImpact();
    _showElementConfigModal(_selected!);
  }

  void _showElementConfigModal(MappedElement elem) {
    final c = context.c;
    final shortcutController = TextEditingController(text: elem.shortcut);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.overlay,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kustomisasi Tombol "${elem.label}"',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.textHi,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.trash2,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        onPressed: () {
                          setState(() {
                            _elements.removeWhere((e) => e.id == elem.id);
                            if (_selected?.id == elem.id) _selected = null;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tombol atau kombinasi keyboard',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textMid,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: shortcutController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: F1, K, Ctrl+V, Ctrl+Shift+S',
                      prefixIcon: Icon(LucideIcons.keyboard, size: 18),
                    ),
                    onChanged: (value) {
                      final shortcut = value.trim();
                      setModalState(() {
                        elem.shortcut = shortcut.isEmpty ? 'F1' : shortcut;
                        elem.label = elem.shortcut;
                      });
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  // ── Mode Tekan ──
                  Text(
                    'Mode Tekan (Press Mode)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textMid,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final mode in PressMode.values) ...[
                          ChoiceChip(
                            label: Text(mode.label),
                            selected: elem.mode == mode,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => elem.mode = mode);
                                setState(() {});
                                HapticFeedback.lightImpact();
                              }
                            },
                            selectedColor: c.accent,
                            backgroundColor: c.raised,
                            labelStyle: TextStyle(
                              color: elem.mode == mode
                                  ? Colors.white
                                  : c.textHi,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Ukuran Tombol ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ukuran Tombol',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.textMid,
                        ),
                      ),
                      Text(
                        '${(elem.scale * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textHi,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 0.6,
                    max: 2.0,
                    value: elem.scale.clamp(0.6, 2.0),
                    onChanged: (val) {
                      setModalState(() => elem.scale = val);
                      setState(() {});
                    },
                  ),
                  // ── Opasitas Tombol ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Opasitas (Transparansi)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.textMid,
                        ),
                      ),
                      Text(
                        '${(elem.opacity * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textHi,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 0.2,
                    max: 1.0,
                    value: elem.opacity.clamp(0.2, 1.0),
                    onChanged: (val) {
                      setModalState(() => elem.opacity = val);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Selesai Kustomisasi'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(shortcutController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1015),
      body: Stack(
        children: [
          // Background grid simulasi layar game
          Positioned.fill(
            child: CustomPaint(
              painter: _GridBackgroundPainter(
                c.textLow.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Elemen Mapped (Drag & Drop)
          for (final elem in _elements) _buildDraggableElement(elem, context),
          // Bilah navigasi atas HUD Editor
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.arrowLeft, color: c.textHi),
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: c.overlay.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: c.textLow.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      'Editor: ${widget.profile.name}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textHi,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Tombol Baru'),
                    onPressed: _addElement,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(LucideIcons.save, size: 16),
                    label: const Text('Simpan'),
                    onPressed: _saveMapping,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableElement(MappedElement elem, BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isSelected = _selected?.id == elem.id;

    return Positioned(
      left: elem.x * size.width - (35 * elem.scale),
      top: elem.y * size.height - (35 * elem.scale),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            _selected = elem;
            elem.x = ((elem.x * size.width + details.delta.dx) / size.width)
                .clamp(0.05, 0.95);
            elem.y = ((elem.y * size.height + details.delta.dy) / size.height)
                .clamp(0.10, 0.90);
          });
        },
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _selected = elem);
          _showElementConfigModal(elem);
        },
        child: Transform.scale(
          scale: elem.scale,
          child: Opacity(
            opacity: elem.opacity,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.c.accent.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999), // HARUS BULAT
                border: Border.all(
                  color: isSelected
                      ? context.c.accent
                      : Colors.white.withValues(alpha: 0.45),
                  width: isSelected ? 2.0 : 1.2,
                ),
              ),
              child: elem.glyph == HudGlyph.keycap
                  ? SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Text(
                          elem.shortcut,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontSize: elem.shortcut.length > 5 ? 8 : 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? context.c.accent : Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HudIcon(
                          elem.glyph,
                          size: 20,
                          color: isSelected ? context.c.accent : Colors.white,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          elem.label,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? context.c.accent : Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  _GridBackgroundPainter(this.gridColor);
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;
    const step = 40.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
