import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';

/// Sesión 1 — smoke screen.
/// Renderiza tokens en pantalla para verificar el theme. Reemplazado en
/// Sesión 2 por el router real.
class SmokeScreen extends StatelessWidget {
  const SmokeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('smwhr', style: AppTypography.displayHero),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 2,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'YOU WERE SOMEWHERE',
                    style: AppTypography.label.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Tonight you stop being someone who said they went.',
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Verified by GPS. Sealed by time. Yours forever.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              const _TokenSampler(),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  'session 01 · bootstrap ok',
                  style: AppTypography.monoSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenSampler extends StatelessWidget {
  const _TokenSampler();

  @override
  Widget build(BuildContext context) {
    final swatches = <(String, Color)>[
      ('bg', AppColors.bg),
      ('surface', AppColors.surface),
      ('elevated', AppColors.surfaceElevated),
      ('border', AppColors.border),
      ('accent', AppColors.accent),
      ('muted', AppColors.accentMuted),
      ('error', AppColors.error),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TOKENS', style: AppTypography.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (name, color) in swatches)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Text(
                  name,
                  style: AppTypography.monoSmall.copyWith(
                    color: color.computeLuminance() > 0.4
                        ? AppColors.bg
                        : AppColors.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
