import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n_bridge.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import '../devices/device_model.dart';
import '../devices/history_page.dart';
import 'guide_page.dart';
import '../session/session_page.dart';

/// Memformat ID jadi "123 456 789" sambil user mengetik.
class DeviceIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 9 ? digits.substring(0, 9) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 3 || i == 6) buf.write(' ');
      buf.write(capped[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Link dukungan — ganti dengan akun/resmi XyDesk kamu.
const _kTelegram = 'https://t.me/xydesk';
const _kTelegramApp = 'tg://resolve?domain=xydesk';
const _kWhatsApp = 'https://whatsapp.com/channel/0029VbB7nwuJZg3ym6UQ4Z1L';
const _kTikTok = 'https://tiktok.com/@xydesk';
const _kTikTokApp = 'snssdk1233://user/profile/xydesk';

Future<void> _launchSocial(String url, {String? appUrl}) async {
  if (appUrl != null) {
    final native = Uri.parse(appUrl);
    if (await canLaunchUrl(native)) {
      await launchUrl(native, mode: LaunchMode.externalApplication);
      return;
    }
  }
  final web = Uri.parse(url);
  if (await canLaunchUrl(web)) {
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }
}

class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> {
  static const _recentsKey = 'connect_recents';
  static const _recentsMax = 5;

  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  bool _remember = false;
  bool _recentsOpen = false;
  String? _error;

  bool get _valid =>
      _id.text.replaceAll(' ', '').length == 9 && _pw.text.isNotEmpty;

  List<Map<String, dynamic>> get _recents =>
      ref.read(storeProvider).getList(_recentsKey);

  /// Simpan pasangan ID+kata sandi ke riwayat (terbaru di depan, maks 5).
  /// Kenyamanan lokal perangkat — bukan sinkron akun.
  Future<void> _saveRecent(String id, String pw) async {
    final store = ref.read(storeProvider);
    final list = store.getList(_recentsKey)
      ..removeWhere((e) => e['id'] == id)
      ..insert(0, {
        'id': id,
        'pw': pw,
        'at': DateTime.now().millisecondsSinceEpoch,
      });
    await store.setList(_recentsKey, list.take(_recentsMax).toList());
  }

  @override
  void initState() {
    super.initState();
    _id.addListener(() => setState(() {}));
    _pw.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_valid) return;
    // Demo: kata sandi "salah" memicu state error agar bisa dilihat di UI.
    if (_pw.text == 'salah') {
      setState(() => _error = null);
      await _showConnectError(
        'Koneksi gagal',
        'Kata sandi salah. Sisa 3 percobaan sebelum dikunci 5 menit.',
      );
      return;
    }
    setState(() => _error = null);

    final id = _id.text.replaceAll(' ', '');
    await _saveRecent(id, _pw.text);
    final device = await ref
        .read(deviceRepoProvider.notifier)
        .connect(id: id, name: _demoName(id), remembered: _remember);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PairSuccessPage(device: device, password: _pw.text),
      ),
    );
  }

  Future<void> _showConnectError(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _demoName(String id) {
    switch (id) {
      case '123456789':
        return 'XYCLOUD-RTX4090-01';
      case '234567890':
        return 'XYCLOUD-RTX4080-02';
      case '345678901':
        return 'XYCLOUD-PRO-WORK-01';
      case '456789012':
        return 'XYCLOUD-ESPORT-360HZ';
      default:
        return 'PC-${id.substring(id.length - 4)}';
    }
  }

  Future<void> _scanQr() async {
    final id = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanDemoPage()));
    if (!mounted || id == null) return;
    _id.text = id;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('QR berhasil dipindai.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 44,
        bottom: 120,
      ),
      children: [
        Text(context.tr('connect_title'), style: t.headlineMedium),
        const SizedBox(height: 7),
        Text(
          'Masukkan ID dan kata sandi dari aplikasi host di PC kamu.',
          style: TextStyle(fontSize: 12.5, color: c.textMid, height: 1.5),
        ),
        const SizedBox(height: Gap.xxl),
        Row(
          children: [
            Expanded(child: _label('ID Perangkat')),
            if (_recents.isNotEmpty)
              InkWell(
                onTap: () => setState(() => _recentsOpen = !_recentsOpen),
                borderRadius: BorderRadius.circular(R.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(
                      alpha: _recentsOpen ? 0.28 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(R.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.history, size: 13, color: c.accent),
                      const SizedBox(width: 5),
                      Text(
                        'Riwayat',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_recentsOpen) ...[
          const SizedBox(height: 6),
          _RecentsList(
            entries: _recents,
            onPick: (id, pw) {
              _id.text = _prettify(id);
              _pw.text = pw;
              setState(() => _recentsOpen = false);
            },
            onClear: () async {
              await ref.read(storeProvider).setList(_recentsKey, []);
              setState(() => _recentsOpen = false);
            },
          ),
          const SizedBox(height: 6),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: TextField(
            controller: _id,
            keyboardType: TextInputType.number,
            inputFormatters: [DeviceIdFormatter()],
            // Rata kiri — konsisten dengan kolom kata sandi di bawahnya.
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: c.textHi,
              // Angka tabular supaya digit tidak bergoyang saat diketik.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            // Sengaja tanpa hintText: angka contoh membuat kolom terlihat
            // sudah terisi dan mengganggu saat mengetik.
            decoration: const InputDecoration(),
          ),
        ),
        const SizedBox(height: Gap.lg),
        _label('Kata sandi'),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: TextField(
            controller: _pw,
            obscureText: _obscure,
            textAlignVertical: TextAlignVertical.center,
            onSubmitted: (_) => _connect(),
            decoration: InputDecoration(
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                  size: 17,
                  color: c.textLow,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        InkWell(
          onTap: () => setState(() => _remember = !_remember),
          borderRadius: BorderRadius.circular(R.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: D.fast,
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _remember ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: _remember
                        ? null
                        : Border.all(
                            color: c.textLow.withValues(alpha: 0.55),
                            width: 1.5,
                          ),
                  ),
                  child: _remember
                      ? const Icon(
                          LucideIcons.check,
                          size: 12,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  context.tr('connect_remember'),
                  style: TextStyle(fontSize: 12, color: c.textMid),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        FilledButton(
          onPressed: _valid ? _connect : null,
          child: Text(context.tr('connect_btn')),
        ),
        const SizedBox(height: Gap.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _pill(context, LucideIcons.scanLine, 'Pindai QR', () => _scanQr()),
            const SizedBox(width: Gap.h32),
            _pill(
              context,
              LucideIcons.history,
              'Riwayat',
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryPage())),
            ),
          ],
        ),
        const SizedBox(height: Gap.xxl),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Belum tahu caranya?',
                style: TextStyle(fontSize: 11.5, color: c.textLow),
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const GuidePage())),
                child: const Text('Ke sini'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        const _SupportBlock(),
      ],
    );
  }

  /// "123456789" -> "123 456 789" untuk ditampilkan kembali di kolom ID.
  static String _prettify(String id) {
    final d = id.replaceAll(RegExp(r'\D'), '');
    if (d.length != 9) return id;
    return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 6),
    child: Text(
      s,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: context.c.textMid,
      ),
    ),
  );

  Widget _pill(
    BuildContext context,
    IconData i,
    String s,
    VoidCallback? onTap,
  ) {
    final c = context.c;
    return Material(
      color: c.input,
      borderRadius: BorderRadius.circular(R.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(i, size: 15, color: c.textMid),
              const SizedBox(width: 7),
              Text(s, style: TextStyle(fontSize: 12.5, color: c.textMid)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daftar riwayat koneksi: ketuk untuk mengisi ID + kata sandi sekaligus.
class _RecentsList extends StatelessWidget {
  const _RecentsList({
    required this.entries,
    required this.onPick,
    required this.onClear,
  });

  final List<Map<String, dynamic>> entries;
  final void Function(String id, String pw) onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.input,
        borderRadius: BorderRadius.circular(R.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in entries)
            InkWell(
              onTap: () => onPick(e['id'] as String, e['pw'] as String? ?? ''),
              borderRadius: BorderRadius.circular(R.pill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.monitor, size: 15, color: c.textMid),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _ConnectPageState._prettify(e['id'] as String),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: c.textHi,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      'sandi tersimpan',
                      style: TextStyle(fontSize: 10.5, color: c.textLow),
                    ),
                  ],
                ),
              ),
            ),
          TextButton(onPressed: onClear, child: const Text('Hapus riwayat')),
        ],
      ),
    );
  }
}

/// Layar scanner QR mockup. Kamera/server belum dibutuhkan di fase UI.
class QrScanDemoPage extends StatelessWidget {
  const QrScanDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Pindai QR'),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: c.textMid),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.screen, 8, Gap.screen, 32),
        children: [
          const SizedBox(height: Gap.lg),
          const Center(child: Illus(Img.qrScan, size: 260)),
          const SizedBox(height: Gap.lg),
          Text(
            'Arahkan kamera ke QR host',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.textHi,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Di versi demo, tombol di bawah mensimulasikan QR berhasil dibaca.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textMid),
          ),
          const SizedBox(height: Gap.xxl),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, '987654321'),
            icon: const Icon(LucideIcons.scanLine, size: 18),
            label: const Text('Simulasikan QR berhasil'),
          ),
        ],
      ),
    );
  }
}

/// Konfirmasi pairing sebelum masuk ke layar session.
class PairSuccessPage extends StatelessWidget {
  const PairSuccessPage({super.key, required this.device, this.password = ''});

  final Device device;

  /// Password pairing yang dimasukkan pengguna — diteruskan ke SessionPage
  /// agar host dapat memverifikasinya saat transport dimulai.
  final String password;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.screen, 24, Gap.screen, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(LucideIcons.arrowLeft, color: c.textMid),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: Gap.lg),
            const Center(child: Illus(Img.pairSuccess, size: 250)),
            const SizedBox(height: Gap.lg),
            Text(
              'Perangkat terhubung',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              '${device.name} siap digunakan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textMid),
            ),
            const SizedBox(height: Gap.xxl),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => SessionPage(
                    deviceName: device.name,
                    deviceId: device.id,
                    password: password,
                  ),
                ),
              ),
              child: const Text('Mulai sesi'),
            ),
            const SizedBox(height: Gap.md),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nanti saja'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blok "Dukung kami di" — Telegram, WhatsApp, TikTok (logo resmi).
class _SupportBlock extends StatelessWidget {
  const _SupportBlock();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Text(
          'Dukung kami di',
          style: TextStyle(fontSize: 11.5, color: c.textLow),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialTile(
              asset: 'assets/libraryicons/social_telegram.webp',
              url: _kTelegram,
              appUrl: _kTelegramApp,
              label: 'Telegram',
            ),
            SizedBox(width: 12),
            _SocialTile(
              asset: 'assets/libraryicons/social_whatsapp.webp',
              url: _kWhatsApp,
              label: 'WhatsApp',
            ),
            SizedBox(width: 12),
            _SocialTile(
              asset: 'assets/libraryicons/social_tiktok.webp',
              url: _kTikTok,
              appUrl: _kTikTokApp,
              label: 'TikTok',
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({
    required this.asset,
    required this.url,
    this.appUrl,
    required this.label,
  });

  final String asset;
  final String url;
  final String? appUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: label,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(color: c.textLow.withValues(alpha: 0.16)),
        ),
        child: Material(
          color: c.raised,
          borderRadius: BorderRadius.circular(R.lg),
          child: InkWell(
            onTap: () => _launchSocial(url, appUrl: appUrl),
            borderRadius: BorderRadius.circular(R.lg),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
