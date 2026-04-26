import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import '../../../data/models/photo_upload.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/smwhr_ambient_background.dart';
import '../services/exif_reader.dart';
import '../widgets/badge_frame_overlay.dart';
import '../widgets/shutter_button.dart';

/// Pantalla 08 — Camera.
///
/// Live preview wraps a [BadgeFrameOverlay] showing what the user's
/// badge will look like once they capture. Tap the shutter →
///   1. heavy haptic + 200 ms white flash
///   2. controller.takePicture() → temp file
///   3. repo.uploadPhoto() (multipart) — EXIF metadata wires in Session 6
///   4. push `/reveal/<badgeId>`
///
/// Falls back to a procedural shim when no cameras are available
/// (simulator) or when the user denies the permission. Both paths still
/// reach the reveal screen so dev iteration on Mac / iOS Simulator
/// keeps working without a physical device.
class CameraScreen extends ConsumerStatefulWidget {
  final String eventId;
  const CameraScreen({super.key, required this.eventId});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

enum _CameraInitState { initializing, ready, permissionDenied, unavailable }

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  _CameraInitState _state = _CameraInitState.initializing;
  bool _shouldOpenSettings = false;
  late final AnimationController _flash;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    _flash.dispose();
    super.dispose();
  }

  /// Pause/resume the camera with the app lifecycle. The camera package
  /// itself doesn't release the OS-level handle when the app is
  /// backgrounded, so we tear down + re-init manually.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeController();
      if (mounted) {
        setState(() => _state = _CameraInitState.initializing);
      }
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _disposeController() async {
    final ctrl = _controller;
    _controller = null;
    if (ctrl != null) {
      await ctrl.dispose();
    }
  }

  Future<void> _initCamera() async {
    final perm = await ref.read(permissionFlowProvider).requestForCamera();
    if (!perm.isGranted) {
      if (!mounted) return;
      setState(() {
        _state = _CameraInitState.permissionDenied;
        _shouldOpenSettings = perm.shouldOpenSettings;
      });
      return;
    }

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (_) {
      cameras = const [];
    }
    if (cameras.isEmpty) {
      // Simulator or device without a camera. Procedural shim takes over.
      if (!mounted) return;
      setState(() => _state = _CameraInitState.unavailable);
      return;
    }

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final ctrl = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _state = _CameraInitState.ready;
      });
    } catch (_) {
      await ctrl.dispose();
      if (!mounted) return;
      setState(() => _state = _CameraInitState.unavailable);
    }
  }

  Future<void> _capture(Event event) async {
    if (_capturing) return;
    setState(() => _capturing = true);
    HapticFeedback.heavyImpact();
    await _flash.forward(from: 0);
    _flash.reverse();

    File? captured;
    try {
      final ctrl = _controller;
      if (ctrl != null && ctrl.value.isInitialized) {
        final shot = await ctrl.takePicture();
        captured = await _moveToEventDir(File(shot.path), event.id);
      }
    } catch (_) {
      // Capture failed (controller died, OOM, perm revoked) — fall
      // through; the reveal can still hand back to the active quest.
    }

    final fileToUpload = captured ?? _shimFile(event.id);
    final metadata = captured != null
        ? await const ExifReader().read(captured)
        : const PhotoMetadata();

    final repo = ref.read(questsRepositoryProvider);
    PhotoUploadResult? result;
    try {
      result = await repo.uploadPhoto(
        eventId: event.id,
        photo: fileToUpload,
        metadata: metadata,
      );
    } catch (_) {
      // Soft-fail: photo couldn't reach the backend (offline, server
      // 5xx). The reveal still progresses; backend reconciliation will
      // pick up whatever data made it (locus + pings, possibly without
      // the photo).
    }

    if (!mounted) return;
    setState(() => _capturing = false);

    if (result != null && result.hasWarning) {
      _showVerificationWarning(result);
    }

    // Reveal screen receives a deterministic mock badge id while we
    // wait for the backend's finalize → badge issuance to land. The
    // photoId from the upload response isn't a badge id; the badge
    // gets minted later by `/quests/:id/finalize`.
    context.go(AppRoutes.reveal('bdg-001'));
  }

  void _showVerificationWarning(PhotoUploadResult result) {
    final issues = <String>[];
    if (!result.isExifValid) issues.add('EXIF incompleto');
    if (!result.isWithinTimeWindow) issues.add('fuera de la ventana del evento');
    if (!result.isInsideGeofence) issues.add('fuera del polígono');
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 6),
        content: Text(
          'Foto subida con observaciones: ${issues.join(', ')}. '
          'Tu insignia se emitirá con score reducido.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<File> _moveToEventDir(File source, String eventId) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/$eventId');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final dest = File('${dir.path}/${_uuid()}.jpg');
    return source.rename(dest.path).catchError((_) => source.copy(dest.path));
  }

  /// Mock-mode / simulator fallback path. `MockQuestsRepository` doesn't
  /// touch the file, so the bytes never matter; the path just has to be
  /// a `File`.
  File _shimFile(String eventId) => File('/tmp/smwhr-mock-$eventId.jpg');

  String _uuid() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = math.Random().nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    return '${ts}_$rand';
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(_cameraEventProvider(widget.eventId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Live preview (when ready) covers the whole screen; falls
          // back to the procedural ambient otherwise so the screen
          // never goes blank during init / on simulator.
          Positioned.fill(child: _Background(controller: _controller)),
          // Top-left framing bracket (decorative)
          const Positioned(
            top: 80,
            left: 22,
            child: _CornerBracket(),
          ),
          // Main content: badge frame preview + controls
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
              if (_state == _CameraInitState.permissionDenied) {
                return _PermissionDeniedBody(
                  onOpenSettings:
                      _shouldOpenSettings ? openAppSettings : null,
                  onClose: () {
                    if (context.canPop()) context.pop();
                  },
                );
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

class _Background extends StatelessWidget {
  final CameraController? controller;
  const _Background({required this.controller});

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const SmwhrAmbientBackground(
        pingCenter: Offset(0.5, 0.7),
        starCount: 30,
        pingRings: 4,
        showSweep: false,
      );
    }
    // Cover-fit so the preview fills the whole screen (default
    // CameraPreview is letterboxed by AspectRatio).
    final size = MediaQuery.sizeOf(context);
    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.width * ctrl.value.aspectRatio,
            child: CameraPreview(ctrl),
          ),
        ),
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

class _PermissionDeniedBody extends StatelessWidget {
  final VoidCallback? onOpenSettings;
  final VoidCallback onClose;

  const _PermissionDeniedBody({
    required this.onOpenSettings,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(
              'Necesitamos tu cámara',
              style: AppTypography.displayMedium.copyWith(
                fontSize: 26,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              onOpenSettings != null
                  ? 'Negaste el permiso. Ábrelo en Ajustes para capturar tu momento.'
                  : 'Sin cámara no podemos componer tu insignia. Concédenos permiso.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (onOpenSettings != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                ),
                onPressed: onOpenSettings,
                child: const Text('Abrir Ajustes'),
              ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onClose,
              child: Text(
                'Volver',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
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
          // Flash toggle ships post-soft-launch; default off keeps the
          // venue ambience intact in concert lighting.
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
