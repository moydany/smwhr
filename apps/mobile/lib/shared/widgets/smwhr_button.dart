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
        SmwhrButtonVariant.outline => AppColors.textPrimary,
      };

  Border? get _border => switch (variant) {
        SmwhrButtonVariant.outline =>
          Border.all(color: AppColors.border, width: 1.2),
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        border: _border,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(fg),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    IconTheme(
                      data: IconThemeData(color: fg, size: 20),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: fg),
                        child: leading!,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: AppTypography.buttonLarge.copyWith(color: fg),
                  ),
                ],
              ),
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
