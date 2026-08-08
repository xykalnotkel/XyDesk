import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n_bridge.dart';
import '../../core/tokens.dart';
import '../session/session_page.dart';
import '../devices/history_page.dart';

/// Memformat ID jadi "123 456 789" sambil user mengetik.
class DeviceIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue neu) {
    final digits = neu.text.replaceAll(RegExp(r'\D'), '');
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
const _kWhatsApp = 'https://wa.me/628000000000';
const _kTikTok = 'https://tiktok.com/@xydesk';

Future<void> _launchSocial(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  bool _remember = false;
  String? _error;

  bool get _valid =>
      _id.text.replaceAll(' ', '').length == 9 && _pw.text.isNotEmpty;

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

  void _connect() {
    if (!_valid) return;
    // Demo: kata sandi "salah" memicu state error agar bisa dilihat di UI.
    if (_pw.text == 'salah') {
      setState(() => _error =
          'Kata sandi salah. Sisa 3 percobaan sebelum dikunci 5 menit.');
      return;
    }
    setState(() => _error = null);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SessionPage(deviceName: 'GAMING-RIG', deviceId: _id.text),
      ),
    );
  }

  void _scanQr() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pindai QR akan hadir.')),
    );
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
        _label('ID Perangkat'),
        TextField(
          controller: _id,
          keyboardType: TextInputType.number,
          inputFormatters: [DeviceIdFormatter()],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: c.textHi,
            // Angka tabular supaya digit tidak bergoyang saat diketik.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: const InputDecoration(
            // Sengaja tanpa hintText: angka contoh membuat kolom terlihat
            // sudah terisi dan mengganggu saat mengetik.
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          ),
        ),
        const SizedBox(height: Gap.lg),
        _label('Kata sandi'),
        TextField(
          controller: _pw,
          obscureText: _obscure,
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
                            color: const Color(0xFF3A3A3E), width: 1.5),
                  ),
                  child: _remember
                      ? const Icon(LucideIcons.check,
                          size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: Gap.sm),
                Text(context.tr('connect_remember'),
                    style: TextStyle(fontSize: 12, color: c.textMid)),
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
            _pill(context, LucideIcons.scanLine, 'Pindai QR', _scanQr),
            const SizedBox(width: Gap.h32),
            _pill(
              context,
              LucideIcons.history,
              'Riwayat',
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xxl),
        const _SupportBlock(),
      ],
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(s,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: context.c.textMid)),
      );

  Widget _pill(
          BuildContext context, IconData i, String s, VoidCallback? onTap) {
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

/// Blok "Dukung kami di" — Telegram, WhatsApp, TikTok (logo resmi).
class _SupportBlock extends StatelessWidget {
  const _SupportBlock();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Text('Dukung kami di',
            style: TextStyle(fontSize: 11.5, color: c.textLow)),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialTile(
                asset: 'assets/libraryicons/social_telegram.png',
                url: _kTelegram,
                label: 'Telegram'),
            SizedBox(width: 12),
            _SocialTile(
                asset: 'assets/libraryicons/social_whatsapp.png',
                url: _kWhatsApp,
                label: 'WhatsApp'),
            SizedBox(width: 12),
            _SocialTile(
                asset: 'assets/libraryicons/social_tiktok.png',
                url: _kTikTok,
                label: 'TikTok'),
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
    required this.label,
  });

  final String asset;
  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(R.lg),
          child: InkWell(
            onTap: () => _launchSocial(url),
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
