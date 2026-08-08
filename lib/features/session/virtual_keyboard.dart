import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tokens.dart';

/// Satu tombol pada keyboard virtual.
class KeySpec {
  const KeySpec(this.label, {this.flex = 1, this.modifier = false, this.icon});

  final String label;
  final int flex;
  final bool modifier;
  final IconData? icon;
}

/// Tata letak keyboard.
enum KbLayout {
  /// Terbagi kiri–kanan dengan ruang kosong di tengah. Ini yang paling
  /// nyaman saat HP dipegang dua tangan dalam mode landscape: jempol
  /// tidak perlu menjangkau tengah layar.
  split,

  /// Satu blok penuh selebar layar.
  full,

  /// Blok penuh tapi menempel ke satu sisi, untuk pemakaian satu tangan.
  compact,
}

const _rowsFull = <List<KeySpec>>[
  [
    KeySpec('Esc'),
    KeySpec('F1'),
    KeySpec('F2'),
    KeySpec('F3'),
    KeySpec('F4'),
    KeySpec('F5'),
    KeySpec('F6'),
    KeySpec('F7'),
    KeySpec('F8'),
    KeySpec('F9'),
    KeySpec('F10'),
    KeySpec('F11'),
    KeySpec('F12'),
    KeySpec('⌫', flex: 2),
  ],
  [
    KeySpec('`'),
    KeySpec('1'),
    KeySpec('2'),
    KeySpec('3'),
    KeySpec('4'),
    KeySpec('5'),
    KeySpec('6'),
    KeySpec('7'),
    KeySpec('8'),
    KeySpec('9'),
    KeySpec('0'),
    KeySpec('-'),
    KeySpec('='),
    KeySpec('Del', flex: 2),
  ],
  [
    KeySpec('Tab', flex: 2),
    KeySpec('Q'),
    KeySpec('W'),
    KeySpec('E'),
    KeySpec('R'),
    KeySpec('T'),
    KeySpec('Y'),
    KeySpec('U'),
    KeySpec('I'),
    KeySpec('O'),
    KeySpec('P'),
    KeySpec('['),
    KeySpec(']'),
  ],
  [
    KeySpec('Caps', flex: 2, modifier: true),
    KeySpec('A'),
    KeySpec('S'),
    KeySpec('D'),
    KeySpec('F'),
    KeySpec('G'),
    KeySpec('H'),
    KeySpec('J'),
    KeySpec('K'),
    KeySpec('L'),
    KeySpec(';'),
    KeySpec('Enter', flex: 2),
  ],
  [
    KeySpec('Shift', flex: 2, modifier: true),
    KeySpec('Z'),
    KeySpec('X'),
    KeySpec('C'),
    KeySpec('V'),
    KeySpec('B'),
    KeySpec('N'),
    KeySpec('M'),
    KeySpec(','),
    KeySpec('.'),
    KeySpec('/'),
    KeySpec('↑'),
  ],
  [
    KeySpec('Ctrl', flex: 2, modifier: true),
    KeySpec('Win', modifier: true),
    KeySpec('Alt', modifier: true),
    KeySpec(' ', flex: 6),
    KeySpec('Fn'),
    KeySpec('←'),
    KeySpec('↓'),
    KeySpec('→'),
  ],
];

/// Belahan kiri — jempol kiri.
const _rowsLeft = <List<KeySpec>>[
  [
    KeySpec('Esc'),
    KeySpec('F1'),
    KeySpec('F2'),
    KeySpec('F3'),
    KeySpec('F4'),
    KeySpec('F5'),
  ],
  [
    KeySpec('`'),
    KeySpec('1'),
    KeySpec('2'),
    KeySpec('3'),
    KeySpec('4'),
    KeySpec('5'),
  ],
  [
    KeySpec('Tab', flex: 2),
    KeySpec('Q'),
    KeySpec('W'),
    KeySpec('E'),
    KeySpec('R'),
    KeySpec('T'),
  ],
  [
    KeySpec('Caps', flex: 2, modifier: true),
    KeySpec('A'),
    KeySpec('S'),
    KeySpec('D'),
    KeySpec('F'),
    KeySpec('G'),
  ],
  [
    KeySpec('Shift', flex: 2, modifier: true),
    KeySpec('Z'),
    KeySpec('X'),
    KeySpec('C'),
    KeySpec('V'),
    KeySpec('B'),
  ],
  [
    KeySpec('Ctrl', flex: 2, modifier: true),
    KeySpec('Win', modifier: true),
    KeySpec('Alt', modifier: true),
    KeySpec(' ', flex: 3),
  ],
];

/// Belahan kanan — jempol kanan.
const _rowsRight = <List<KeySpec>>[
  [
    KeySpec('F6'),
    KeySpec('F7'),
    KeySpec('F8'),
    KeySpec('F9'),
    KeySpec('F10'),
    KeySpec('F11'),
    KeySpec('F12'),
    KeySpec('⌫', flex: 2),
  ],
  [
    KeySpec('6'),
    KeySpec('7'),
    KeySpec('8'),
    KeySpec('9'),
    KeySpec('0'),
    KeySpec('-'),
    KeySpec('='),
    KeySpec('Del', flex: 2),
  ],
  [
    KeySpec('Y'),
    KeySpec('U'),
    KeySpec('I'),
    KeySpec('O'),
    KeySpec('P'),
    KeySpec('['),
    KeySpec(']'),
    KeySpec(r'\'),
  ],
  [
    KeySpec('H'),
    KeySpec('J'),
    KeySpec('K'),
    KeySpec('L'),
    KeySpec(';'),
    KeySpec("'"),
    KeySpec('Enter', flex: 3),
  ],
  [
    KeySpec('N'),
    KeySpec('M'),
    KeySpec(','),
    KeySpec('.'),
    KeySpec('/'),
    KeySpec('Shift', flex: 2, modifier: true),
    KeySpec('↑'),
  ],
  [
    KeySpec(' ', flex: 3),
    KeySpec('Alt', modifier: true),
    KeySpec('Fn'),
    KeySpec('←'),
    KeySpec('↓'),
    KeySpec('→'),
  ],
];

/// Keyboard virtual.
///
/// Mode bawaan adalah **split**: dua blok di kiri dan kanan dengan ruang
/// kosong di tengah, sehingga area layar remote di tengah tetap terlihat
/// dan ibu jari tidak perlu menjangkau jauh saat mode landscape.
class VirtualKeyboard extends StatefulWidget {
  const VirtualKeyboard({
    super.key,
    this.onKey,
    this.onDismiss,
    this.layout = KbLayout.split,
    this.onLayoutChanged,
    this.opacity = 0.95,
  });

  final ValueChanged<String>? onKey;
  final VoidCallback? onDismiss;
  final KbLayout layout;
  final ValueChanged<KbLayout>? onLayoutChanged;
  final double opacity;

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  final Set<String> _sticky = {};
  final Set<String> _locked = {};

  void _press(KeySpec k) {
    HapticFeedback.selectionClick();
    if (k.modifier) {
      setState(() {
        if (_locked.contains(k.label)) {
          _locked.remove(k.label);
          _sticky.remove(k.label);
        } else if (_sticky.contains(k.label)) {
          _locked.add(k.label);
        } else {
          _sticky.add(k.label);
        }
      });
      return;
    }
    widget.onKey?.call(k.label);
    if (_sticky.isNotEmpty) {
      setState(() => _sticky.removeWhere((m) => !_locked.contains(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.layout) {
      KbLayout.split => _buildSplit(context),
      KbLayout.full => _buildFull(context),
      KbLayout.compact => _buildCompact(context),
    };
  }

  // ── SPLIT: dua blok, tengah kosong ──
  Widget _buildSplit(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Lebar tiap belahan ~40% layar; sisanya jadi celah tengah.
    final half = w * 0.40;
    return SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: half, child: _pane(_rowsLeft, left: true)),
          // Celah tengah dibiarkan transparan agar layar remote tetap terlihat
          // dan bisa disentuh untuk menggerakkan pointer.
          Expanded(child: _centerBar(context)),
          SizedBox(width: half, child: _pane(_rowsRight, left: false)),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) => SafeArea(
    top: false,
    child: _pane(_rowsFull, left: true, fullWidth: true),
  );

  Widget _buildCompact(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return SafeArea(
      top: false,
      child: Row(
        children: [
          const Spacer(),
          SizedBox(width: w * 0.62, child: _pane(_rowsFull, left: false)),
        ],
      ),
    );
  }

  /// Bilah tengah: pegangan tutup + pemilih tata letak.
  Widget _centerBar(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniBtn(
            icon: LucideIcons.columns2,
            tooltip: 'Ubah tata letak',
            onTap: () {
              final next = switch (widget.layout) {
                KbLayout.split => KbLayout.full,
                KbLayout.full => KbLayout.compact,
                KbLayout.compact => KbLayout.split,
              };
              widget.onLayoutChanged?.call(next);
            },
          ),
          const SizedBox(height: 6),
          _MiniBtn(
            icon: LucideIcons.chevronDown,
            tooltip: 'Tutup keyboard',
            onTap: widget.onDismiss,
          ),
          const SizedBox(height: 8),
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: c.textLow.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pane(
    List<List<KeySpec>> rows, {
    required bool left,
    bool fullWidth = false,
  }) {
    final radius = fullWidth
        ? const BorderRadius.vertical(top: Radius.circular(6))
        : BorderRadius.only(
            topLeft: Radius.circular(left ? 0 : 8),
            topRight: Radius.circular(left ? 8 : 0),
          );

    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 250) widget.onDismiss?.call();
      },
      child: Opacity(
        opacity: widget.opacity,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18181B).withValues(alpha: 0.95),
            borderRadius: radius,
          ),
          padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3.5),
                  child: Row(
                    children: [
                      for (final k in row) ...[
                        Expanded(flex: k.flex, child: _key(k)),
                        if (k != row.last) const SizedBox(width: 3),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _key(KeySpec k) {
    final c = context.c;
    final locked = _locked.contains(k.label);
    final sticky = _sticky.contains(k.label);

    final Color bg;
    final Color fg;
    if (locked) {
      bg = c.accent;
      fg = Colors.white;
    } else if (sticky) {
      bg = c.accentSoft;
      fg = c.textHi;
    } else {
      bg = Colors.white.withValues(alpha: 0.055);
      fg = c.textMid;
    }

    return _PressableKey(
      background: bg,
      onTap: () => _press(k),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          k.label,
          maxLines: 1,
          style: TextStyle(fontSize: 9.5, color: fg, height: 1),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: const Color(0xFF18181B).withValues(alpha: 0.9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 15, color: c.textMid),
          ),
        ),
      ),
    );
  }
}

class _PressableKey extends StatefulWidget {
  const _PressableKey({
    required this.child,
    required this.background,
    required this.onTap,
  });

  final Widget child;
  final Color background;
  final VoidCallback onTap;

  @override
  State<_PressableKey> createState() => _PressableKeyState();
}

class _PressableKeyState extends State<_PressableKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _down
                ? Colors.white.withValues(alpha: 0.12)
                : widget.background,
            borderRadius: BorderRadius.circular(R.key),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
