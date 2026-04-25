import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A pulsing surface block used for skeleton loaders. Auto-loops
/// `smwhrPulse`-like opacity (0.4 ↔ 0.7).
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double? radius;
  final EdgeInsets? margin;

  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.radius,
    this.margin,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
        final opacity = 0.4 + 0.3 * _pulse.value;
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(
              widget.radius ?? AppSpacing.radiusBadge,
            ),
            border: Border.all(
              color: AppColors.borderSoft.withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}
