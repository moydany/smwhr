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
import '../../../shared/widgets/smwhr_text_field.dart';

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

  bool _opening = false;

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

  Future<void> _openEmailSheet() async {
    if (_opening) return;
    _opening = true;
    final result = await showModalBottomSheet<AuthResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetCtx) => _EmailAuthSheet(
        repo: ref.read(authRepositoryProvider),
      ),
    );
    _opening = false;
    if (!mounted || result == null) return;
    _handleResult(result);
  }

  void _handleResult(AuthResult result) {
    switch (result) {
      case AuthResultReady():
        HapticFeedback.heavyImpact();
        context.go(AppRoutes.home);
      case AuthResultNeedsOnboarding():
        HapticFeedback.heavyImpact();
        context.go(AppRoutes.onboardingIdentity);
      case AuthResultEmailSent():
        // Reached only if sheet returns a 'sent' (it doesn't today; stays open).
        break;
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
                        child: SmwhrButton(
                          label: 'Continue with email',
                          variant: SmwhrButtonVariant.outline,
                          isLoading: false,
                          onPressed: _openEmailSheet,
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

/// Bottom sheet that walks the user through the email magic-link OTP flow.
/// Two stages: email entry → 6-digit code entry. On success it pops the
/// sheet with the [AuthResult] so the splash can route home or onboarding.
class _EmailAuthSheet extends StatefulWidget {
  const _EmailAuthSheet({required this.repo});
  final AuthRepository repo;

  @override
  State<_EmailAuthSheet> createState() => _EmailAuthSheetState();
}

enum _Stage { email, code }

class _EmailAuthSheetState extends State<_EmailAuthSheet> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  _Stage _stage = _Stage.email;
  bool _busy = false;
  String? _error;
  String _email = '';

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repo.requestEmailMagicLink(email);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case AuthResultEmailSent(:final email):
        setState(() {
          _email = email;
          _stage = _Stage.code;
          _codeController.clear();
        });
      case AuthResultFailure(:final message):
        setState(() => _error = message);
      case AuthResultReady():
      case AuthResultNeedsOnboarding():
        Navigator.of(context).pop(result);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code from your email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repo.verifyEmailMagicLink(_email, code);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case AuthResultReady():
      case AuthResultNeedsOnboarding():
        Navigator.of(context).pop(result);
      case AuthResultFailure(:final message):
        setState(() => _error = message);
      case AuthResultEmailSent():
        // Unexpected on verify — treat as failure.
        setState(() => _error = 'Unexpected response');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusCard),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _stage == _Stage.email ? 'Continue with email' : 'Enter the code',
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _stage == _Stage.email
                    ? 'We\'ll send you a 6-digit code. No password.'
                    : 'Sent to $_email. Check your inbox.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_stage == _Stage.email)
                SmwhrTextField(
                  controller: _emailController,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _sendCode(),
                  readOnly: _busy,
                  autofocus: true,
                )
              else
                SmwhrTextField(
                  controller: _codeController,
                  hint: '••••••',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  onSubmitted: (_) => _verify(),
                  readOnly: _busy,
                  autofocus: true,
                ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SmwhrButton(
                label: _stage == _Stage.email ? 'Send code' : 'Verify',
                variant: SmwhrButtonVariant.primary,
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : (_stage == _Stage.email ? _sendCode : _verify),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_stage == _Stage.code)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _stage = _Stage.email;
                            _error = null;
                            _codeController.clear();
                          }),
                  child: Text(
                    'Use a different email',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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

