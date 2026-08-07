import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tokens.dart';

/// Satu tombol pada keyboard virtual.
class KeySpec {
  const KeySpec(this.label, {this.flex = 1, this.modifier = false});

  final String label;
  final int flex;
  final bool modifier;
}

const _rows = <List<KeySpec>>[
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
    KeySpec(' ', flex: 7),
    KeySpec('Fn'),
    KeySpec('←'),
    KeySpec('↓'),
    KeySpec('→'),
  ],
];

/// Keyboard virtual penuh.
///
/// Radius tombol sengaja **3dp** (hampir kotak) agar terasa presisi seperti
/// keyboard mekanis. Tombol biasa tidak berubah warna saat ditekan — hanya
/// sedikit lebih terang; kilatan aksen berulang melelahkan saat mengetik cepat.
/// Hanya modifier sticky yang memakai aksen, karena statusnya perlu terlihat.
class VirtualKeyboard extends StatefulWidget {
  const VirtualKeyboard({super.key, this.onKey, this.onDismiss});

  final ValueChanged<String>? onKey;
  final VoidCallback? onDismiss;

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  /// Modifier ditahan sampai tombol berikutnya ditekan.
  final Set<String> _sticky = {};

  /// Modifier dikunci (ketuk dua kali).
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
    final c = context.c;
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) widget.onDismiss?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF18181B).withValues(alpha: 0.94),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pegangan seret untuk menutup
              Container(
                width: 30,
                height: 3,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: c.textLow.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              for (final row in _rows)
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
      child: Text(
        k.label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(fontSize: 9, color: fg, height: 1),
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
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 21,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Ditekan hanya jadi lebih terang, BUKAN berubah ke warna aksen.
            color: _down
                ? Colors.white.withValues(alpha: 0.11)
                : widget.background,
            borderRadius: BorderRadius.circular(R.key),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
