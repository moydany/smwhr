import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/quest.dart';

/// Single row in the active-quest verification checklist. Three visual
/// states map to [VerificationTaskStatus]:
///
///   - `pending` — outlined circle, dimmed label, "—" trailing
///   - `active`  — outlined accent circle, full label, optional count/hint
///   - `done`    — filled accent circle with check, full label, "OK" /
///                 N/M / time-stamp trailing
///
/// Stateless on purpose; mirrors the data layer ([VerificationTask])
/// without holding any of its own state. The animation comes from the
/// `AnimatedContainer` on the leading dot.
class VerificationTaskRow extends StatelessWidget {
  final String label;
  final VerificationTaskStatus status;

  /// Optional trailing string (e.g. "2/4", "OK", "Disponible"). When
  /// null, the row picks a sensible default based on [status]. Pass an
  /// empty string to suppress the default text — useful when the
  /// trailing slot should show [trailingWidget] instead.
  final String? trailing;

  /// Optional widget to render in the trailing slot in addition to
  /// (or in place of) the [trailing] text. Used by the photo task to
  /// surface a camera icon as the affordance.
  final Widget? trailingWidget;

  /// Optional secondary line under the label (e.g. "30 min mínimos",
  /// "Toma la foto cuando quieras"). Shown dim, smaller font.
  final String? hint;

  const VerificationTaskRow({
    super.key,
    required this.label,
    required this.status,
    this.trailing,
    this.trailingWidget,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = status == VerificationTaskStatus.done;
    final isActive = status == VerificationTaskStatus.active;
    final accent = isDone || isActive;

    final trailingText = trailing ?? _defaultTrailing(status);
    final labelColor = accent ? AppColors.textPrimary : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: AppSpacing.durationDefault,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AppColors.accent : Colors.transparent,
              border: Border.all(
                color: accent ? AppColors.accent : AppColors.border,
                width: 1.4,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : (isActive
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                      )
                    : null),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(color: labelColor),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingText.isNotEmpty)
            Text(
              trailingText,
              style: AppTypography.monoSmall.copyWith(
                color: isDone
                    ? AppColors.accent
                    : (isActive ? AppColors.textSecondary : AppColors.textTertiary),
                letterSpacing: 1.0,
              ),
            ),
          if (trailingWidget != null) ...[
            if (trailingText.isNotEmpty) const SizedBox(width: AppSpacing.xs),
            trailingWidget!,
          ],
        ],
      ),
    );
  }

  static String _defaultTrailing(VerificationTaskStatus status) {
    switch (status) {
      case VerificationTaskStatus.done:
        return 'OK';
      case VerificationTaskStatus.active:
        return '···';
      case VerificationTaskStatus.pending:
        return '—';
    }
  }
}
