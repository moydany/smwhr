import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/smwhr_ambient_background.dart';
import '../widgets/badge_frame_overlay.dart';
import '../widgets/shutter_button.dart';

/// Pantalla 08 — Camera.
///
/// Live preview wraps a [BadgeFrameOverlay] showing what the user's
/// badge will look like once they capture. The dashed photo area is
/// where the actual selfie composites in. Tap the shutter →
///   1. heavy haptic + 200 ms white flash
///   2. mockQuestsRepository.uploadPhoto (1.5 s simulated upload)
///   3. push `/reveal/<badgeId>` (in mock mode the badge id is generated
///      from the event id)
///
/// Real CameraController integration lands in Phase 2 — the moment we
/// have a signed Apple Developer team for entitlements. Until then the
/// "viewfinder" is the ambient background drawing through.
class CameraScreen extends ConsumerStatefulWidget {
  final String eventId;
  const CameraScreen({super.key, required this.eventId});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  Future<void> _capture(Event event) async {
    if (_capturing) return;
    setState(() => _capturing = true);
    HapticFeedback.heavyImpact();
    await _flash.forward(from: 0);
    _flash.reverse();

    // Simulate upload + reveal hand-off through the mock repo.
    // The real impl writes the file path here.
    final dummyFile = File('/tmp/smwhr-mock-${event.id}.jpg');
    final repo = ref.read(questsRepositoryProvider);
    await repo.uploadPhoto(eventId: event.id, photo: dummyFile);

    if (!mounted) return;
    setState(() => _capturing = false);

    // Issue a deterministic mock badge id keyed off the event so
    // /reveal can find it in the seeded badges. Falls back to the
    // first seeded badge when no specific badge exists yet.
    context.go(AppRoutes.reveal('bdg-001'));
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(_cameraEventProvider(widget.eventId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: SmwhrAmbientBackground(
              pingCenter: Offset(0.5, 0.7),
              starCount: 30,
              pingRings: 4,
              showSweep: false,
            ),
          ),
          // Top-left framing bracket (decorative)
          const Positioned(
            top: 80,
            left: 22,
            child: _CornerBracket(),
          ),
          // Main content: badge frame preview
          eventAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (e, _) => Center(
              child: Text(
                e.toString(),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
            data: (event) {
              if (event == null) {
                return const Center(child: Text('Event not found'));
              }
              return _Body(
                event: event,
                isCapturing: _capturing,
                onCapture: () => _capture(event),
                onClose: () {
                  if (context.canPop()) context.pop();
                },
              );
            },
          ),
          // White flash overlay
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) {
                if (_flash.value == 0) return const SizedBox.shrink();
                return Container(
                  color: Colors.white.withValues(alpha: _flash.value * 0.7),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Event event;
  final bool isCapturing;
  final VoidCallback onCapture;
  final VoidCallback onClose;

  const _Body({
    required this.event,
    required this.isCapturing,
    required this.onCapture,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          children: [
            const Spacer(flex: 2),
            BadgeFrameOverlay(event: event),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Hold steady. Capture the moment that proves you were here.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            const Spacer(flex: 1),
            _Controls(
              isCapturing: isCapturing,
              onCapture: onCapture,
              onClose: onClose,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onCapture;
  final VoidCallback onClose;

  const _Controls({
    required this.isCapturing,
    required this.onCapture,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIconButton(
          icon: Icons.close_rounded,
          onPressed: isCapturing ? null : onClose,
        ),
        ShutterButton(
          isLoading: isCapturing,
          onPressed: isCapturing ? null : onCapture,
        ),
        _RoundIconButton(
          icon: Icons.flash_off_rounded,
          // Flash toggle ships with real CameraController in Phase 2.
          onPressed: () {
            HapticFeedback.selectionClick();
          },
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _RoundIconButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 22,
            color: onPressed != null
                ? AppColors.textPrimary
                : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _CornerBracketPainter(),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0), Offset(size.width * 0.7, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height * 0.7), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter old) => false;
}

final _cameraEventProvider =
    FutureProvider.autoDispose.family<Event?, String>((ref, eventId) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getEventById(eventId);
});
