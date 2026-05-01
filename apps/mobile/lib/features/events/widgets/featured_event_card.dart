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
import '../../../shared/widgets/smwhr_button.dart';
import 'event_artwork.dart';

/// Big hero card on the home feed for the next event the user RSVP'd to.
/// Mirrors the HTML mock — FEATURED pill at the top of the artwork,
/// title/venue/date stacked, going-count + "I'll be there" CTA in a row.
class FeaturedEventCard extends ConsumerWidget {
  final Event event;
  const FeaturedEventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(AppRoutes.eventDetail(event.slug));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                EventArtwork(event: event, large: true),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: _FeaturedPill(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.displaySmall.copyWith(
                      fontSize: 22,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.artistName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.artistName!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${event.venueName} · ${event.city}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(event.startsAt),
                    style: AppTypography.monoSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BottomRow(event: event),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final dow = days[d.weekday - 1];
    final mon = months[d.month - 1];
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$dow, $mon ${d.day.toString().padLeft(2, '0')} · $hour:$mm $ampm';
  }
}

class _FeaturedPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        'FEATURED',
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _BottomRow extends ConsumerStatefulWidget {
  final Event event;
  const _BottomRow({required this.event});

  @override
  ConsumerState<_BottomRow> createState() => _BottomRowState();
}

class _BottomRowState extends ConsumerState<_BottomRow> {
  /// Optimistic local copy of the event. The button updates this
  /// instantly on tap so the user gets immediate feedback; the network
  /// call replaces it with the server's authoritative version (which
  /// also bumps `intentCount`). Reverts on error.
  late Event _local = widget.event;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _BottomRow old) {
    super.didUpdateWidget(old);
    // The home feed refresh hands us a new prop after pull-to-refresh.
    // Adopt the fresh values whenever the parent rerenders with a
    // different intent count or the same event id.
    if (old.event.id != widget.event.id ||
        old.event.intentCount != widget.event.intentCount) {
      _local = widget.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasIntentAsync = ref.watch(_hasIntentProvider(_local.id));
    final hasIntent = hasIntentAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '${_compactCount(_local.intentCount)} going',
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        SmwhrButton(
          label: _busy
              ? '…'
              : (hasIntent ? "You're in" : "I'll be there"),
          variant: hasIntent
              ? SmwhrButtonVariant.dark
              : SmwhrButtonVariant.primary,
          fullWidth: false,
          isLoading: _busy,
          onPressed: _busy ? null : () => _toggleIntent(hasIntent),
        ),
      ],
    );
  }

  Future<void> _toggleIntent(bool hasIntent) async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final updated = hasIntent
          ? await repo.removeIntent(_local.id)
          : await repo.setIntent(_local.id);
      if (!mounted) return;
      setState(() => _local = updated);
      // Bump the cached `_hasIntentProvider` so any other widget on
      // the home (or this card itself, on next rebuild) reflects the
      // change without an extra network hit.
      ref.invalidate(_hasIntentProvider(_local.id));
    } catch (_) {
      // Leave the optimistic state alone — the provider invalidate
      // below will refetch and snap us back to truth.
      if (!mounted) return;
      ref.invalidate(_hasIntentProvider(_local.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _compactCount(int n) {
    if (n >= 1000) {
      final k = (n / 1000);
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return n.toString();
  }
}

/// Per-event helper provider for the cached "has the user RSVP'd"
/// boolean. AutoDispose so navigating away from the home stops
/// holding onto stale state. Intent count comes from the [Event]
/// prop directly — `setIntent` returns an updated Event so we don't
/// need a polling stream on the home feed.
final _hasIntentProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, eventId) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.hasIntent(eventId);
});
