import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Visual variants for [SmwhrButton]. Maps roughly to the splash/auth
/// hierarchy: primary = magenta accent, white = OAuth provider-like,
/// dark = secondary gray, outline = tertiary outlined.
enum SmwhrButtonVariant { primary, white, dark, outline }

/// Single source of truth for buttons across smwhr. Auth providers, intent
/// CTAs, "Take photo", "Share" all flow through this widget — keeps haptic
/// feedback, loading state, and disabled state consistent.
class SmwhrButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final SmwhrButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final HapticFeedbackType? haptic;

  const SmwhrButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.variant = SmwhrButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.haptic = HapticFeedbackType.medium,
  });

  bool get _enabled => onPressed != null && !isLoading;

  // ── Style table ───────────────────────────────────────────────────────
  // Specs derived from design/mocks/v1 (Continue with Apple/Google/email):
  // 52 px tall, 14 px radius, 15 px text @ weight 500, letter-spacing -0.15.
  Color get _bg => switch (variant) {
        SmwhrButtonVariant.primary => AppColors.accent,
        SmwhrButtonVariant.white => Colors.white,
        SmwhrButtonVariant.dark => AppColors.surfaceElevated,
        SmwhrButtonVariant.outline => Colors.transparent,
      };

  Color get _fg => switch (variant) {
        SmwhrButtonVariant.primary => Colors.white,
        SmwhrButtonVariant.white => AppColors.bg,
        SmwhrButtonVariant.dark => AppColors.textPrimary,
        SmwhrButtonVariant.outline => const Color(0xFFAAAAAA),
      };

  Border? get _border => switch (variant) {
        SmwhrButtonVariant.outline =>
          Border.all(color: AppColors.borderSoft, width: 1),
        SmwhrButtonVariant.dark =>
          Border.all(color: const Color(0xFF222222), width: 1),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final disabled = !_enabled;
    final bg = disabled ? _bg.withValues(alpha: 0.4) : _bg;
    final fg = disabled ? _fg.withValues(alpha: 0.6) : _fg;

    final child = AnimatedContainer(
      duration: AppSpacing.durationFast,
      curve: Curves.easeOut,
      width: fullWidth ? double.infinity : null,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        border: _border,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Icon stays absolutely positioned on the left so the label can
          // remain perfectly centered relative to the button (matches HTML).
          if (leading != null && !isLoading)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconTheme(
                  data: IconThemeData(color: fg, size: 20),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: fg),
                    child: leading!,
                  ),
                ),
              ),
            ),
          if (isLoading)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            )
          else
            Text(
              label,
              style: AppTypography.buttonMedium.copyWith(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.15,
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _enabled
            ? () {
                _fireHaptic();
                onPressed!();
              }
            : null,
        child: AnimatedOpacity(
          duration: AppSpacing.durationFast,
          opacity: _enabled ? 1.0 : 0.6,
          child: child,
        ),
      ),
    );
  }

  void _fireHaptic() {
    switch (haptic) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
      case null:
        break;
    }
  }
}

enum HapticFeedbackType { light, medium, heavy, selection }
