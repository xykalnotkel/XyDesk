//! Langganan — keadaan jujur: semua fitur inti gratis selama beta.
//!
//! Sebelumnya halaman ini berisi mockup paket Pro/Studio dengan harga yang
//! tidak terhubung ke gateway pembayaran mana pun — itu dummy yang menyesatkan.
//! Sekarang halaman menyatakan fakta: tidak ada paket berbayar, tidak ada
//! batas percobaan, dan pengumuman (kalau kelak ada) akan lewat tab Berita.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tokens.dart';
import '../../widgets/seamless.dart';

class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Langganan'),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: c.textMid),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.screen, 8, Gap.screen, 32),
        children: [
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(R.lg),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF241042),
                      c.accent.withValues(alpha: 0.82),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'XyDesk Beta',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Semua fitur inti terbuka, tanpa batas, tanpa kartu kredit.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      LucideIcons.badgeCheck,
                      size: 34,
                      color: Color(0xFFE8C7FF),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          const SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeatureRow(
                  icon: LucideIcons.monitorSmartphone,
                  title: 'Perangkat tanpa batas',
                  subtitle: 'Simpan dan hubungkan semua perangkatmu.',
                ),
                _CardGap(),
                _FeatureRow(
                  icon: LucideIcons.highlighter,
                  title: 'Semua mode kontrol',
                  subtitle: 'Panel gaming, keyboard virtual, pointer relatif.',
                ),
                _CardGap(),
                _FeatureRow(
                  icon: LucideIcons.shieldCheck,
                  title: 'Sesi peer-to-peer',
                  subtitle: 'Media tidak disimpan dan tidak lewat server kami.',
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          Text(
            'Tidak ada paket berbayar saat ini. Kalau kelak ada perubahan model, '
            'pengumumannya dipublikasikan di tab Berita — bukan lewat iklan '
            'dalam aplikasi.',
            style: TextStyle(fontSize: 12.5, color: c.textMid, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Icon(icon, size: 19, color: c.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(subtitle, style: TextStyle(fontSize: 12, color: c.textMid)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardGap extends StatelessWidget {
  const _CardGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 14);
}
