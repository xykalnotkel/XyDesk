import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/seamless.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 56,
        bottom: 110,
      ),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: c.raised, shape: BoxShape.circle),
              child: Text('R',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textMid)),
            ),
            const SizedBox(width: Gap.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rizky Maulana',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textHi)),
                const SizedBox(height: 2),
                Text('rizky@mail.com',
                    style: TextStyle(fontSize: 11.5, color: c.textLow)),
              ],
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.crown, size: 15, color: c.accent),
                  const SizedBox(width: Gap.sm),
                  Text('Pro',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: c.textHi)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Diperpanjang 12 Sep 2026 · Rp 59.000/bln',
                  style: TextStyle(fontSize: 11, color: c.textLow)),
              const SizedBox(height: 11),
              Text('Kelola langganan',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.accent)),
            ],
          ),
        ),
        const SectionLabel('Preferensi'),
        ListRow(
            title: 'Tampilan',
            icon: LucideIcons.moon,
            value: 'Gelap',
            trailing: _chev(context)),
        ListRow(
            title: 'Notifikasi',
            icon: LucideIcons.bell,
            trailing: _chev(context)),
        ListRow(
            title: 'Keamanan',
            icon: LucideIcons.lock,
            value: '2FA aktif',
            trailing: _chev(context)),
        // Izin bisa dicabut dari dalam aplikasi, tanpa masuk setelan OS.
        ListRow(
            title: 'Izin aplikasi',
            icon: LucideIcons.shield,
            value: '3 aktif',
            trailing: _chev(context)),
        const SectionLabel('Lainnya'),
        ListRow(
            title: 'Bantuan & FAQ',
            icon: LucideIcons.info,
            trailing: _chev(context)),
        ListRow(
          title: 'Tentang',
          icon: LucideIcons.fileText,
          value: 'v1.0.0',
          trailing: _chev(context),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AboutPage()),
          ),
        ),
        const ListRow(title: 'Keluar', icon: LucideIcons.logOut, danger: true),
      ],
    );
  }

  Widget _chev(BuildContext context) =>
      Icon(LucideIcons.chevronRight, size: 16, color: context.c.textLow);
}

/// Halaman Tentang — sering dilupakan, padahal penting untuk dukungan.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SeamlessScaffold(
      title: 'Tentang',
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 56,
          bottom: 40,
        ),
        children: [
          Column(
            children: [
              const BrandLogo(size: 66),
              const SizedBox(height: 9),
              Text('XyDesk',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.textHi)),
              const SizedBox(height: 4),
              Text('Versi 1.0.0 · Build 1 · arm64',
                  style: TextStyle(fontSize: 11.5, color: c.textLow)),
              const SizedBox(height: 9),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('Aplikasi sudah terbaru',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: c.accent)),
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          const ListRow(
              title: 'Catatan rilis',
              subtitle: 'Apa yang baru di 1.0.0',
              icon: LucideIcons.list),
          const ListRow(
              title: 'Cek pembaruan',
              subtitle: 'Terakhir dicek 2 jam lalu',
              icon: LucideIcons.refreshCw),
          const SectionLabel('Legal'),
          const ListRow(title: 'Ketentuan layanan', icon: LucideIcons.fileText),
          const ListRow(title: 'Kebijakan privasi', icon: LucideIcons.shield),
          const ListRow(
              title: 'Lisensi sumber terbuka', icon: LucideIcons.code),
          const SectionLabel('Diagnostik'),
          // ID yang bisa disalin ini membuat laporan bug bisa ditelusuri
          // di log server — fitur dukungan termurah yang bisa dibangun.
          ListRow(
            title: 'Salin ID diagnostik',
            subtitle: 'a7f3-9c21-4e88',
            icon: LucideIcons.key,
            trailing: Icon(LucideIcons.copy, size: 15, color: c.textLow),
          ),
          const ListRow(
              title: 'Kirim log ke dukungan', icon: LucideIcons.upload),
        ],
      ),
    );
  }
}
