import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Big circular shutter button matching the HTML mock.
/// Outer 1.5 px magenta ring, gap, inner solid white disc. Tapping
/// fires medium haptic + onPressed; while [isLoading] is true, the
/// inner disc dims and a spinner takes its place.
class ShutterButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;

  const ShutterButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.size = 76,
  });

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _press.forward() : null,
      onTapCancel: enabled ? () => _press.reverse() : null,
      onTapUp: enabled
          ? (_) {
              _press.reverse();
              HapticFeedback.heavyImpact();
              widget.onPressed!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, _) {
          final scale = 1.0 - (_press.value * 0.08);
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                  // Inner disc
                  Container(
                    width: widget.size - 18,
                    height: widget.size - 18,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: widget.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.accent),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
