import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Tiny "● QUEST ACTIVE" pulsing pill at the top of the active quest
/// screen. The dot heartbeats on `smwhrPulse` (2 s) — confirms to the
/// user that the trackers are running.
class QuestActivePill extends StatefulWidget {
  const QuestActivePill({super.key});

  @override
  State<QuestActivePill> createState() => _QuestActivePillState();
}

class _QuestActivePillState extends State<QuestActivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final opacity = 0.55 + 0.45 * _pulse.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: opacity),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(
                      alpha: 0.6 * _pulse.value,
                    ),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'QUEST ACTIVE',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.accent,
                letterSpacing: 1.6,
              ),
            ),
          ],
        );
      },
    );
  }
}
