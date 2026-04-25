import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import '../../../data/models/event_category.dart';

/// The badge frame composed live as the user lines up their shot.
///
/// Header: "SMWHR" left + uppercase category right (e.g. "LIVE MUSIC").
/// Body: dashed rectangle "YOUR PHOTO HERE" — replaced by the captured
/// photo at composite time.
/// Footer: venue uppercase, `<city> · <DATE>` mono, `<artist> · <title>`
/// small footer.
///
/// Pre-capture the [photo] is null and the dashed placeholder shows.
/// Post-capture, [photo] is the rendered Image (from camera or mock fixture).
class BadgeFrameOverlay extends StatelessWidget {
  final Event event;
  final ImageProvider? photo;
  final bool tight;

  const BadgeFrameOverlay({
    super.key,
    required this.event,
    this.photo,
    this.tight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: tight ? 0.85 : 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Frame header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SMWHR',
                  style: AppTypography.monoSmall.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _categoryHeader(event.category),
                  style: AppTypography.monoSmall.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Photo / placeholder area
          AspectRatio(
            aspectRatio: 1,
            child: _PhotoArea(photo: photo),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Frame footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.venueName.toUpperCase(),
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.city.toUpperCase()} · ${_formatShortDate(event.startsAt)}',
                  style: AppTypography.monoSmall.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitleLine(event),
                  style: AppTypography.monoSmall.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _categoryHeader(EventCategory c) => switch (c) {
        EventCategory.music => 'LIVE MUSIC',
        EventCategory.sports => 'LIVE SPORTS',
        EventCategory.festivals => 'FESTIVAL',
        EventCategory.outdoor => 'OUTDOOR',
        EventCategory.culture => 'CULTURE',
      };

  static String _formatShortDate(DateTime d) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, '
        '${d.year}';
  }

  static String _subtitleLine(Event event) {
    final parts = <String>[];
    if (event.artistName != null) {
      parts.add(event.artistName!.toUpperCase());
    }
    parts.add(event.title.toUpperCase());
    return parts.join(' · ');
  }
}

class _PhotoArea extends StatelessWidget {
  final ImageProvider? photo;
  const _PhotoArea({required this.photo});

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: Image(image: photo!, fit: BoxFit.cover),
      );
    }
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Center(
        child: Text(
          'YOUR PHOTO HERE',
          style: AppTypography.monoSmall.copyWith(
            fontSize: 10,
            letterSpacing: 1.4,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.border;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final radius = AppSpacing.radiusSmall;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final extract = metric.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => false;
}
