import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Onboarding step indicator. 3 dots — current step is solid magenta,
/// past steps stay magenta, future steps are dim.
class SmwhrProgressDots extends StatelessWidget {
  final int total;
  final int current; // 1-based
  final double dotSize;
  final double activeDotWidth;
  final double gap;

  const SmwhrProgressDots({
    super.key,
    required this.total,
    required this.current,
    this.dotSize = 6,
    this.activeDotWidth = 24,
    this.gap = AppSpacing.xs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= total; i++) ...[
          AnimatedContainer(
            duration: AppSpacing.durationDefault,
            curve: Curves.easeOutCubic,
            width: i == current ? activeDotWidth : dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: i <= current
                  ? AppColors.accent
                  : AppColors.border,
              borderRadius: BorderRadius.circular(dotSize),
            ),
          ),
          if (i < total) SizedBox(width: gap),
        ],
      ],
    );
  }
}
