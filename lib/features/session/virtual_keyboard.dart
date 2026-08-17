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
    this.onKeyWithModifiers,
    this.onDismiss,
    this.layout = KbLayout.split,
    this.onLayoutChanged,
    this.onOpacityChanged,
    this.opacity = 0.95,
  });

  final ValueChanged<String>? onKey;

  /// Seperti [onKey], tetapi menyertakan modifier sticky yang sedang aktif
  /// (Ctrl/Shift/Alt/Win/Caps) — dibutuhkan transport untuk mengirim kombinasi
  /// tombol yang benar ke host.
  final void Function(String label, Set<String> modifiers)? onKeyWithModifiers;
  final VoidCallback? onDismiss;
  final KbLayout layout;
  final ValueChanged<KbLayout>? onLayoutChanged;
  final ValueChanged<double>? onOpacityChanged;
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
    widget.onKeyWithModifiers?.call(k.label, Set.unmodifiable(_sticky));
    if (_sticky.isNotEmpty) {
      setState(() => _sticky.removeWhere((m) => !_locked.contains(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _KeyboardCloseButton(onTap: widget.onDismiss),
        ),
        switch (widget.layout) {
          KbLayout.split => _buildSplit(context),
          KbLayout.full => _buildFull(context),
          KbLayout.compact => _buildCompact(context),
        },
      ],
    );
  }

  // ── SPLIT: dua blok, tengah kosong ──
  Widget _buildSplit(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Lebar tiap belahan ~40% layar; sisanya jadi celah tengah.
    final half = w * 0.42;
    return SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: half,
            child: _pane(_rowsLeft, left: true, context: context),
          ),
          // Celah tengah dibiarkan transparan agar layar remote tetap terlihat
          // dan bisa disentuh untuk menggerakkan pointer.
          Expanded(child: _centerBar(context)),
          SizedBox(
            width: half,
            child: _pane(_rowsRight, left: false, context: context),
          ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) => SafeArea(
    top: false,
    child: _pane(_rowsFull, left: true, fullWidth: true, context: context),
  );

  Widget _buildCompact(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return SafeArea(
      top: false,
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: w * 0.62,
            child: _pane(_rowsFull, left: false, context: context),
          ),
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
          const SizedBox(height: 5),
          Semantics(
            label: 'Opacity keyboard',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.sun, size: 12, color: c.textLow),
                SizedBox(
                  width: 68,
                  height: 22,
                  child: Slider(
                    min: 0.45,
                    max: 0.98,
                    value: widget.opacity.clamp(0.45, 0.98),
                    onChanged: widget.onOpacityChanged,
                  ),
                ),
              ],
            ),
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
    required BuildContext context,
    bool fullWidth = false,
  }) {
    final c = context.c;
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
            color: c.overlay.withValues(alpha: 0.96),
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
      bg = c.textHi.withValues(alpha: 0.055);
      fg = c.textMid;
    }

    return Semantics(
      button: true,
      label: k.label,
      child: _PressableKey(
        background: bg,
        onTap: () => _press(k),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            k.label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: fg,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyboardCloseButton extends StatelessWidget {
  const _KeyboardCloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.overlay.withValues(alpha: 0.96),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 38,
          width: 86,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.x, size: 16, color: c.textHi),
              const SizedBox(width: 5),
              Text('Tutup', style: TextStyle(fontSize: 10, color: c.textMid)),
            ],
          ),
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
        color: c.overlay.withValues(alpha: 0.92),
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

  void _trigger() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _down = true);
        _trigger();
      },
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 45),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _down
                ? context.c.accent.withValues(alpha: 0.35)
                : widget.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _down
                  ? context.c.accent
                  : context.c.textLow.withValues(alpha: 0.22),
              width: _down ? 1.2 : 0.7,
            ),
            boxShadow: [
              if (!_down)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 3,
                  offset: const Offset(0, 1.5),
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
