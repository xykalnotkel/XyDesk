import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tokens.dart';
import '../../widgets/seamless.dart';
import 'billing_page.dart';

/// Halaman Langganan — menampilkan status keanggotaan dan riwayat billing.
///
/// Ini BUKAN halaman Sewa PC (BillingPage). Halaman ini untuk:
/// - Melihat status keanggotaan saat ini
/// - Riwayat sesi yang pernah disewa
/// - Status pembayaran aktif
/// - Link ke halaman Sewa PC untuk menambah sesi
class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

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
        padding: const EdgeInsets.fromLTRB(Gap.screen, 8, Gap.screen, 40),
        children: [
          // Status keanggotaan
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(R.md),
                      ),
                      child: Icon(LucideIcons.crown, size: 24, color: c.accent),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Free Plan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.textHi,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Anggota sejak Sep 2026',
                            style: TextStyle(fontSize: 12, color: c.textMid),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(R.md),
                    border: Border.all(color: c.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.checkCircle, size: 20, color: c.success),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Akses penuh ke fitur inti',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.successText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Remote desktop, streaming, kontrol penuh',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: c.textMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.xxl),

          // Riwayat Sewa PC
          Text(
            'RIWAYAT SEWA PC',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: c.textLow,
            ),
          ),
          const SizedBox(height: Gap.md),

          // Empty state - belum ada riwayat
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Column(
              children: [
                Icon(
                  LucideIcons.inbox,
                  size: 48,
                  color: c.textLow.withValues(alpha: 0.3),
                ),
                const SizedBox(height: Gap.md),
                Text(
                  'Belum ada riwayat sewa',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textMid,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Sewa PC untuk pertama kali dan nikmati akses remote\n'
                  'ke PC gaming berkualitas tinggi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.textLow, height: 1.5),
                ),
                const SizedBox(height: Gap.lg),
                SizedBox(
                  width: 200,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BillingPage()),
                      );
                    },
                    icon: const Icon(LucideIcons.monitor, size: 18),
                    label: const Text('Sewa PC Sekarang'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.xxl),

          // Benefit member
          Text(
            'BENEFIT MEMBER',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: c.textLow,
            ),
          ),
          const SizedBox(height: Gap.md),

          const _BenefitItem(
            icon: LucideIcons.monitor,
            title: 'Remote Desktop',
            description: 'Akses PC dari mana saja lewat XyDesk',
            active: true,
          ),
          const _BenefitItem(
            icon: LucideIcons.gamepad2,
            title: 'Gaming Mode',
            description: 'Kontrol gaming dengan D-pad & button mapping',
            active: true,
          ),
          const _BenefitItem(
            icon: LucideIcons.volume2,
            title: 'Audio Streaming',
            description: 'Dengar audio dari PC secara real-time',
            active: true,
          ),
          const _BenefitItem(
            icon: LucideIcons.mic,
            title: 'Microphone Passthrough',
            description: 'Gunakan mic HP untuk chat di PC',
            active: true,
          ),
          const _BenefitItem(
            icon: LucideIcons.zap,
            title: 'Low Latency',
            description: 'Streaming <40ms untuk gaming kompetitif',
            active: true,
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
    this.active = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(
          color: active
              ? c.success.withValues(alpha: 0.3)
              : c.textLow.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? c.success.withValues(alpha: 0.12)
                  : c.textLow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(R.md),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? c.successText : c.textLow,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textHi,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Icon(LucideIcons.check, size: 14, color: c.success),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(fontSize: 11.5, color: c.textMid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
