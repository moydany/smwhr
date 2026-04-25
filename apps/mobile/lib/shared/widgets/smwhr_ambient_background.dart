import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Ambient background reused on the "magical" screens (splash/auth, reveal,
/// soon: active quest). Five layers stacked back-to-front:
///
///   1. Drifting grid (`smwhrGridPan` 40 s linear) — subtle white lines.
///   2. Drifting radial glow (`smwhrDrift` 16-22 s ease-in-out) — magenta blob.
///   3. Slowly rotating sweep (`smwhrSweep` 18 s linear) — soft conic beam.
///   4. Twinkling stars (`smwhrStar` 3-7 s ease-in-out) — N white pixels.
///   5. Expanding ping rings (`smwhrPing` 6.6 s ease-out, staggered) — 6 rings
///      pulsing outward from the [pingCenter] in fractional coords.
///
/// All layers honour `IgnorePointer`, so the background never steals taps
/// from foreground content.
class SmwhrAmbientBackground extends StatefulWidget {
  /// Fractional center of the ping rings + radial glow (0..1, 0..1).
  final Offset pingCenter;
  final int starCount;
  final int pingRings;
  final bool showSweep;

  const SmwhrAmbientBackground({
    super.key,
    this.pingCenter = const Offset(0.5, 0.45),
    this.starCount = 60,
    this.pingRings = 6,
    this.showSweep = true,
  });

  @override
  State<SmwhrAmbientBackground> createState() => _SmwhrAmbientBackgroundState();
}

class _SmwhrAmbientBackgroundState extends State<SmwhrAmbientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _ticker;
  late final List<_StarSpec> _stars;
  final Random _rng = Random(42);

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _stars = List.generate(widget.starCount, (_) => _StarSpec.random(_rng));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _ticker,
          builder: (context, _) {
            return CustomPaint(
              painter: _AmbientPainter(
                t: _ticker.value, // 0..1 over 60s
                stars: _stars,
                pingCenter: widget.pingCenter,
                pingRings: widget.pingRings,
                showSweep: widget.showSweep,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _StarSpec {
  final Offset position; // fractional 0..1
  final double phase; // 0..1
  final double period; // seconds (3..7)
  final double minOpacity; // 0..0.4
  final double maxOpacity; // 0.6..1
  final double size; // 0.6..1.6 px

  _StarSpec({
    required this.position,
    required this.phase,
    required this.period,
    required this.minOpacity,
    required this.maxOpacity,
    required this.size,
  });

  factory _StarSpec.random(Random r) => _StarSpec(
        position: Offset(r.nextDouble(), r.nextDouble()),
        phase: r.nextDouble(),
        period: 3 + r.nextDouble() * 4,
        minOpacity: 0.15 + r.nextDouble() * 0.2,
        maxOpacity: 0.7 + r.nextDouble() * 0.3,
        size: 0.6 + r.nextDouble() * 1.0,
      );
}

class _AmbientPainter extends CustomPainter {
  final double t; // 0..1 over 60s
  final List<_StarSpec> stars;
  final Offset pingCenter;
  final int pingRings;
  final bool showSweep;

  _AmbientPainter({
    required this.t,
    required this.stars,
    required this.pingCenter,
    required this.pingRings,
    required this.showSweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wallSeconds = t * 60.0;
    final cx = size.width * pingCenter.dx;
    final cy = size.height * pingCenter.dy;
    final maxR = size.width * 0.55;

    _paintGrid(canvas, size, wallSeconds);
    _paintDrift(canvas, size, cx, cy, wallSeconds);
    if (showSweep) _paintSweep(canvas, size, cx, cy, wallSeconds);
    _paintStars(canvas, size, wallSeconds);
    _paintPingRings(canvas, size, cx, cy, maxR, wallSeconds);
  }

  // ── Layers ──────────────────────────────────────────────────────────

  void _paintGrid(Canvas canvas, Size size, double seconds) {
    // 60 px grid panning -60 px over 40 s.
    const cell = 60.0;
    final progress = (seconds % 40) / 40;
    final dx = -progress * cell;
    final dy = -progress * cell;

    final paint = Paint()
      ..color = const Color(0x06FFFFFF) // ~2.4% white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double x = dx; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = dy; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintDrift(Canvas canvas, Size size, double cx, double cy, double s) {
    // Two drifting magenta radial gradients with different periods.
    _paintDriftBlob(canvas, size, cx, cy, s, period: 16, scale: 1.0,
        radiusFactor: 0.65, intensity: 0.20);
    _paintDriftBlob(canvas, size, cx + 30, cy + 80, s + 5,
        period: 22, scale: 0.85, radiusFactor: 0.45, intensity: 0.12);
  }

  void _paintDriftBlob(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double seconds, {
    required double period,
    required double scale,
    required double radiusFactor,
    required double intensity,
  }) {
    final p = (seconds % period) / period; // 0..1
    // Drift transform: 0 → (20,-24)*1.08 → (-18,18)*0.96 → 0
    double tx, ty, sc;
    if (p < 0.33) {
      final k = p / 0.33;
      tx = 20 * k;
      ty = -24 * k;
      sc = 1 + 0.08 * k;
    } else if (p < 0.66) {
      final k = (p - 0.33) / 0.33;
      tx = 20 - (38 * k);
      ty = -24 + (42 * k);
      sc = 1.08 - (0.12 * k);
    } else {
      final k = (p - 0.66) / 0.34;
      tx = -18 + (18 * k);
      ty = 18 - (18 * k);
      sc = 0.96 + (0.04 * k);
    }

    final radius = size.width * radiusFactor * sc * scale;
    final rect = Rect.fromCircle(
      center: Offset(cx + tx, cy + ty),
      radius: radius,
    );

    final shader = RadialGradient(
      colors: [
        AppColors.accent.withValues(alpha: intensity),
        AppColors.accent.withValues(alpha: intensity * 0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 1.0],
    ).createShader(rect);

    final paint = Paint()..shader = shader;
    canvas.drawRect(rect, paint);
  }

  void _paintSweep(Canvas canvas, Size size, double cx, double cy, double s) {
    // 18 s rotation of a soft beam (conic gradient simulated with Path).
    final angle = ((s % 18) / 18) * 2 * pi;
    final radius = size.width * 0.7;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    final shader = SweepGradient(
      colors: [
        Colors.transparent,
        AppColors.accent.withValues(alpha: 0.06),
        Colors.transparent,
      ],
      stops: const [0.45, 0.5, 0.55],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));

    final paint = Paint()..shader = shader;
    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.restore();
  }

  void _paintStars(Canvas canvas, Size size, double s) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in stars) {
      final periodPos = ((s / star.period) + star.phase) % 1.0;
      // 0,1 ⇒ minOpacity, 0.5 ⇒ maxOpacity
      final wave = (sin(periodPos * 2 * pi - pi / 2) + 1) / 2; // 0..1
      final opacity =
          star.minOpacity + (star.maxOpacity - star.minOpacity) * wave;

      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(star.position.dx * size.width,
            star.position.dy * size.height),
        star.size,
        paint,
      );
    }
  }

  void _paintPingRings(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double maxR,
    double seconds,
  ) {
    const period = 6.6;
    final stagger = period / pingRings;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i < pingRings; i++) {
      final delay = i * stagger;
      var p = ((seconds - delay) % period) / period;
      if (p < 0) p += 1;
      // Scale 0.2 → 1, opacity 0 → 0.55 (15%) → 0
      final scale = 0.2 + 0.8 * p;
      double opacity;
      if (p < 0.15) {
        opacity = (p / 0.15) * 0.55;
      } else {
        opacity = 0.55 * (1 - ((p - 0.15) / 0.85));
      }
      paint.color = AppColors.accent.withValues(alpha: opacity);
      canvas.drawCircle(Offset(cx, cy), maxR * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => old.t != t;
}
