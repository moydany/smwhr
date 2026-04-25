import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Stub used by every feature screen until its session is wired up.
/// Renders the route name + the upcoming session # so we know what's next.
class PlaceholderScreen extends StatelessWidget {
  final String route;
  final String session;
  final List<String> notes;

  const PlaceholderScreen({
    super.key,
    required this.route,
    required this.session,
    this.notes = const [],
  });

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(route, style: AppTypography.monoSmall),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'placeholder',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(route, style: AppTypography.displayLarge),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(session, style: AppTypography.monoSmall),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '· $note',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
