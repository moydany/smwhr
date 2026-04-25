import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Big mono HH:MM:SS timer. In mock mode the input is `dwellMinutes`,
/// where 1 second of wall time = 1 mock minute. Renders three two-digit
/// segments separated by spaced colons, matching the HTML mock layout
/// (`00 : 47 : 23`).
class QuestTimer extends StatelessWidget {
  /// Total elapsed time in mock-minutes. The widget converts to HH:MM:SS
  /// where the seconds field is animated by a wall-clock controller in
  /// the parent — for the static mock, seconds = (wallMs / 1000) % 60.
  final int dwellMinutes;
  final int wallSeconds;

  const QuestTimer({
    super.key,
    required this.dwellMinutes,
    this.wallSeconds = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hh = (dwellMinutes ~/ 60).toString().padLeft(2, '0');
    final mm = (dwellMinutes % 60).toString().padLeft(2, '0');
    final ss = wallSeconds.toString().padLeft(2, '0');

    final digitStyle = GoogleFonts.jetBrainsMono(
      fontSize: 56,
      fontWeight: FontWeight.w700,
      letterSpacing: -2,
      height: 1.0,
      color: AppColors.textPrimary,
    );
    final colonStyle = digitStyle.copyWith(
      color: AppColors.textTertiary,
      fontWeight: FontWeight.w400,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(hh, style: digitStyle),
        const SizedBox(width: AppSpacing.xs),
        Text(':', style: colonStyle),
        const SizedBox(width: AppSpacing.xs),
        Text(mm, style: digitStyle),
        const SizedBox(width: AppSpacing.xs),
        Text(':', style: colonStyle),
        const SizedBox(width: AppSpacing.xs),
        Text(ss, style: digitStyle),
      ],
    );
  }
}
