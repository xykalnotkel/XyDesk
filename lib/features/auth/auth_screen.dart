import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/devlog.dart';
import '../../core/l10n_bridge.dart';
import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';
import 'legal_page.dart';

/// Layar masuk: Google atau Email + OTP.
///
/// Verifikasi OTP di sini masih tiruan (kode apa pun 6 digit diterima,
/// dan kode contoh dicetak ke DevLog). Alurnya sudah lengkap sehingga
/// tinggal menyambungkan ke backend nanti tanpa mengubah UI.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _emailMode = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: D.panel,
          switchInCurve: D.curve,
          child: _emailMode
              ? _EmailStep(
                  key: const ValueKey('email'),
                  onBack: () => setState(() => _emailMode = false),
                )
              : _buildChoice(context, c),
        ),
      ),
    );
  }

  Widget _buildChoice(BuildContext context, AppPalette c) {
    return ListView(
      key: const ValueKey('choice'),
      padding: const EdgeInsets.fromLTRB(Gap.screen, 0, Gap.screen, Gap.xxl),
      children: [
        const SizedBox(height: Gap.h32),
        Center(
          child: Image.asset(Img.auth,
              width: 168,
              height: 168,
              errorBuilder: (_, __, ___) => const SizedBox(height: 168)),
        ),
        const SizedBox(height: Gap.xl),
        Text(context.tr('auth_welcome'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w600, color: c.textHi)),
        const SizedBox(height: Gap.sm),
        Text(context.tr('auth_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.55, color: c.textMid)),
        const SizedBox(height: Gap.h32),
        _AuthButton(
          icon: LucideIcons.globe,
          label: context.tr('auth_google'),
          primary: true,
          busy: _busy,
          onTap: _signInGoogle,
        ),
        const SizedBox(height: Gap.md),
        _AuthButton(
          icon: LucideIcons.mail,
          label: context.tr('auth_email'),
          onTap: () => setState(() => _emailMode = true),
        ),
        const SizedBox(height: Gap.lg),
        Center(
          child: TextButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).signInGuest();
            },
            child: Text(context.tr('auth_guest')),
          ),
        ),
        const SizedBox(height: Gap.xxl),
        const _LegalNote(),
      ],
    );
  }

  Future<void> _signInGoogle() async {
    setState(() => _busy = true);
    DevLog.i('auth', 'Mulai masuk dengan Google');
    // Tiruan: penundaan singkat agar keadaan sibuk terlihat.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await ref
        .read(authProvider.notifier)
        .signInEmail('pengguna@gmail.com', name: 'Pengguna XyDesk');
    DevLog.w('auth', 'Google Sign-In masih tiruan',
        'Sambungkan google_sign_in + Firebase untuk produksi');
  }
}

/// Langkah masukkan email lalu OTP.
class _EmailStep extends ConsumerStatefulWidget {
  const _EmailStep({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<_EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends ConsumerState<_EmailStep> {
  final _email = TextEditingController();
  final _otp = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());

  bool _otpSent = false;
  bool _busy = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;
  String _sentCode = '';

  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    for (final c in _otp) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    final e = _email.text.trim();
    if (!_emailRe.hasMatch(e)) {
      setState(() => _error = context.tr('auth_invalid_email'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // Kode tiruan; dicetak ke DevLog supaya bisa diuji tanpa email nyata.
    _sentCode = '123456';
    DevLog.ok('auth', 'Kode OTP dikirim (tiruan)', 'ke $e — kode: $_sentCode');

    setState(() {
      _busy = false;
      _otpSent = true;
    });
    _startCooldown();
    _otpFocus.first.requestFocus();
  }

  Future<void> _verify() async {
    final code = _otp.map((c) => c.text).join();
    if (code.length < 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    if (code != _sentCode) {
      setState(() {
        _busy = false;
        _error = context.tr('auth_invalid_otp');
      });
      DevLog.w('auth', 'Kode OTP salah', 'dimasukkan: $code');
      for (final c in _otp) {
        c.clear();
      }
      _otpFocus.first.requestFocus();
      return;
    }
    await ref.read(authProvider.notifier).signInEmail(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.screen, 0, Gap.screen, Gap.xxl),
      children: [
        const SizedBox(height: Gap.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.textMid),
            onPressed: _otpSent
                ? () => setState(() {
                      _otpSent = false;
                      _error = null;
                    })
                : widget.onBack,
          ),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          _otpSent ? context.tr('auth_otp_title') : context.tr('auth_email'),
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, color: c.textHi),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          _otpSent
              ? '${context.tr('auth_otp_sent')} ${_email.text.trim()}'
              : context.tr('auth_subtitle'),
          style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textMid),
        ),
        const SizedBox(height: Gap.xxl),
        if (!_otpSent) ...[
          Text(context.tr('auth_email_label'),
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: c.textMid)),
          const SizedBox(height: 6),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(errorText: _error),
            style: TextStyle(fontSize: 14, color: c.textHi),
          ),
          const SizedBox(height: Gap.xl),
          FilledButton(
            onPressed: _busy ? null : _send,
            child:
                _busy ? const _Spinner() : Text(context.tr('auth_send_code')),
          ),
        ] else ...[
          _OtpBoxes(
              controllers: _otp, focusNodes: _otpFocus, onFilled: _verify),
          if (_error != null) ...[
            const SizedBox(height: Gap.md),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: c.danger)),
          ],
          const SizedBox(height: Gap.xl),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: _busy ? const _Spinner() : Text(context.tr('auth_verify')),
          ),
          const SizedBox(height: Gap.md),
          Center(
            child: TextButton(
              onPressed: _cooldown > 0 ? null : _send,
              child: Text(_cooldown > 0
                  ? '${context.tr('auth_resend_in')} ${_cooldown}s'
                  : context.tr('auth_resend')),
            ),
          ),
        ],
        const SizedBox(height: Gap.xxl),
        const _LegalNote(),
      ],
    );
  }
}

/// Enam kotak OTP dengan perpindahan fokus otomatis.
class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controllers,
    required this.focusNodes,
    required this.onFilled,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback onFilled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 6; i++)
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(right: i == 5 ? 0 : 8),
              child: AspectRatio(
                aspectRatio: 0.82,
                child: TextField(
                  controller: controllers[i],
                  focusNode: focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: c.textHi,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) {
                      focusNodes[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      focusNodes[i - 1].requestFocus();
                    }
                    if (controllers.every((c) => c.text.isNotEmpty)) {
                      FocusScope.of(context).unfocus();
                      onFilled();
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: primary ? c.accent : c.input,
      borderRadius: BorderRadius.circular(R.lg),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(R.lg),
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const _Spinner()
              else
                Icon(icon, size: 18, color: primary ? Colors.white : c.textMid),
              const SizedBox(width: Gap.md),
              Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primary ? Colors.white : c.textHi,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = TextStyle(fontSize: 11, height: 1.6, color: c.textLow);
    final link = style.copyWith(color: c.accent, fontWeight: FontWeight.w500);

    return Column(
      children: [
        Text(context.tr('auth_legal'),
            style: style, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GestureDetector(
              onTap: () => LegalPage.open(context, LegalDoc.terms),
              child: Text(context.tr('legal_terms'), style: link),
            ),
            Text('  ·  ', style: style),
            GestureDetector(
              onTap: () => LegalPage.open(context, LegalDoc.privacy),
              child: Text(context.tr('legal_privacy'), style: link),
            ),
          ],
        ),
      ],
    );
  }
}
