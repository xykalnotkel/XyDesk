import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/store.dart';
import '../../core/tokens.dart';
import '../../widgets/brand.dart';

/// Flutter half of the native-to-app launch transition.
///
/// The native window and this page intentionally share the same dark surface,
/// safe-zone 34 dp mark, and centered first frame. Flutter completes the lockup by
/// moving the mark a short distance and revealing the wordmark; there is no
/// second entrance animation or decorative ripple to restart the splash.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  )..forward();

  late final Animation<double> _markOffset =
      Tween<double>(begin: 0, end: -55).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.72, curve: Curves.easeOutCubic),
    ),
  );

  late final Animation<double> _wordmarkOpacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.32, 0.78, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _wordmarkOffset =
      Tween<double>(begin: 10, end: 0).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.32, 0.78, curve: Curves.easeOutCubic),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ref.watch(settingsProvider).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: AppColors.bgDark,
      child: Center(
        child: reduceMotion
            ? const _SplashLockup(
                markOffset: -55,
                wordmarkOpacity: 1,
                wordmarkOffset: 0,
              )
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _SplashLockup(
                  markOffset: _markOffset.value,
                  wordmarkOpacity: _wordmarkOpacity.value,
                  wordmarkOffset: _wordmarkOffset.value,
                ),
              ),
      ),
    );
  }
}

class _SplashLockup extends StatelessWidget {
  const _SplashLockup({
    required this.markOffset,
    required this.wordmarkOpacity,
    required this.wordmarkOffset,
  });

  final double markOffset;
  final double wordmarkOpacity;
  final double wordmarkOffset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(markOffset, 0),
            child: const BrandLogo(size: 34),
          ),
          Positioned(
            left: 90,
            child: Opacity(
              opacity: wordmarkOpacity,
              child: Transform.translate(
                offset: Offset(wordmarkOffset, 0),
                child: const Text(
                  'XyDesk',
                  style: TextStyle(
                    color: AppColors.textHiDark,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
