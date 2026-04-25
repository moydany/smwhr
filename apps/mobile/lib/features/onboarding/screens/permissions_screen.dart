import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/smwhr_button.dart';
import '../state/onboarding_state.dart';
import '../widgets/onboarding_shell.dart';

/// Pantalla 04 — Permissions. Bell icon + 3 features list + Enable / Maybe
/// later buttons. Final tap completes onboarding and routes to /home.
class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  static const _features = [
    _Feature('Quest active', 'When you arrive at a venue'),
    _Feature('Quest complete', 'When your badge is ready'),
    _Feature('Reminders', '24h before your next event'),
  ];

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    HapticFeedback.heavyImpact();
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    ctrl.setNotificationsEnabled(enabled);
    final ok = await ctrl.submit();
    if (!context.mounted) return;
    if (ok) {
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorBackground,
          content: Text(
            ref.read(onboardingControllerProvider).submitError ??
                'Something went wrong.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(onboardingControllerProvider);

    return OnboardingShell(
      currentStep: 3,
      title: 'Never miss\na quest.',
      subtitle:
          "We'll ping you when a quest starts at your location, when "
          "it's complete, and nothing else. Zero spam. Ever.",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: Alignment.centerLeft, child: _BellMark()),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _features.length; i++) ...[
                  _FeatureRow(feature: _features[i]),
                  if (i < _features.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ],
      ),
      cta: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SmwhrButton(
            label: 'Enable notifications  →',
            variant: SmwhrButtonVariant.primary,
            isLoading: form.isSubmitting,
            onPressed: form.isSubmitting
                ? null
                : () => _finish(context, ref, enabled: true),
          ),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: form.isSubmitting
                ? null
                : () => _finish(context, ref, enabled: false),
            child: Container(
              alignment: Alignment.center,
              height: 44,
              child: Text(
                'Maybe later',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BellMark extends StatelessWidget {
  const _BellMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 28,
              color: AppColors.textPrimary,
            ),
          ),
          // Magenta unread dot top-right.
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66FF2D95),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 1.4),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 14,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(feature.title, style: AppTypography.bodyLarge),
              const SizedBox(height: 2),
              Text(
                feature.subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Feature {
  final String title;
  final String subtitle;
  const _Feature(this.title, this.subtitle);
}
