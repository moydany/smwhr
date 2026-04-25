import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/smwhr_ambient_background.dart';
import '../../../shared/widgets/smwhr_button.dart';

/// Pantalla 01 — Splash / Auth.
///
/// Center-aligned hero matching design/mocks/v1: large magenta wordmark
/// with double glow, pulsing dot above the wordmark, ambient background
/// (grid + drift + sweep + stars + ping rings), and 3 provider buttons.
///
/// Cold-start fade-in is short (650 ms): the ambient layers do the
/// "alive" work after that — the screen is never static.
class SplashAuthScreen extends ConsumerStatefulWidget {
  const SplashAuthScreen({super.key});

  @override
  ConsumerState<SplashAuthScreen> createState() => _SplashAuthScreenState();
}

class _SplashAuthScreenState extends ConsumerState<SplashAuthScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _wordmarkScale;
  late final Animation<double> _bodyOpacity;
  late final Animation<double> _buttonsOpacity;
  late final AnimationController _dotPulse;

  _Provider? _busyProvider;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _wordmarkOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _wordmarkScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _bodyOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );
    _buttonsOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );

    _dotPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _dotPulse.dispose();
    super.dispose();
  }

  Future<void> _signIn(_Provider provider) async {
    if (_busyProvider != null) return;
    setState(() => _busyProvider = provider);

    final repo = ref.read(authRepositoryProvider);
    AuthResult result;
    try {
      result = switch (provider) {
        _Provider.apple => await repo.signInWithApple(),
        _Provider.google => await repo.signInWithGoogle(),
        _Provider.email => await repo.requestEmailMagicLink('mock@smwhr.dev'),
      };
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyProvider = null);
      _showError(e.toString());
      return;
    }
    if (!mounted) return;
    setState(() => _busyProvider = null);

    switch (result) {
      case AuthResultReady():
        HapticFeedback.heavyImpact();
        context.go(AppRoutes.home);
      case AuthResultNeedsOnboarding():
        HapticFeedback.heavyImpact();
        context.go(AppRoutes.onboardingIdentity);
      case AuthResultEmailSent(:final email):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Text(
              'Magic link sent to $email · tap any provider above to bypass',
              style: AppTypography.bodySmall,
            ),
          ),
        );
      case AuthResultFailure(:final message):
        _showError(message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.errorBackground,
        content: Text(
          message,
          style: AppTypography.bodySmall.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Ambient layer — runs forever, never blocks taps.
          const Positioned.fill(
            child: SmwhrAmbientBackground(
              pingCenter: Offset(0.5, 0.42),
              starCount: 60,
              pingRings: 6,
            ),
          ),

          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_intro, _dotPulse]),
              builder: (context, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(flex: 5),

                      // Pulsing dot above the wordmark — small, bright.
                      Opacity(
                        opacity: _wordmarkOpacity.value,
                        child: _PulseDot(progress: _dotPulse.value),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      Opacity(
                        opacity: _wordmarkOpacity.value,
                        child: Transform.scale(
                          scale: _wordmarkScale.value,
                          child: const _Wordmark(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      Opacity(
                        opacity: _bodyOpacity.value,
                        child: Text(
                          'You were somewhere.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      Opacity(
                        opacity: _bodyOpacity.value,
                        child: const _GeoPill(),
                      ),

                      const Spacer(flex: 6),

                      Opacity(
                        opacity: _buttonsOpacity.value,
                        child: Column(
                          children: [
                            SmwhrButton(
                              label: 'Continue with Apple',
                              variant: SmwhrButtonVariant.white,
                              leading: const Padding(
                                padding: EdgeInsets.only(left: AppSpacing.md),
                                child: Icon(Icons.apple, size: 20),
                              ),
                              isLoading: _busyProvider == _Provider.apple,
                              onPressed: _busyProvider == null
                                  ? () => _signIn(_Provider.apple)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            SmwhrButton(
                              label: 'Continue with Google',
                              variant: SmwhrButtonVariant.dark,
                              leading: const Padding(
                                padding: EdgeInsets.only(left: AppSpacing.md),
                                child: _GoogleGlyph(),
                              ),
                              isLoading: _busyProvider == _Provider.google,
                              onPressed: _busyProvider == null
                                  ? () => _signIn(_Provider.google)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            SmwhrButton(
                              label: 'Continue with email',
                              variant: SmwhrButtonVariant.outline,
                              isLoading: _busyProvider == _Provider.email,
                              onPressed: _busyProvider == null
                                  ? () => _signIn(_Provider.email)
                                  : null,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),
                      Opacity(
                        opacity: _buttonsOpacity.value,
                        child: Text(
                          'By continuing you agree to our Terms and Privacy.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.11,
                            color: const Color(0xFF444444),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _Provider { apple, google, email }

/// Big magenta "smwhr" wordmark with double textShadow glow.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text(
      'smwhr',
      style: GoogleFonts.spaceGrotesk(
        fontSize: 68,
        fontWeight: FontWeight.w700,
        letterSpacing: -3.4,
        height: 1.0,
        color: AppColors.accent,
        shadows: const [
          Shadow(
            color: Color(0x73FF2D95), // ~45% magenta
            blurRadius: 40,
          ),
          Shadow(
            color: Color(0x33FF2D95), // ~20% magenta
            blurRadius: 80,
          ),
        ],
      ),
    );
  }
}

/// 6×6 pulsing magenta dot — `smwhrPulse`-style heartbeat (0.55↔1 opacity).
class _PulseDot extends StatelessWidget {
  final double progress; // 0..1 from controller (reverses)
  const _PulseDot({required this.progress});

  @override
  Widget build(BuildContext context) {
    final opacity = 0.55 + 0.45 * progress; // 0.55..1.0
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: opacity),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.6 * progress),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

/// Geo coords pill — a tiny mono row centred under the tagline. The leading
/// dot blinks (3 s) per the HTML mock.
class _GeoPill extends StatefulWidget {
  const _GeoPill();

  @override
  State<_GeoPill> createState() => _GeoPillState();
}

class _GeoPillState extends State<_GeoPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(
                  alpha: 0.4 + 0.6 * _blink.value,
                ),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '20.0849° N   -98.3634° W',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Lightweight stand-in for the Google "G" mark — small ringed glyph.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.textPrimary, width: 1.2),
      ),
      child: Text(
        'G',
        style: AppTypography.buttonMedium.copyWith(
          fontSize: 11,
          height: 1,
        ),
      ),
    );
  }
}
