import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/event.dart';
import '../../../data/models/event_category.dart';

/// Procedural artwork for event cards that mirrors the HTML mock — a
/// dark surface with a category-tinted radial gradient, optional star
/// dots, and (for the large featured variant) a mountain silhouette.
///
/// We deliberately avoid network images for the mock layer: every event
/// gets a deterministic, gorgeous thumbnail driven by its `id` seed and
/// `category`. Real promoter posters land in Phase 2 once the
/// Ticketmaster integration is wired.
class EventArtwork extends StatelessWidget {
  final Event event;
  final bool large;
  final BorderRadius? borderRadius;

  const EventArtwork({
    super.key,
    required this.event,
    this.large = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final color = _ambientFor(event.category);
    final radius = borderRadius ?? BorderRadius.circular(0);
    final heroUrl = event.heroImageUrl;
    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: large ? 16 / 10 : 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base surface — also the placeholder while the network
            // image streams in. The procedural layers below render
            // first so we never flash a blank black box.
            Container(color: AppColors.surfaceElevated),
            // Vertical depth gradient (subtle)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF111111), Color(0xFF050505)],
                ),
              ),
            ),
            // Tinted radial glow from bottom-center
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.85),
                  radius: large ? 0.85 : 1.1,
                  colors: [
                    color.withValues(alpha: large ? 0.55 : 0.45),
                    color.withValues(alpha: large ? 0.18 : 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.45, 1.0],
                ),
              ),
            ),
            if (large) ...[
              // Star dots (deterministic from event id)
              CustomPaint(
                painter: _DotPainter(seed: event.id.hashCode),
              ),
              // Mountain silhouette at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CustomPaint(
                  painter: _MountainPainter(seed: event.id.hashCode),
                  size: const Size.fromHeight(44),
                ),
              ),
            ],
            // Hero photo overlay — promoter / artist artwork when the
            // backend has it. Sits on top of the procedural layers so
            // the dark surface + glow keep showing through any
            // transparent edges of the source image, and so the
            // procedural artwork is the graceful fallback while the
            // network image is loading or unavailable.
            if (heroUrl != null && heroUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: heroUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 260),
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  static Color _ambientFor(EventCategory c) => switch (c) {
        EventCategory.music => AppColors.musicAmbient,
        EventCategory.sports => AppColors.sportsAmbient,
        EventCategory.festivals => AppColors.festivalsAmbient,
        EventCategory.outdoor => AppColors.outdoorAmbient,
        EventCategory.culture => AppColors.cultureAmbient,
      };
}

class _DotPainter extends CustomPainter {
  final int seed;
  _DotPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final paint = Paint()..style = PaintingStyle.fill;
    const count = 14;
    for (var i = 0; i < count; i++) {
      // Cluster dots in the upper-half — they're stars in the night sky.
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height * 0.7;
      final r = 0.8 + rng.nextDouble() * 1.6;
      final alpha = 0.35 + rng.nextDouble() * 0.55;
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) => old.seed != seed;
}

class _MountainPainter extends CustomPainter {
  final int seed;
  _MountainPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final path = Path()..moveTo(0, size.height);
    var x = 0.0;
    while (x < size.width) {
      final peakHeight = size.height * (0.4 + rng.nextDouble() * 0.55);
      final step = 18 + rng.nextDouble() * 24;
      x += step;
      path.lineTo(x - step / 2, size.height - peakHeight);
      path.lineTo(x, size.height);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF050505).withValues(alpha: 0.92);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MountainPainter old) => old.seed != seed;
}
