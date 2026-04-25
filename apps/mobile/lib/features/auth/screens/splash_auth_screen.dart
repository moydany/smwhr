import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/smwhr_button.dart';

/// Pantalla 01 — Splash / Auth.
///
/// Cold-start sequence:
/// 1. Splash phase (1.5 s): wordmark fades up + scales while the magenta
///    accent line draws in horizontally.
/// 2. Auth phase: tagline, geo coords, 3 provider buttons, legal copy.
///
/// Splash is skipped when navigating here from elsewhere (e.g. sign-out)
/// thanks to the router; the [_alreadySplashed] static keeps cold-start
/// detection cheap.
class SplashAuthScreen extends ConsumerStatefulWidget {
  const SplashAuthScreen({super.key});

  @override
  ConsumerState<SplashAuthScreen> createState() => _SplashAuthScreenState();
}

class _SplashAuthScreenState extends ConsumerState<SplashAuthScreen>
    with SingleTickerProviderStateMixin {
  static bool _alreadySplashed = false;

  late final AnimationController _intro;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<double> _wordmarkScale;
  late final Animation<double> _accentDraw;
  late final Animation<double> _bodyOpacity;

  _Provider? _busyProvider;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _wordmarkOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _wordmarkScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutBack),
      ),
    );
    _accentDraw = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic),
    );
    _bodyOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );

    if (_alreadySplashed) {
      // Reactive navigation back to splash — skip the slow intro.
      _intro.value = 1.0;
    } else {
      _alreadySplashed = true;
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
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
        // Stub for the magic link flow until Session 4 wires the verify
        // step. For now, show a snack so the dev knows what happened.
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
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _intro,
          builder: (_, _) {
            return Stack(
              children: [
                // Subtle radial glow behind the wordmark
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _wordmarkOpacity.value * 0.5,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.7,
                            center: Alignment(0, -0.35),
                            colors: [
                              Color(0x33FF2D95),
                              Colors.transparent,
                            ],
                            stops: [0, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Hero stack ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 3),
                      Opacity(
                        opacity: _wordmarkOpacity.value,
                        child: Transform.scale(
                          scale: _wordmarkScale.value,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'smwhr',
                            style: AppTypography.displayHero.copyWith(
                              fontSize: 64,
                              height: 1,
                              letterSpacing: -2,
                              shadows: const [
                                Shadow(
                                  color: Color(0x66FF2D95),
                                  blurRadius: 28,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Container(
                            width: 32 * _accentDraw.value,
                            height: 2,
                            color: AppColors.accent,
                          ),
                          if (_accentDraw.value > 0.4) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Opacity(
                              opacity: _accentDraw.value,
                              child: Text(
                                'YOU WERE SOMEWHERE',
                                style: AppTypography.label.copyWith(
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Opacity(
                        opacity: _bodyOpacity.value,
                        child: const _GeoBadge(),
                      ),
                      const Spacer(flex: 4),

                      // ── Auth buttons ───────────────────────────────────
                      Opacity(
                        opacity: _bodyOpacity.value,
                        child: Column(
                          children: [
                            SmwhrButton(
                              label: 'Continuar con Apple',
                              variant: SmwhrButtonVariant.white,
                              leading: const Icon(Icons.apple, size: 22),
                              isLoading: _busyProvider == _Provider.apple,
                              onPressed: _busyProvider == null
                                  ? () => _signIn(_Provider.apple)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SmwhrButton(
                              label: 'Continuar con Google',
                              variant: SmwhrButtonVariant.dark,
                              leading: const _GoogleGlyph(),
                              isLoading: _busyProvider == _Provider.google,
                              onPressed: _busyProvider == null
                                  ? () => _signIn(_Provider.google)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SmwhrButton(
                              label: 'Continuar con email',
                              variant: SmwhrButtonVariant.outline,
                              leading: const Icon(Icons.mail_outline,
                                  size: 20),
                              isLoading: _busyProvider == _Provider.email,
                              onPressed: _busyProvider == null
                                  ? () => _signIn(_Provider.email)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Opacity(
                        opacity: _bodyOpacity.value * 0.8,
                        child: Text(
                          'Al continuar aceptas los Términos y la '
                          'Política de privacidad.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _Provider { apple, google, email }

/// Tulancingo coordinates — replaced with live Geolocator data once the
/// real location flow lands (Session 4 / Phase 2).
class _GeoBadge extends StatelessWidget {
  const _GeoBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '20.0850° N · -98.3630° W',
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Lightweight stand-in for the Google "G" mark until SVG icons land in
/// Session 12 (polish).
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.textPrimary, width: 1.4),
      ),
      child: Text(
        'G',
        style: AppTypography.buttonMedium.copyWith(
          fontSize: 13,
          height: 1,
        ),
      ),
    );
  }
}
