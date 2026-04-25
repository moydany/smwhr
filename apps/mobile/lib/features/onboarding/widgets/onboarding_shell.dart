import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Shared scaffold for the 3 onboarding screens.
///
/// Top bar: chevron-back (left) + step indicator like `01 / 03` (right).
/// Body: padded column with title + subtitle + caller's content.
/// Footer: optional Continue CTA (passed via `cta`) — gets pinned to the
/// bottom safe area, with an optional subtle "PICK AT LEAST ONE"-style
/// hint label above it.
class OnboardingShell extends StatelessWidget {
  /// 1-based current step. The total is fixed at 3.
  final int currentStep;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget? cta;
  final String? hint;

  const OnboardingShell({
    super.key,
    required this.currentStep,
    required this.title,
    required this.subtitle,
    required this.body,
    this.cta,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xs),
              _TopBar(currentStep: currentStep),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                style: AppTypography.displayLarge.copyWith(
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: body,
                ),
              ),
              if (hint != null) ...[
                Center(
                  child: Text(
                    hint!.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              ?cta,
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int currentStep;
  const _TopBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.lightImpact();
                if (GoRouter.of(context).canPop()) {
                  context.pop();
                }
              },
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        Text(
          '${currentStep.toString().padLeft(2, '0')} / 03',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            letterSpacing: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
