import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/smwhr_button.dart';
import '../widgets/event_artwork.dart';
import '../widgets/locked_badge_preview.dart';

/// Pantalla 06 — Event detail. Pulls the event by slug, renders the
/// hero artwork with overlaid title/venue/date, the intent CTA, the
/// going/network/verified stats row, the THE QUEST explainer, the
/// WHAT YOU'LL EARN locked badge preview, and the ticketing footer.
class EventDetailScreen extends ConsumerWidget {
  final String slug;
  const EventDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(_eventBySlugProvider(slug));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: eventAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              e.toString(),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ),
        data: (event) {
          if (event == null) {
            return _MissingEvent(slug: slug);
          }
          return _EventDetailBody(event: event);
        },
      ),
    );
  }
}

class _EventDetailBody extends ConsumerWidget {
  final Event event;
  const _EventDetailBody({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasIntentAsync = ref.watch(_hasIntentProvider(event.id));
    final hasIntent = hasIntentAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    final intentCount = ref.watch(_intentCountProvider(event.id)).value ??
        event.intentCount;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _HeroArt(event: event)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: AppSpacing.lg),
              SmwhrButton(
                label: hasIntent ? "You're in" : "I'll be there",
                variant: hasIntent
                    ? SmwhrButtonVariant.dark
                    : SmwhrButtonVariant.primary,
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final repo = ref.read(eventsRepositoryProvider);
                  if (hasIntent) {
                    await repo.removeIntent(event.id);
                  } else {
                    await repo.setIntent(event.id);
                  }
                  ref.invalidate(_hasIntentProvider(event.id));
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _StatsRow(
                going: intentCount,
                network: hasIntent ? 12 : 8,
                verified: 0,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionLabel('The quest'),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Show up. Stay for at least '
                '${event.dwellMinimumMin} minutes. Capture one moment. '
                'Earn a collectible proving you were there — verified by '
                'GPS, device trust, and dwell time.',
                style: AppTypography.bodyMedium.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionLabel("What you'll earn"),
              const SizedBox(height: AppSpacing.xs),
              LockedBadgePreview(event: event),
              const SizedBox(height: AppSpacing.lg),
              if (event.ticketmasterUrl != null)
                _TicketsLink(url: event.ticketmasterUrl!),
              const SizedBox(height: AppSpacing.xxl),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HeroArt extends StatelessWidget {
  final Event event;
  const _HeroArt({required this.event});

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: AspectRatio(
            aspectRatio: 5 / 6,
            child: EventArtwork(event: event, large: true),
          ),
        ),
        // Bottom darken overlay so overlaid text stays legible.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.bg.withValues(alpha: 0.85),
                    AppColors.bg,
                  ],
                  stops: const [0.55, 0.92, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Back chevron
        Positioned(
          top: padding.top + 8,
          left: AppSpacing.sm,
          child: Material(
            color: AppColors.bg.withValues(alpha: 0.55),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                context.pop();
              },
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        // Title block (bottom-left of hero)
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.artistName != null)
                Text(
                  event.artistName!.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                _titleLine(event.title),
                style: AppTypography.displayHero.copyWith(
                  fontSize: 38,
                  letterSpacing: -1.2,
                  height: 1.05,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${event.venueName} · ${_formatLongDate(event.startsAt)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Splits "BTS World Tour · Noche 1" → "Noche 1" so the hero shows
  /// the most distinctive line. If there's no separator, returns the
  /// whole title.
  static String _titleLine(String title) {
    final i = title.indexOf('·');
    if (i < 0 || i == title.length - 1) return title;
    return title.substring(i + 1).trim();
  }

  static String _formatLongDate(DateTime d) {
    const days = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dow = days[d.weekday - 1];
    final mon = months[d.month - 1];
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$dow, $mon ${d.day}, ${d.year} · $hour:$mm $ampm';
  }
}

class _StatsRow extends StatelessWidget {
  final int going;
  final int network;
  final int verified;
  const _StatsRow({
    required this.going,
    required this.network,
    required this.verified,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatPill(value: _compactCount(going), label: 'going'),
        const _Dot(),
        _StatPill(value: network.toString(), label: 'from network'),
        const _Dot(),
        _StatPill(value: verified.toString(), label: 'verified'),
      ],
    );
  }

  static String _compactCount(int n) {
    if (n >= 1000) {
      final k = (n / 1000);
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return n.toString();
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  const _StatPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Text(
        '·',
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.accent,
      ),
    );
  }
}

class _TicketsLink extends StatelessWidget {
  final String url;
  const _TicketsLink({required this.url});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Tickets available via official venue',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.arrow_outward_rounded,
          size: 14,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

class _MissingEvent extends StatelessWidget {
  final String slug;
  const _MissingEvent({required this.slug});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Event not found',
                style: AppTypography.displayMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(slug, style: AppTypography.monoSmall),
          ],
        ),
      ),
    );
  }
}

// ── Providers ──────────────────────────────────────────────────────

final _eventBySlugProvider =
    FutureProvider.autoDispose.family<Event?, String>((ref, slug) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getEventBySlug(slug);
});

final _hasIntentProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, eventId) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.hasIntent(eventId);
});

final _intentCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, eventId) {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.watchIntentCount(eventId);
});
