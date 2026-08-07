import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Glyph HUD XyDesk — versi Flutter dari `hudsvg.py`.
///
/// Semua digambar sebagai path, bukan teks. Alasannya: karakter seperti
/// `↑↓` dan `⇄` dirender berbeda di tiap font dan OS, ukurannya tidak
/// konsisten, dan ketebalan garisnya tidak bisa diatur. Dengan CustomPainter
/// kita bisa mengubah stroke 1.5 → 3.0 untuk mode kontras tinggi tanpa
/// mengubah bentuk sama sekali.
enum HudGlyph {
  mouseLeft,
  mouseRight,
  mouseMiddle,
  scrollUp,
  scrollDown,
  scrollBoth,
  switchHold,
  dropdownUpDown,
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight,
  dpad,
  stick,
  wasd,
  trackpad,
  keypad,
  ptt,
  keycap,
  combo4,
}

class HudIcon extends StatelessWidget {
  const HudIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.color = const Color(0xFFEDEDEF),
    this.strokeWidth = 1.5,
  });

  final HudGlyph glyph;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    // Badan mouse memakai proporsi 32:40, sisanya bujur sangkar.
    final isMouse = glyph == HudGlyph.mouseLeft ||
        glyph == HudGlyph.mouseRight ||
        glyph == HudGlyph.mouseMiddle;
    final h = isMouse ? size * 40 / 32 : size;

    return SizedBox(
      width: size,
      height: h,
      child: CustomPaint(
        painter: _HudPainter(glyph, color, strokeWidth),
      ),
    );
  }
}

class _HudPainter extends CustomPainter {
  _HudPainter(this.glyph, this.color, this.sw);

  final HudGlyph glyph;
  final Color color;
  final double sw;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.9);

    switch (glyph) {
      case HudGlyph.mouseLeft:
        _mouse(canvas, size, stroke, fill, _MousePart.left);
      case HudGlyph.mouseRight:
        _mouse(canvas, size, stroke, fill, _MousePart.right);
      case HudGlyph.mouseMiddle:
        _mouse(canvas, size, stroke, fill, _MousePart.middle);
      case HudGlyph.scrollUp:
        _scroll(canvas, size, stroke, up: true);
      case HudGlyph.scrollDown:
        _scroll(canvas, size, stroke, up: false);
      case HudGlyph.scrollBoth:
        _scrollBoth(canvas, size, stroke);
      case HudGlyph.switchHold:
        _switchHold(canvas, size, stroke);
      case HudGlyph.dropdownUpDown:
        _dropdown(canvas, size, stroke);
      case HudGlyph.arrowUp:
        _arrow(canvas, size, stroke, 0);
      case HudGlyph.arrowRight:
        _arrow(canvas, size, stroke, 1);
      case HudGlyph.arrowDown:
        _arrow(canvas, size, stroke, 2);
      case HudGlyph.arrowLeft:
        _arrow(canvas, size, stroke, 3);
      case HudGlyph.dpad:
        _dpad(canvas, size, stroke);
      case HudGlyph.stick:
        _stick(canvas, size, stroke);
      case HudGlyph.wasd:
        _wasd(canvas, size, stroke);
      case HudGlyph.trackpad:
        _trackpad(canvas, size, stroke, fill);
      case HudGlyph.keypad:
        _keypad(canvas, size, stroke);
      case HudGlyph.ptt:
        _ptt(canvas, size, stroke);
      case HudGlyph.keycap:
        _keycap(canvas, size, stroke);
      case HudGlyph.combo4:
        _combo4(canvas, size, stroke);
    }
  }

  // ── Mouse: badan membulat, garis pemisah atas, garis tengah vertikal ──
  void _mouse(Canvas c, Size s, Paint st, Paint fl, _MousePart part) {
    final u = s.width / 32; // skala dari viewBox 32x40
    final body = RRect.fromLTRBR(
      3 * u,
      2 * u,
      29 * u,
      38 * u,
      Radius.circular(13 * u),
    );

    // Bagian yang tersorot digambar lebih dulu agar berada di bawah garis.
    c.save();
    c.clipRRect(body);
    switch (part) {
      case _MousePart.left:
        c.drawRect(Rect.fromLTRB(3 * u, 2 * u, 16 * u, 15 * u), fl);
      case _MousePart.right:
        c.drawRect(Rect.fromLTRB(16 * u, 2 * u, 29 * u, 15 * u), fl);
      case _MousePart.middle:
        break;
    }
    c.restore();

    c.drawRRect(body, st);
    c.drawLine(Offset(3 * u, 15 * u), Offset(29 * u, 15 * u), st);
    c.drawLine(Offset(16 * u, 2 * u), Offset(16 * u, 15 * u), st);

    // Roda tengah
    final wheel = RRect.fromLTRBR(
      13.5 * u,
      5 * u,
      18.5 * u,
      14 * u,
      Radius.circular(2.5 * u),
    );
    if (part == _MousePart.middle) {
      c.drawRRect(wheel, fl);
    } else {
      c.drawRRect(wheel, st);
    }
  }

  // ── Roda gulir + panah ganda (panah kedua lebih samar = arah) ──
  void _scroll(Canvas c, Size s, Paint st, {required bool up}) {
    final u = s.width / 24;
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (up) {
      c.drawRRect(
          RRect.fromLTRBR(8 * u, 9 * u, 16 * u, 23 * u, Radius.circular(4 * u)),
          st);
      c.drawLine(Offset(12 * u, 12 * u), Offset(12 * u, 16 * u), st);
      _chevron(c, st, Offset(12 * u, 1 * u), 5.5 * u, up: true);
      _chevron(c, faint, Offset(12 * u, 6 * u), 3.5 * u, up: true);
    } else {
      c.drawRRect(
          RRect.fromLTRBR(8 * u, 1 * u, 16 * u, 15 * u, Radius.circular(4 * u)),
          st);
      c.drawLine(Offset(12 * u, 4 * u), Offset(12 * u, 8 * u), st);
      _chevron(c, st, Offset(12 * u, 23 * u), 5.5 * u, up: false);
      _chevron(c, faint, Offset(12 * u, 18 * u), 3.5 * u, up: false);
    }
  }

  void _scrollBoth(Canvas c, Size s, Paint st) {
    final u = s.width / 24;
    c.drawRRect(
        RRect.fromLTRBR(8 * u, 5 * u, 16 * u, 19 * u, Radius.circular(4 * u)),
        st);
    c.drawLine(Offset(12 * u, 8.5 * u), Offset(12 * u, 11.5 * u), st);
    _chevron(c, st, Offset(12 * u, 0.5 * u), 3.5 * u, up: true);
    _chevron(c, st, Offset(12 * u, 23.5 * u), 3.5 * u, up: false);
  }

  void _chevron(Canvas c, Paint p, Offset tip, double r, {required bool up}) {
    final dy = up ? r : -r;
    final path = Path()
      ..moveTo(tip.dx - r, tip.dy + dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + r, tip.dy + dy);
    c.drawPath(path, p);
  }

  // ── Switch tahan-klik: kapsul + dua panah bolak-balik ──
  void _switchHold(Canvas c, Size s, Paint st) {
    final u = s.width / 34;
    c.drawRRect(
        RRect.fromLTRBR(1 * u, 1 * u, 33 * u, 19 * u, Radius.circular(9 * u)),
        st);
    // panah ke kanan (atas)
    c.drawLine(Offset(11 * u, 7.5 * u), Offset(23 * u, 7.5 * u), st);
    c.drawPath(
      Path()
        ..moveTo(19.5 * u, 4.5 * u)
        ..lineTo(23 * u, 7.5 * u),
      st,
    );
    // panah ke kiri (bawah)
    c.drawLine(Offset(23 * u, 12.5 * u), Offset(11 * u, 12.5 * u), st);
    c.drawPath(
      Path()
        ..moveTo(14.5 * u, 15.5 * u)
        ..lineTo(11 * u, 12.5 * u),
      st,
    );
  }

  // ── Dropdown ▲▼: kotak nilai + dua panah terpisah ──
  void _dropdown(Canvas c, Size s, Paint st) {
    final u = s.width / 24;
    c.drawRRect(
        RRect.fromLTRBR(
            2.5 * u, 8 * u, 15.5 * u, 16 * u, Radius.circular(2 * u)),
        st);
    c.drawLine(Offset(20 * u, 10.5 * u), Offset(20 * u, 4 * u), st);
    _chevron(c, st, Offset(20 * u, 4 * u), 2.5 * u, up: true);
    c.drawLine(Offset(20 * u, 13.5 * u), Offset(20 * u, 20 * u), st);
    _chevron(c, st, Offset(20 * u, 20 * u), 2.5 * u, up: false);
  }

  // ── Panah arah, dirotasi dari bentuk "atas" ──
  void _arrow(Canvas c, Size s, Paint st, int quarterTurns) {
    final u = s.width / 24;
    c.save();
    c.translate(s.width / 2, s.height / 2);
    c.rotate(quarterTurns * math.pi / 2);
    c.translate(-s.width / 2, -s.height / 2);
    c.drawLine(Offset(12 * u, 19 * u), Offset(12 * u, 6 * u), st);
    _chevron(c, st, Offset(12 * u, 6 * u), 5.5 * u, up: true);
    c.restore();
  }

  // ── D-Pad salib: 4 kotak + kotak tengah putus-putus ──
  void _dpad(Canvas c, Size s, Paint st) {
    final u = s.width / 60;
    final r = Radius.circular(3 * u);
    void box(double l, double t) => c.drawRRect(
        RRect.fromLTRBR(l * u, t * u, (l + 18) * u, (t + 18) * u, r), st);
    box(21, 1);
    box(21, 41);
    box(1, 21);
    box(41, 21);

    final dashed = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.38)
      ..strokeWidth = sw;
    _dashedRRect(
      c,
      RRect.fromLTRBR(21 * u, 21 * u, 39 * u, 39 * u, r),
      dashed,
      dash: 2 * u,
      gap: 2 * u,
    );

    // panah kecil di tiap kotak
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = sw * 0.95
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawLine(Offset(30 * u, 12.5 * u), Offset(30 * u, 6.5 * u), thin);
    _chevron(c, thin, Offset(30 * u, 6.5 * u), 3 * u, up: true);
    c.drawLine(Offset(30 * u, 47.5 * u), Offset(30 * u, 53.5 * u), thin);
    _chevron(c, thin, Offset(30 * u, 53.5 * u), 3 * u, up: false);
    _hChevron(c, thin, Offset(6.5 * u, 30 * u), 3 * u, left: true);
    c.drawLine(Offset(12.5 * u, 30 * u), Offset(6.5 * u, 30 * u), thin);
    _hChevron(c, thin, Offset(53.5 * u, 30 * u), 3 * u, left: false);
    c.drawLine(Offset(47.5 * u, 30 * u), Offset(53.5 * u, 30 * u), thin);
  }

  void _hChevron(Canvas c, Paint p, Offset tip, double r,
      {required bool left}) {
    final dx = left ? r : -r;
    c.drawPath(
      Path()
        ..moveTo(tip.dx + dx, tip.dy - r)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + dx, tip.dy + r),
      p,
    );
  }

  void _dashedRRect(Canvas c, RRect rr, Paint p,
      {required double dash, required double gap}) {
    final path = Path()..addRRect(rr);
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, math.min(d + dash, m.length)), p);
        d += dash + gap;
      }
    }
  }

  // ── Stik analog: ring luar + ring dalam + 4 penanda ──
  void _stick(Canvas c, Size s, Paint st) {
    final u = s.width / 60;
    final ctr = Offset(30 * u, 30 * u);
    c.drawCircle(ctr, 28 * u, st);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = sw;
    c.drawCircle(ctr, 11 * u, inner);
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(30 * u, 4 * u), Offset(30 * u, 9 * u), tick);
    c.drawLine(Offset(30 * u, 51 * u), Offset(30 * u, 56 * u), tick);
    c.drawLine(Offset(4 * u, 30 * u), Offset(9 * u, 30 * u), tick);
    c.drawLine(Offset(51 * u, 30 * u), Offset(56 * u, 30 * u), tick);
  }

  // ── Tracker WASD: 4 kotak berlabel ──
  void _wasd(Canvas c, Size s, Paint st) {
    final u = s.width / 62;
    final r = Radius.circular(3 * u);
    void box(double l, double t) => c.drawRRect(
        RRect.fromLTRBR(l * u, t * u, (l + 18) * u, (t + 18) * u, r), st);
    box(21, 1);
    box(1, 21);
    box(21, 21);
    box(41, 21);

    void label(String t, double cx, double cy) {
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            color: color,
            fontSize: 10 * u,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(cx * u - tp.width / 2, cy * u - tp.height / 2));
    }

    label('W', 30, 10);
    label('A', 10, 30);
    label('S', 30, 30);
    label('D', 50, 30);
  }

  // ── Trackpad: kotak putus-putus + jejak jari ──
  void _trackpad(Canvas c, Size s, Paint st, Paint fl) {
    final u = s.width / 24;
    _dashedRRect(
      c,
      RRect.fromLTRBR(2 * u, 4 * u, 22 * u, 20 * u, Radius.circular(2.5 * u)),
      st,
      dash: 3 * u,
      gap: 2.5 * u,
    );
    final trail = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    c.drawPath(
      Path()
        ..moveTo(7 * u, 15 * u)
        ..cubicTo(9.5 * u, 11 * u, 12 * u, 9.5 * u, 17 * u, 9 * u),
      trail,
    );
    c.drawCircle(Offset(17 * u, 9 * u), 2 * u,
        Paint()..color = color.withValues(alpha: 0.7));
  }

  void _keypad(Canvas c, Size s, Paint st) {
    final u = s.width / 24;
    for (var r = 0; r < 3; r++) {
      for (var q = 0; q < 3; q++) {
        c.drawRRect(
          RRect.fromLTRBR(
            (2.5 + q * 7) * u,
            (2.5 + r * 7) * u,
            (8 + q * 7) * u,
            (8 + r * 7) * u,
            Radius.circular(1.2 * u),
          ),
          st,
        );
      }
    }
  }

  void _ptt(Canvas c, Size s, Paint st) {
    final u = s.width / 24;
    c.drawRRect(
        RRect.fromLTRBR(
            8.5 * u, 2 * u, 15.5 * u, 13 * u, Radius.circular(3.5 * u)),
        st);
    c.drawArc(
        Rect.fromLTRB(5 * u, 4.5 * u, 19 * u, 17.5 * u), 0, math.pi, false, st);
    c.drawLine(Offset(12 * u, 17.5 * u), Offset(12 * u, 21 * u), st);
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(2.5 * u, 8.5 * u), Offset(2.5 * u, 12.5 * u), faint);
    c.drawLine(Offset(21.5 * u, 8.5 * u), Offset(21.5 * u, 12.5 * u), faint);
  }

  void _keycap(Canvas c, Size s, Paint st) {
    final u = s.width / 24;
    c.drawRRect(
        RRect.fromLTRBR(3 * u, 5 * u, 21 * u, 19 * u, Radius.circular(2.5 * u)),
        st);
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(7.5 * u, 9.5 * u), Offset(16.5 * u, 9.5 * u), faint);
    c.drawLine(Offset(7.5 * u, 14.5 * u), Offset(12.5 * u, 14.5 * u), faint);
  }

  /// Kombinasi 4 tombol — slot terakhir putus-putus = opsional.
  void _combo4(Canvas c, Size s, Paint st) {
    final u = s.width / 30;
    final r = Radius.circular(1.5 * u);
    for (final l in [1.0, 9.0, 17.0]) {
      c.drawRRect(RRect.fromLTRBR(l * u, 8 * u, (l + 6) * u, 16 * u, r), st);
    }
    _dashedRRect(
      c,
      RRect.fromLTRBR(25 * u, 8 * u, 29 * u, 16 * u, r),
      st,
      dash: 2 * u,
      gap: 1.6 * u,
    );
    final link = Paint()
      ..style = PaintingStyle.stroke
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    for (final l in [7.0, 15.0, 23.0]) {
      c.drawLine(Offset(l * u, 12 * u), Offset((l + 2) * u, 12 * u), link);
    }
  }

  @override
  bool shouldRepaint(_HudPainter old) =>
      old.glyph != glyph || old.color != color || old.sw != sw;
}

enum _MousePart { left, right, middle }

/// Tombol HUD border-only dengan glyph di atas dan label di bawah.
///
/// Isi sengaja transparan penuh: piksel game di dalam tombol tetap terlihat.
/// Saat ditekan hanya diisi 14% — cukup memberi umpan balik tanpa menutupi.
class HudButton extends StatefulWidget {
  const HudButton({
    super.key,
    required this.glyph,
    required this.label,
    this.size = const Size(56, 58),
    this.strokeWidth = 1.5,
    this.opacity = 0.55,
    this.onTap,
  });

  final HudGlyph glyph;
  final String label;
  final Size size;
  final double strokeWidth;
  final double opacity;
  final VoidCallback? onTap;

  @override
  State<HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<HudButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.opacity,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: widget.size.width,
            height: widget.size.height,
            decoration: BoxDecoration(
              color: _down
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.34),
                width: widget.strokeWidth,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HudIcon(widget.glyph,
                    size: 17, strokeWidth: widget.strokeWidth),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 7.5,
                    height: 1,
                    color: Color(0xFFA0A0A8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
