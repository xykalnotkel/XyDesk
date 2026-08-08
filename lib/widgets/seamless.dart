import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Gradient fade yang menggantikan garis pemisah.
///
/// Ini inti dari aturan "nol garis": alih-alih memberi border di bawah topbar
/// atau di atas bottom-nav, kita taruh gradasi dari warna background menuju
/// transparan. Teks yang lewat di belakangnya memudar dengan halus.
class FadeEdge extends StatelessWidget {
  const FadeEdge({super.key, required this.height, this.fromTop = true});

  final double height;
  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    final bg = context.c.bg;
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [bg, bg.withValues(alpha: 0)],
            stops: const [0.32, 1],
          ),
        ),
      ),
    );
  }
}

/// Scaffold seamless: konten mengalir di belakang topbar dan bottom-nav.
class SeamlessScaffold extends StatelessWidget {
  const SeamlessScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.bottomNav,
    this.leading,
    this.padHorizontal = true,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? bottomNav;
  final Widget? leading;
  final bool padHorizontal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dua flag ini yang membuat background benar-benar mengalir.
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              leading: leading,
              actions: [
                ...?actions,
                const SizedBox(width: Gap.md),
              ],
              toolbarHeight: 52,
            ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: padHorizontal ? Gap.screen : 0,
            ),
            child: body,
          ),
          if (bottomNav != null)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FadeEdge(height: 92, fromTop: false),
            ),
        ],
      ),
      bottomNavigationBar: bottomNav,
    );
  }
}

/// Kartu tanpa border — hanya beda luminansi ~3% dari background.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.dim = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Material(
        color: context.c.raised,
        borderRadius: BorderRadius.circular(R.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Titik status koneksi. Warna desaturasi, bukan lampu neon.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.pingMs});

  /// null = offline.
  final int? pingMs;

  Color _color(BuildContext context) {
    final ms = pingMs;
    if (ms == null) return context.c.textLow;
    if (ms < 40) return AppColors.success;
    if (ms <= 90) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: _color(context), shape: BoxShape.circle),
    );
  }
}

/// Label bagian: huruf kecil, kapital, warna redup.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.top = 18});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 7, left: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: context.c.textLow,
        ),
      ),
    );
  }
}

/// Baris daftar sederhana — dipakai menggantikan kartu bertumpuk.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.value,
    this.onTap,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = danger ? c.danger : c.textHi;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: c.raised,
                  borderRadius: BorderRadius.circular(9),
                ),
                child:
                    Icon(icon, size: 16, color: danger ? c.danger : c.textMid),
              ),
              const SizedBox(width: Gap.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: fg)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          style: TextStyle(fontSize: 11, color: c.textLow)),
                    ),
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(value!,
                    style: TextStyle(fontSize: 11.5, color: c.textLow)),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Tombol sekunder bergaya "ghost" — latar input, tanpa border.
class OutlinedButtonLike extends StatelessWidget {
  const OutlinedButtonLike({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.input,
      borderRadius: BorderRadius.circular(R.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.lg),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: c.textMid),
                const SizedBox(width: Gap.sm),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textHi)),
            ],
          ),
        ),
      ),
    );
  }
}
