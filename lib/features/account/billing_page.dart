import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/seamless.dart';

/// Billing premium mockup. Belum terhubung ke payment gateway; seluruh aksi
/// sengaja memberi feedback lokal sampai backend billing tersedia.
class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Billing akan tersedia setelah backend siap.')),
    );
  }

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
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'XyDesk Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Remote desktop lebih cepat, lebih nyaman, tanpa batas demo.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons.crown,
                      size: 34,
                      color: Color(0xFFE8C7FF),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          const Center(child: Illus(Img.billing, size: 235)),
          const SizedBox(height: Gap.sm),
          Text(
            'Pilih paket yang cocok untuk cara kamu memakai XyDesk.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: c.textMid, height: 1.45),
          ),
          const SizedBox(height: Gap.lg),
          const _PlanCard(
            name: 'Free',
            price: 'Rp0',
            period: 'untuk mencoba flow UI',
            features: [
              '1 perangkat tersimpan',
              'Session demo',
              'Kontrol dasar',
            ],
            current: true,
            onTap: null,
          ),
          const SizedBox(height: Gap.md),
          _PlanCard(
            name: 'Pro',
            price: 'Rp49.000',
            period: 'per bulan',
            features: const [
              'Perangkat tanpa batas',
              'Kualitas video tinggi',
              'Preset kontrol tersimpan',
              'Prioritas relay region',
            ],
            featured: true,
            onTap: () => _comingSoon(context),
          ),
          const SizedBox(height: Gap.md),
          _PlanCard(
            name: 'Studio',
            price: 'Rp129.000',
            period: 'per bulan',
            features: const [
              'Semua fitur Pro',
              'Multi-user host',
              'Audit session',
              'Dukungan prioritas',
            ],
            onTap: () => _comingSoon(context),
          ),
          const SizedBox(height: Gap.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.shieldCheck, size: 15, color: c.textLow),
              const SizedBox(width: 6),
              Text(
                'Pembayaran aman dan dapat dibatalkan kapan saja',
                style: TextStyle(fontSize: 10.5, color: c.textLow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    required this.onTap,
    this.current = false,
    this.featured = false,
  });

  final String name;
  final String price;
  final String period;
  final List<String> features;
  final VoidCallback? onTap;
  final bool current;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const accent = Color(0xFF9B5CFF);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: featured
            ? BoxDecoration(
                border: Border.all(color: accent.withValues(alpha: 0.65)),
                borderRadius: BorderRadius.circular(R.md),
              )
            : null,
        padding: featured ? const EdgeInsets.all(12) : EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: c.textHi,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (featured) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'POPULER',
                      style: TextStyle(
                        color: Color(0xFFB987FF),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (current)
                  Text(
                    'AKTIF',
                    style: TextStyle(
                      color: c.textLow,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    color: featured ? const Color(0xFFB987FF) : c.textHi,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    period,
                    style: TextStyle(fontSize: 10.5, color: c.textLow),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final feature in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.check,
                      size: 14,
                      color: featured ? accent : c.textMid,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      feature,
                      style: TextStyle(fontSize: 11.5, color: c.textMid),
                    ),
                  ],
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  style: featured
                      ? FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(R.lg),
                          ),
                        )
                      : null,
                  child: Text('Pilih $name'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
