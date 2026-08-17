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
import 'auth_service.dart';
import 'legal_page.dart';

const _authContentWidth = 440.0;

double _authSidePadding(double width) {
  final centered = (width - _authContentWidth) / 2;
  return centered > Gap.screen ? centered : Gap.screen;
}

enum _EmailOperation { sendOtp, verifyOtp }

/// Layar masuk asli: Google ID token atau Email + OTP melalui Cloudflare.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _emailMode = false;
  bool _busy = false;
  String? _error;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = _authSidePadding(constraints.maxWidth);
        return ListView(
          key: const ValueKey('choice'),
          padding: EdgeInsets.fromLTRB(side, 0, side, Gap.xxl),
          children: [
            const SizedBox(height: Gap.h32),
            Center(
              child: Image.asset(
                Img.auth,
                width: 168,
                height: 168,
                errorBuilder: (_, __, ___) => const SizedBox(height: 168),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Text(
              context.tr('auth_welcome'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              context.tr('auth_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.55, color: c.textMid),
            ),
            const SizedBox(height: Gap.h32),
            _AuthButton(
              leading: const GoogleBrandIcon(size: 22),
              label: context.tr('auth_google'),
              primary: true,
              busy: _busy,
              enabled: !_busy,
              onTap: _signInGoogle,
            ),
            if (_error != null) ...[
              const SizedBox(height: Gap.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: c.danger),
                ),
              ),
            ],
            const SizedBox(height: Gap.md),
            _AuthButton(
              leading: const EmailBrandIcon(size: 22),
              label: context.tr('auth_email'),
              enabled: !_busy,
              onTap: () {
                setState(() {
                  _emailMode = true;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: Gap.md),
            _AuthButton(
              leading: const GuestBrandIcon(size: 22),
              label: context.tr('auth_guest'),
              enabled: !_busy,
              onTap: () async {
                await ref.read(authProvider.notifier).signInGuest();
              },
            ),
            const SizedBox(height: Gap.xxl),
            const _LegalNote(),
          ],
        );
      },
    );
  }

  Future<void> _signInGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    DevLog.i('auth', 'Mulai masuk dengan Google');
    try {
      final session = await ref.read(googleAuthServiceProvider).signIn();
      if (!mounted) return;
      await ref
          .read(authProvider.notifier)
          .signInAuthenticated(
            email: session.user.email,
            name: session.user.name,
            token: session.token,
          );
      DevLog.ok('auth', 'Google Sign-In berhasil', session.user.email);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      DevLog.w('auth', 'Google Sign-In gagal', error.code);
    } catch (error, stack) {
      if (!mounted) return;
      setState(() => _error = 'Google Sign-In gagal. Coba lagi.');
      DevLog.e('auth', 'Google Sign-In gagal', error, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
  _EmailOperation? _operation;
  String _otpValue = '';
  bool _otpHasError = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  bool get _busy => _operation != null;

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

  void _clearOtp() {
    for (final controller in _otp) {
      controller.clear();
    }
    _otpValue = '';
    _otpHasError = false;
  }

  void _editEmail() {
    _timer?.cancel();
    _clearOtp();
    setState(() {
      _otpSent = false;
      _cooldown = 0;
      _error = null;
    });
  }

  void _startCooldown(int seconds) {
    setState(() => _cooldown = seconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = context.tr('auth_invalid_email'));
      return;
    }
    setState(() {
      _operation = _EmailOperation.sendOtp;
      _otpHasError = false;
      _error = null;
    });
    var focusOtp = false;

    try {
      final result = await ref.read(authServiceProvider).requestOtp(email);
      if (!mounted) return;
      _clearOtp();
      setState(() => _otpSent = true);
      _startCooldown(result.resendIn);
      focusOtp = true;
      DevLog.ok('auth', 'Kode OTP dikirim', email);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      DevLog.w('auth', 'Gagal meminta OTP', error.code);
    } catch (error, stack) {
      if (!mounted) return;
      setState(() => _error = 'Kode OTP gagal dikirim. Coba lagi.');
      DevLog.e('auth', 'Gagal meminta OTP', error, stack);
    } finally {
      if (mounted) {
        setState(() => _operation = null);
        if (focusOtp) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _otpFocus.first.requestFocus();
          });
        }
      }
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _otp.map((c) => c.text).join();
    if (code.length < 6) return;
    var refocusOtp = false;
    setState(() {
      _operation = _EmailOperation.verifyOtp;
      _otpHasError = false;
      _error = null;
    });

    try {
      final session = await ref
          .read(authServiceProvider)
          .verifyOtp(_email.text.trim(), code);
      if (!mounted) return;
      await ref
          .read(authProvider.notifier)
          .signInAuthenticated(
            email: session.user.email,
            name: session.user.name,
            token: session.token,
          );
      DevLog.ok('auth', 'OTP berhasil diverifikasi', session.user.email);
    } on AuthException catch (error) {
      if (!mounted) return;
      final codeRejected =
          error.code == 'wrong-otp' || error.code == 'otp-expired';
      if (codeRejected) {
        _clearOtp();
        refocusOtp = true;
      }
      setState(() {
        _otpHasError = codeRejected;
        _error = error.message;
      });
      DevLog.w('auth', 'Verifikasi OTP gagal', error.code);
    } catch (error, stack) {
      if (!mounted) return;
      setState(() => _error = 'Verifikasi gagal. Coba lagi.');
      DevLog.e('auth', 'Verifikasi OTP gagal', error, stack);
    } finally {
      if (mounted) {
        setState(() => _operation = null);
        if (refocusOtp) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _otpFocus.first.requestFocus();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = _authSidePadding(constraints.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(side, 0, side, Gap.xxl),
          children: [
            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(LucideIcons.arrowLeft, size: 20, color: c.textMid),
                tooltip: context.tr('back'),
                onPressed:
                    _busy ? null : (_otpSent ? _editEmail : widget.onBack),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              _otpSent
                  ? context.tr('auth_otp_title')
                  : context.tr('auth_email_label'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: c.textHi,
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              _otpSent
                  ? '${context.tr('auth_otp_sent')} ${_email.text.trim()}'
                  : context.tr('auth_email_help'),
              style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textMid),
            ),
            const SizedBox(height: Gap.xxl),
            if (!_otpSent) ...[
              Text(
                context.tr('auth_email_label'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: c.textMid,
                ),
              ),
              const SizedBox(height: 6),
              AutofillGroup(
                child: TextField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'email@example.com',
                    errorText: _error,
                    prefixIcon: Icon(
                      LucideIcons.mail,
                      size: 18,
                      color: c.textLow,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                  style: TextStyle(fontSize: 14, color: c.textHi),
                ),
              ),
              const SizedBox(height: Gap.xl),
              FilledButton(
                onPressed: _busy ? null : _send,
                style: _operation == _EmailOperation.sendOtp
                    ? FilledButton.styleFrom(
                        disabledBackgroundColor: c.accent,
                        disabledForegroundColor: Colors.white,
                      )
                    : null,
                child: _operation == _EmailOperation.sendOtp
                    ? Semantics(
                        label: context.tr('auth_send_code'),
                        child: const _Spinner(),
                      )
                    : Text(context.tr('auth_send_code')),
              ),
            ] else ...[
              _OtpBoxes(
                controllers: _otp,
                focusNodes: _otpFocus,
                enabled: !_busy,
                hasError: _otpHasError,
                onChanged: (code) {
                  setState(() {
                    _otpValue = code;
                    _otpHasError = false;
                    _error = null;
                  });
                },
                onSubmitted: _verify,
              ),
              if (_error != null) ...[
                const SizedBox(height: Gap.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: c.danger),
                  ),
                ),
              ],
              const SizedBox(height: Gap.xl),
              FilledButton(
                onPressed: _busy || _otpValue.length != 6 ? null : _verify,
                style: _operation == _EmailOperation.verifyOtp
                    ? FilledButton.styleFrom(
                        disabledBackgroundColor: c.accent,
                        disabledForegroundColor: Colors.white,
                      )
                    : null,
                child: _operation == _EmailOperation.verifyOtp
                    ? Semantics(
                        label: context.tr('auth_verify'),
                        child: const _Spinner(),
                      )
                    : Text(context.tr('auth_verify')),
              ),
              const SizedBox(height: Gap.md),
              Center(
                child: TextButton(
                  onPressed: _busy || _cooldown > 0 ? null : _send,
                  child: _operation == _EmailOperation.sendOtp
                      ? Semantics(
                          label: context.tr('auth_resend'),
                          child: _Spinner(color: c.accent),
                        )
                      : Text(
                          _cooldown > 0
                              ? '${context.tr('auth_resend_in')} ${_cooldown}s'
                              : context.tr('auth_resend'),
                        ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Enam field OTP yang tegas dan ringkas, dengan dukungan paste/autofill.
class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controllers,
    required this.focusNodes,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  String get _code => controllers.map((controller) => controller.text).join();

  void _notify() => onChanged(_code);

  void _handleChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    // OTP autofill dan paste biasanya masuk sebagai enam digit sekaligus.
    // Sebarkan ke seluruh field agar pengguna tidak perlu mengetik ulang.
    if (digits.length > 1) {
      final start = digits.length == 6 ? 0 : index;
      for (var offset = 0; offset < digits.length; offset++) {
        final target = start + offset;
        if (target >= controllers.length) break;
        controllers[target].text = digits[offset];
      }
      final next = start + digits.length;
      focusNodes[next < focusNodes.length ? next : focusNodes.length - 1]
          .requestFocus();
    } else if (digits.isNotEmpty && index < focusNodes.length - 1) {
      focusNodes[index + 1].requestFocus();
    } else if (digits.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    _notify();
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        controllers[index].text.isEmpty &&
        index > 0) {
      controllers[index - 1].clear();
      focusNodes[index - 1].requestFocus();
      _notify();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AutofillGroup(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth > 352
              ? 352.0
              : constraints.maxWidth;
          final gap = contentWidth < 300 ? 6.0 : 8.0;
          final boxWidth = (contentWidth - (gap * 5)) / 6;
          final idleBorder = c.textLow.withValues(alpha: 0.20);
          final borderColor = hasError ? c.danger : idleBorder;
          final focusColor = hasError ? c.danger : c.accent;

          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: contentWidth,
              child: Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(
                      width: boxWidth,
                      height: 58,
                      child: Focus(
                        canRequestFocus: false,
                        onKeyEvent: (_, event) => _handleKey(i, event),
                        child: Semantics(
                          label: '${context.tr('auth_otp_title')} ${i + 1}',
                          textField: true,
                          child: TextField(
                            controller: controllers[i],
                            focusNode: focusNodes[i],
                            enabled: enabled,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            textInputAction: i == 5
                                ? TextInputAction.done
                                : TextInputAction.next,
                            autofillHints: i == 0
                                ? const [AutofillHints.oneTimeCode]
                                : null,
                            autocorrect: false,
                            enableSuggestions: false,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            cursorColor: c.accent,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              color: c.textHi,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: c.input,
                              constraints: const BoxConstraints.tightFor(
                                height: 58,
                              ),
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(R.sm),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(R.sm),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(R.sm),
                                borderSide: BorderSide(color: idleBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(R.sm),
                                borderSide: BorderSide(
                                  color: focusColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onTap: () {
                              final text = controllers[i].text;
                              controllers[i].selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: text.length,
                              );
                            },
                            onChanged: (value) =>
                                _handleChanged(i, value),
                            onSubmitted: (_) {
                              if (_code.length == 6) onSubmitted();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    this.leading,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.busy = false,
    this.enabled = true,
  });

  final Widget? leading;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final disabled = !enabled && !busy;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: primary ? c.accent : c.input,
        borderRadius: BorderRadius.circular(R.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy || !enabled ? null : onTap,
          borderRadius: BorderRadius.circular(R.md),
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const _Spinner()
                else if (leading != null)
                  leading!,
                const SizedBox(width: Gap.md),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primary ? Colors.white : c.textHi,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleBrandIcon extends StatelessWidget {
  const GoogleBrandIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final yellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // 4 bagian arc warna resmi Google
    canvas.drawArc(rect, -0.78, 1.35, false, red);
    canvas.drawArc(rect, 2.35, 1.15, false, yellow);
    canvas.drawArc(rect, 0.78, 1.57, false, green);
    canvas.drawArc(rect, -0.78, -1.05, false, blue);

    // Crossbar horizontal biru G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - strokeWidth / 2,
        center.dx + radius * 0.95,
        center.dy + strokeWidth / 2,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EmailBrandIcon extends StatelessWidget {
  const EmailBrandIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF5B7FE8), Color(0xFF3D63D8)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(LucideIcons.mail, size: size * 0.58, color: Colors.white),
    );
  }
}

class GuestBrandIcon extends StatelessWidget {
  const GuestBrandIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(LucideIcons.userCheck, size: size * 0.58, color: Colors.white),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
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
        Text(
          context.tr('auth_legal'),
          style: style,
          textAlign: TextAlign.center,
        ),
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
