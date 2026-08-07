import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../session/session_page.dart';

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
        Text('Hubungkan ke perangkat', style: t.headlineMedium),
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
            hintText: '123 456 789',
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
        const SizedBox(height: Gap.lg),
        _label('Kata sandi'),
        TextField(
          controller: _pw,
          obscureText: _obscure,
          onSubmitted: (_) => _connect(),
          decoration: InputDecoration(
            hintText: '••••••',
            errorText: _error,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
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
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _remember ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: _remember
                        ? null
                        : Border.all(
                            color: const Color(0xFF3A3A3E), width: 1.5),
                  ),
                  child: _remember
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: Gap.sm),
                Text('Ingat perangkat ini',
                    style: TextStyle(fontSize: 12, color: c.textMid)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        FilledButton(
          onPressed: _valid ? _connect : null,
          child: const Text('Hubungkan'),
        ),
        const SizedBox(height: Gap.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ghost(context, Icons.qr_code_scanner_rounded, 'Pindai QR'),
            const SizedBox(width: Gap.h32),
            _ghost(context, Icons.history_rounded, 'Riwayat'),
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

  Widget _ghost(BuildContext context, IconData i, String s) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 14, color: context.c.textMid),
          const SizedBox(width: 6),
          Text(s, style: TextStyle(fontSize: 12.5, color: context.c.textMid)),
        ],
      );
}

/// Blok "Dukung kami di" — Telegram, Saluran WhatsApp, TikTok.
class _SupportBlock extends StatelessWidget {
  const _SupportBlock();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Text('Dukung kami di',
            style: TextStyle(fontSize: 11.5, color: c.textLow)),
        const SizedBox(height: 11),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialTile(icon: Icons.send_rounded, label: 'Telegram'),
            SizedBox(width: 9),
            _SocialTile(
                icon: Icons.chat_bubble_outline_rounded, label: 'WhatsApp'),
            SizedBox(width: 9),
            _SocialTile(icon: Icons.music_note_rounded, label: 'TikTok'),
          ],
        ),
      ],
    );
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: c.input,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 42,
            height: 42,
            // Ikon monokrom — tanpa warna brand, agar palet tetap tenang.
            child: Icon(icon, size: 18, color: c.textMid),
          ),
        ),
      ),
    );
  }
}
