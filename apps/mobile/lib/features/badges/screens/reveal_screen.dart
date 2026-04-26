import 'dart:io';

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/badge.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/smwhr_ambient_background.dart';
import '../../../shared/widgets/smwhr_button.dart';
import '../widgets/badge_card.dart';

/// Pantalla 09 — Reveal animation.
///
/// Procedural reveal in pure Flutter (Lottie swap deferred to Phase 2):
/// - 0–500 ms: "QUEST COMPLETE" label fades in + frame drops in from above
///   (translateY -28 → 0 with `Curves.easeOutBack`).
/// - 400–1000 ms: photo composite scales + fades in (the EventArtwork
///   inside the badge ramps from 0.85→1.0 + opacity 0→1). Heavy haptic
///   fires at the start of this band.
/// - 1000–1600 ms: serial label types out + verified pill flashes in.
/// - 1600 ms onward: caption + Share / Save CTAs fade in.
class RevealScreen extends ConsumerStatefulWidget {
  final String badgeId;

  /// Captured photo (just took). When non-null, replaces the procedural
  /// EventArtwork in the badge frame's photo slot. The profile
  /// collection grid + badge-detail screen don't have this — they
  /// fall back to the EventArtwork until the server-side `sharp`
  /// pipeline lands and surfaces `composedImageUrl` post-launch.
  final File? photoFile;

  const RevealScreen({
    super.key,
    required this.badgeId,
    this.photoFile,
  });

  @override
  ConsumerState<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends ConsumerState<RevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _labelOpacity;
  late final Animation<double> _frameDrop;
  late final Animation<double> _frameOpacity;
  late final Animation<double> _photoOpacity;
  late final Animation<double> _photoScale;
  late final Animation<double> _serialOpacity;
  late final Animation<double> _ctaOpacity;

  bool _haptic1Fired = false;
  bool _haptic2Fired = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // 0–500 ms — frame drop + label
    _labelOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.32, curve: Curves.easeOut),
    );
    _frameDrop = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.05, 0.5, curve: Curves.easeOutBack),
    );
    _frameOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.05, 0.4, curve: Curves.easeOut),
    );

    // 400–1000 ms — photo composite
    _photoOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );
    _photoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    // 1000–1600 ms — serial / verified
    _serialOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOut),
    );

    // After intro — captions + CTAs
    _ctaOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
    );

    _intro.addListener(() {
      if (!_haptic1Fired && _intro.value >= 0.05) {
        HapticFeedback.lightImpact();
        _haptic1Fired = true;
      }
      if (!_haptic2Fired && _intro.value >= 0.5) {
        HapticFeedback.heavyImpact();
        _haptic2Fired = true;
      }
    });

    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeAsync = ref.watch(_badgeProvider(widget.badgeId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: SmwhrAmbientBackground(
              pingCenter: Offset(0.5, 0.5),
              starCount: 80,
              pingRings: 7,
            ),
          ),
          badgeAsync.when(
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
            data: (badge) {
              if (badge == null) {
                return const Center(child: Text('Badge not found'));
              }
              return _Body(
                badge: badge,
                photoFile: widget.photoFile,
                intro: _intro,
                labelOpacity: _labelOpacity,
                frameDrop: _frameDrop,
                frameOpacity: _frameOpacity,
                photoOpacity: _photoOpacity,
                photoScale: _photoScale,
                serialOpacity: _serialOpacity,
                ctaOpacity: _ctaOpacity,
                onShare: () {
                  HapticFeedback.mediumImpact();
                  context.push(AppRoutes.share(badge.id));
                },
                onSave: () {
                  HapticFeedback.lightImpact();
                  context.go(AppRoutes.badgeDetail(badge.id));
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Badge badge;
  final File? photoFile;
  final AnimationController intro;
  final Animation<double> labelOpacity;
  final Animation<double> frameDrop;
  final Animation<double> frameOpacity;
  final Animation<double> photoOpacity;
  final Animation<double> photoScale;
  final Animation<double> serialOpacity;
  final Animation<double> ctaOpacity;
  final VoidCallback onShare;
  final VoidCallback onSave;

  const _Body({
    required this.badge,
    required this.photoFile,
    required this.intro,
    required this.labelOpacity,
    required this.frameDrop,
    required this.frameOpacity,
    required this.photoOpacity,
    required this.photoScale,
    required this.serialOpacity,
    required this.ctaOpacity,
    required this.onShare,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: intro,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                Opacity(
                  opacity: labelOpacity.value,
                  child: Text(
                    'QUEST COMPLETE',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.accent,
                      letterSpacing: 2.6,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                Transform.translate(
                  offset: Offset(0, -28 * (1 - frameDrop.value)),
                  child: Opacity(
                    opacity: frameOpacity.value,
                    child: _AnimatedBadge(
                      badge: badge,
                      photoFile: photoFile,
                      photoOpacity: photoOpacity.value,
                      photoScale: photoScale.value,
                      serialOpacity: serialOpacity.value,
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                Opacity(
                  opacity: ctaOpacity.value,
                  child: Column(
                    children: [
                      Text(
                        'Quest complete.',
                        style: AppTypography.displayLarge.copyWith(
                          letterSpacing: -1,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _attendeeLine(badge),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SmwhrButton(
                        label: 'Share',
                        variant: SmwhrButtonVariant.primary,
                        leading: const Padding(
                          padding: EdgeInsets.only(left: AppSpacing.md),
                          child: Icon(
                            Icons.ios_share_rounded,
                            size: 20,
                          ),
                        ),
                        onPressed: onShare,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SmwhrButton(
                        label: 'Save to collection',
                        variant: SmwhrButtonVariant.outline,
                        leading: const Padding(
                          padding: EdgeInsets.only(left: AppSpacing.md),
                          child: Icon(
                            Icons.bookmark_outline_rounded,
                            size: 20,
                          ),
                        ),
                        onPressed: onSave,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _attendeeLine(Badge b) {
    final total = b.totalIssued ?? 0;
    if (total == 0) return 'You were one of the few who were there.';
    final formatted = total.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return 'You were one of $formatted who were there.';
  }
}

/// Wraps the BadgeCard with mid-reveal photo opacity/scale + a serial-line
/// opacity overlay, all driven by the parent's intro controller.
class _AnimatedBadge extends StatelessWidget {
  final Badge badge;
  final File? photoFile;
  final double photoOpacity;
  final double photoScale;
  final double serialOpacity;

  const _AnimatedBadge({
    required this.badge,
    required this.photoFile,
    required this.photoOpacity,
    required this.photoScale,
    required this.serialOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final photoOverride =
        photoFile != null ? FileImage(photoFile!) : null;
    return Transform.scale(
      scale: 0.95 + 0.05 * photoOpacity,
      child: Stack(
        children: [
          BadgeCard(
            badge: badge,
            dimmed: photoOpacity < 0.95,
            photoOverride: photoOverride,
          ),
          // The photo composite: dim the underlying artwork until the photo
          // opacity ramps up.
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 1 - photoOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.85),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusButton),
                  ),
                ),
              ),
            ),
          ),
          // Serial line cover: hide the serial row until its band starts.
          if (serialOpacity < 1)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 1 - serialOpacity,
                  child: Container(
                    height: 24,
                    color: AppColors.bg,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final _badgeProvider =
    FutureProvider.autoDispose.family<Badge?, String>((ref, id) async {
  final repo = ref.watch(badgesRepositoryProvider);
  return repo.getBadge(id);
});
