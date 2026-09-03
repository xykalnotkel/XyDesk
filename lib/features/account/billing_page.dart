//! Billing — Sewa PC XyDesk.
//!
//! Halaman ini menampilkan paket sewa PC (bayar per jam) dan pemesanan
//! via WhatsApp. Keputusan produk & harga oleh operator:
//!   - Reguler: Rp 5.000 / jam
//!   - Gaming:  Rp 8.000 / jam
//!   - Pro:     Rp 12.000 / jam
//!
//! Pembayaran otomatis (QRIS) belum aktif — pesanan dikonfirmasi manual
//! lewat WhatsApp. Halaman ini TIDAK berpura-pura punya pembayaran otomatis.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tokens.dart';
import '../../widgets/seamless.dart';

/// Nomor WhatsApp pemesanan (format internasional tanpa +).
const _orderWa = '6283116632566';

/// Paket sewa PC.
class _Paket {
  const _Paket({
    required this.id,
    required this.nama,
    required this.hargaPerJam,
    required this.ringkas,
    required this.spesifikasi,
    this.unggulan = false,
  });

  final String id;
  final String nama;
  final int hargaPerJam;
  final String ringkas;
  final List<String> spesifikasi;
  final bool unggulan;
}

const _pakets = <_Paket>[
  _Paket(
    id: 'reguler',
    nama: 'Reguler',
    hargaPerJam: 5000,
    ringkas: 'Buat kerja, browsing, dan game ringan.',
    spesifikasi: ['PC warnet standar', 'Game populer terpasang', 'Simpanan sesi aman'],
  ),
  _Paket(
    id: 'gaming',
    nama: 'Gaming',
    hargaPerJam: 8000,
    ringkas: 'Buat game kompetitif dengan frame stabil.',
    spesifikasi: ['GPU kelas gaming', 'Monitor refresh tinggi', 'Game AAA siap main'],
    unggulan: true,
  ),
  _Paket(
    id: 'pro',
    nama: 'Pro',
    hargaPerJam: 12000,
    ringkas: 'Buat streaming, render, dan game berat.',
    spesifikasi: ['GPU + CPU tertinggi', 'RAM lega untuk multitask', 'Prioritas bandwidth'],
  ),
];

const _durasi = [1, 2, 3, 5, 10];
const _maksJam = 24;

/// Stok unit tiap paket — angka operator.
const _stok = <String, int>{
  'reguler': 6,
  'gaming': 4,
  'pro': 2,
};

String _rupiah(int n) => 'Rp ${n.toString().replaceAllMapped(
  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]}.',
)}';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  String _paketId = 'gaming';
  int _jam = 1;
  final _jamCustomCtrl = TextEditingController();

  _Paket get _paket {
    return _pakets.firstWhere(
      (p) => p.id == _paketId && (_stok[p.id] ?? 0) > 0,
      orElse: () => _pakets.firstWhere(
        (p) => (_stok[p.id] ?? 0) > 0,
        orElse: () => _pakets.first,
      ),
    );
  }

  int get _total => _paket.hargaPerJam * _jam;

  @override
  void dispose() {
    _jamCustomCtrl.dispose();
    super.dispose();
  }

  void _pilihPaket(String id) {
    if ((_stok[id] ?? 0) <= 0) return;
    setState(() => _paketId = id);
  }

  void _pilihDurasi(int d) {
    setState(() {
      _jam = d;
      _jamCustomCtrl.clear();
    });
  }

  void _isiDurasiCustom(String value) {
    final n = int.tryParse(value);
    if (n != null && n >= 1 && n <= _maksJam) {
      setState(() => _jam = n);
    }
  }

  Future<void> _pesan() async {
    final pesan = 'Halo XySpace! Mau sewa PC:\n'
        '- Paket: ${_paket.nama}\n'
        '- Durasi: $_jam jam\n'
        '- Total: ${_rupiah(_total)}';
    final uri = Uri.parse(
      'https://wa.me/$_orderWa?text=${Uri.encodeComponent(pesan)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final paket = _paket;
    final stokPaket = _stok[paket.id] ?? 0;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Sewa PC'),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: c.textMid),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.screen, 8, Gap.screen, 40),
        children: [
          // Header
          Text(
            'SEWA PC',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: c.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Main di PC kencang, bayar per jam.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: c.textHi,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak punya PC gaming? Sewa punya kami. Kamu terima ID + '
            'password, konek lewat XyDesk dari HP, dan PC-nya jadi '
            'milikmu selama durasi berjalan.',
            style: TextStyle(fontSize: 12.5, color: c.textMid, height: 1.5),
          ),
          const SizedBox(height: Gap.xxl),

          // ── Paket ──
          for (final p in _pakets) ...[
            _PaketCard(
              paket: p,
              selected: p.id == paket.id,
              stok: _stok[p.id] ?? 0,
              onTap: () => _pilihPaket(p.id),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: Gap.lg),

          // ── Durasi ──
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PILIH DURASI',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
                    color: c.textLow,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in _durasi)
                      _DurasiChip(
                        label: '$d jam',
                        selected: d == _jam && _jamCustomCtrl.text.isEmpty,
                        onTap: () => _pilihDurasi(d),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Custom durasi.
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _jamCustomCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: _isiDurasiCustom,
                    style: TextStyle(fontSize: 14, color: c.textHi),
                    decoration: InputDecoration(
                      hintText: 'Custom',
                      isDense: true,
                      suffixText: 'jam',
                      suffixStyle: TextStyle(fontSize: 11, color: c.textLow),
                      constraints: const BoxConstraints(minHeight: 44),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),

                // Ringkasan.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.input.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(R.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paket ${paket.nama} · $_jam jam',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.textHi,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_rupiah(paket.hargaPerJam)} × $_jam',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textLow,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _rupiah(_total),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),

                // Tombol pesan.
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: stokPaket > 0 ? _pesan : null,
                    icon: const Icon(LucideIcons.messageCircle, size: 18),
                    label: Text(
                      stokPaket > 0 ? 'Pesan via WhatsApp' : 'Stok habis',
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
                Text(
                  'Pembayaran otomatis (QRIS) sedang disiapkan — untuk '
                  'sekarang pesanan dikonfirmasi manual oleh tim, biasanya '
                  'dalam hitungan menit pada jam operasional.',
                  style: TextStyle(fontSize: 11, color: c.textLow, height: 1.45),
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.xxl),

          // ── Cara kerjanya ──
          Text(
            'CARA KERJANYA',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
              color: c.textLow,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _langkah.length; i++) ...[
            _LangkahItem(
              nomor: i + 1,
              judul: _langkah[i].$1,
              deskripsi: _langkah[i].$2,
            ),
            if (i < _langkah.length - 1) const SizedBox(height: 14),
          ],

          const SizedBox(height: Gap.xxl),

          // ── Beli PC ──
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mau sekalian beli PC?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kami juga merakit PC sesuai budget — konsultasi spek '
                  'gratis, garansi toko, dan XyDesk Host terpasang siap '
                  'remote dari hari pertama.',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textMid,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: Gap.md),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _pesan,
                    icon: const Icon(LucideIcons.messageCircle, size: 16),
                    label: const Text('Konsultasi via WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: c.accent.withValues(alpha: 0.5),
                      ),
                      foregroundColor: c.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _langkah = <(String, String)>[
  (
    'Pilih paket & durasi',
    'Tentukan spek PC dan berapa lama kamu main — mulai dari 1 jam.',
  ),
  (
    'Bayar',
    'Selesaikan pembayaran lewat WhatsApp (QRIS otomatis menyusul).',
  ),
  (
    'Terima akses',
    'Kamu dikirimi ID + password XyDesk dan kode billing untuk PC-nya.',
  ),
  (
    'Konek & main',
    'Masuk lewat halaman Connect. Saat menebus kode billing, masukkan 4 digit terakhir nomor WhatsApp kamu.',
  ),
];

class _PaketCard extends StatelessWidget {
  const _PaketCard({
    required this.paket,
    required this.selected,
    required this.stok,
    required this.onTap,
  });

  final _Paket paket;
  final bool selected;
  final int stok;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final habis = stok <= 0;

    return Material(
      color: c.raised,
      borderRadius: BorderRadius.circular(R.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: habis ? null : onTap,
        borderRadius: BorderRadius.circular(R.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? c.accent
                  : c.textLow.withValues(alpha: 0.15),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(R.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      paket.nama,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textHi,
                      ),
                    ),
                  ),
                  if (paket.unggulan && !habis)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(R.pill),
                      ),
                      child: Text(
                        'LARIS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: c.accent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${_rupiah(paket.hargaPerJam)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: selected ? c.accent : c.textHi,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ jam',
                    style: TextStyle(fontSize: 12, color: c.textLow),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                paket.ringkas,
                style: TextStyle(fontSize: 12, color: c.textMid, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                habis ? 'Stok habis' : '$stok unit tersedia',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: habis ? c.dangerText : c.textLow,
                ),
              ),
              if (!habis) ...[
                const SizedBox(height: 8),
                for (final spec in paket.spesifikasi) ...[
                  Row(
                    children: [
                      Icon(
                        LucideIcons.check,
                        size: 13,
                        color: c.accent.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          spec,
                          style: TextStyle(fontSize: 11.5, color: c.textMid),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DurasiChip extends StatelessWidget {
  const _DurasiChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.accent : c.input,
      borderRadius: BorderRadius.circular(R.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : c.textMid,
            ),
          ),
        ),
      ),
    );
  }
}

class _LangkahItem extends StatelessWidget {
  const _LangkahItem({
    required this.nomor,
    required this.judul,
    required this.deskripsi,
  });

  final int nomor;
  final String judul;
  final String deskripsi;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$nomor',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                judul,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textHi,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                deskripsi,
                style: TextStyle(
                  fontSize: 11.5,
                  color: c.textMid,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
