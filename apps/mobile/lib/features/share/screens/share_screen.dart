import 'dart:io';

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/badge.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/smwhr_ambient_background.dart';
import '../../../shared/widgets/smwhr_button.dart';
import '../services/share_image_generator.dart';
import '../widgets/share_card.dart';

/// Pantalla 11 — Share.
///
/// Shows the post-capture composed image (the BadgeCard + "I was
/// somewhere." caption + smwhr.quest footer). Two CTAs:
///   1. Magenta "Share" → captures the RepaintBoundary as a 1080-wide
///      PNG, writes it to a temp file, and hands off to share_plus.
///   2. Outline "Save to camera roll" — Phase 2 (gal_2 / image_gallery_saver).
class ShareScreen extends ConsumerStatefulWidget {
  final String badgeId;
  const ShareScreen({super.key, required this.badgeId});

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.mediumImpact();
    try {
      final bytes = await ShareImageGenerator.capture(_boundaryKey);
      if (bytes == null || !mounted) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/smwhr-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'I was somewhere. @smwhr',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorBackground,
          content: Text(
            e.toString(),
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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
              pingCenter: Offset(0.5, 0.4),
              starCount: 50,
              pingRings: 5,
              showSweep: false,
            ),
          ),
          SafeArea(
            child: badgeAsync.when(
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
                  boundaryKey: _boundaryKey,
                  isSharing: _sharing,
                  onShare: _share,
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
  final Badge badge;
  final GlobalKey boundaryKey;
  final bool isSharing;
  final VoidCallback onShare;

  const _Body({
    required this.badge,
    required this.boundaryKey,
    required this.isSharing,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          _TopBar(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ShareCard(badge: badge, boundaryKey: boundaryKey),
              ),
            ),
          ),
          SmwhrButton(
            label: 'Share',
            variant: SmwhrButtonVariant.primary,
            isLoading: isSharing,
            leading: const Padding(
              padding: EdgeInsets.only(left: AppSpacing.md),
              child: Icon(Icons.ios_share_rounded, size: 20),
            ),
            onPressed: isSharing ? null : onShare,
          ),
          const SizedBox(height: AppSpacing.xs),
          SmwhrButton(
            label: 'Save to camera roll',
            variant: SmwhrButtonVariant.outline,
            leading: const Padding(
              padding: EdgeInsets.only(left: AppSpacing.md),
              child: Icon(Icons.download_rounded, size: 20),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surface,
                  content: Text(
                    'Camera roll save lands in Phase 2.',
                    style: AppTypography.bodySmall,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (GoRouter.of(context).canPop())
          SizedBox(
            width: 40,
            height: 40,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
                child: const Icon(
                  Icons.close_rounded,
                  size: 22,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

final _badgeProvider =
    FutureProvider.autoDispose.family<Badge?, String>((ref, id) async {
  final repo = ref.watch(badgesRepositoryProvider);
  return repo.getBadge(id);
});
