import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Single row in the verification checks list. Has 3 visual states:
/// - **passing** (filled magenta circle with check) → label normal, "OK" right
/// - **pending** (empty circle outline) → label dimmed, "—" right
/// - **idle** (used at boot before mock fires the check) → same as pending
class VerificationCheckRow extends StatelessWidget {
  final String label;
  final bool passing;
  final bool optional;

  const VerificationCheckRow({
    super.key,
    required this.label,
    required this.passing,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelText = optional ? '$label (optional)' : label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          AnimatedContainer(
            duration: AppSpacing.durationDefault,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: passing ? AppColors.accent : Colors.transparent,
              border: Border.all(
                color: passing ? AppColors.accent : AppColors.border,
                width: 1.4,
              ),
            ),
            child: passing
                ? const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              labelText,
              style: AppTypography.bodyMedium.copyWith(
                color: passing
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            passing ? 'OK' : '—',
            style: AppTypography.monoSmall.copyWith(
              color: passing ? AppColors.accent : AppColors.textTertiary,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
