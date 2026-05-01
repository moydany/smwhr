import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import '../../../data/models/quest.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/smwhr_button.dart';
import '../../quest/providers/quest_state_provider.dart';
import '../../quest/widgets/quest_active_pill.dart';
import '../../quest/widgets/verification_task_row.dart';
import '../widgets/event_artwork.dart';
import '../widgets/event_location_map.dart';
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

class _EventDetailBody extends ConsumerStatefulWidget {
  final Event event;
  const _EventDetailBody({required this.event});

  @override
  ConsumerState<_EventDetailBody> createState() => _EventDetailBodyState();
}

class _EventDetailBodyState extends ConsumerState<_EventDetailBody> {
  /// Optimistic local copy of the event. Tap → server returns the
  /// updated row → we replace this. Reverts on error via the
  /// `_hasIntentProvider` invalidation snapping us back to truth.
  late Event _local = widget.event;
  bool _busy = false;

  /// Local "claim is in flight" flag for the manual finalize button.
  /// Separate from [_busy] so the intent toggle and the claim action
  /// don't fight over the same spinner.
  bool _claiming = false;

  /// Has the auto-start path fired this session? `QuestTracker.startQuest`
  /// is itself idempotent, but we don't want to re-trigger the iOS
  /// permission sheet on every rebuild. Flips back to `false` if the
  /// user toggles intent off, so re-RSVP'ing kicks the tracker again.
  bool _autoStartTried = false;

  /// When the silent auto-start path throws (permission denied,
  /// tracker conflict, hive error), we capture the message here so
  /// the in-progress banner can surface it instead of pretending the
  /// quest is fine and silently failing to record pings.
  String? _trackerStartupError;

  /// Has the silent auto-claim attempt fired this screen visit? When
  /// the screen renders with `canClaim == true && badgeId == null`,
  /// we fire `finalizeQuest` once in the background. If the verifier
  /// passes, the status provider invalidation flips the screen from
  /// "Reclamar insignia" → "Ver tu insignia" without the user having
  /// to tap anything. If it fails (verifier returns null), the manual
  /// "Reclamar" button stays visible as the explicit fallback.
  /// Resets when claim conditions go away, so a re-entry to claim
  /// gets one fresh silent shot.
  bool _autoClaimTried = false;

  @override
  void didUpdateWidget(covariant _EventDetailBody old) {
    super.didUpdateWidget(old);
    if (old.event.id != widget.event.id ||
        old.event.intentCount != widget.event.intentCount) {
      _local = widget.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _local;
    final hasIntentAsync = ref.watch(_hasIntentProvider(event.id));
    final hasIntent = hasIntentAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    final shouldRunQuest = hasIntent && event.isLive;
    // Quest status keeps polling after the event ends as long as the
    // user has intent — that's how the "Reclamar insignia" CTA stays
    // alive in the post-event window when the badge hasn't been issued
    // yet (verifier was still warming up, or finalize never landed).
    // Without this, the UI snaps back to the "I'll be there" CTA the
    // moment the event window closes and the user has no way to claim.
    final shouldShowQuestStatus =
        hasIntent && (event.isLive || event.isPast);

    // Auto-start the tracker the first time we see (intent + live).
    // Idempotent on the QuestTracker side, but we still gate with a
    // local flag so the iOS "Always" permission sheet only fires once
    // per visit.
    if (shouldRunQuest && !_autoStartTried) {
      _autoStartTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await ref.read(questsRepositoryProvider).startQuest(event.id);
          debugPrint('[smwhr.quest] tracker started for ${event.slug}');
          if (mounted && _trackerStartupError != null) {
            setState(() => _trackerStartupError = null);
          }
        } catch (e) {
          debugPrint(
              '[smwhr.quest] tracker FAILED for ${event.slug}: $e');
          if (mounted) {
            setState(() => _trackerStartupError = e.toString());
          }
        }
      });
    }
    if (!shouldRunQuest && _autoStartTried) {
      // User went from "in + live" back to "no intent" or "post" —
      // re-arm the auto-start so the next live entry triggers it.
      _autoStartTried = false;
      _trackerStartupError = null;
    }

    final liveStatusAsync = shouldShowQuestStatus
        ? ref.watch(questStatusProvider(event.id))
        : null;
    final liveStatus = liveStatusAsync?.maybeWhen(
      data: (s) => s,
      orElse: () => null,
    );
    final canClaim = _canClaimNow(liveStatus);

    // Silent auto-claim: when the screen first observes "ready to
    // claim but no badge yet", fire finalize once in the background.
    // If it passes, the user lands directly on "Ver tu insignia"
    // without ever seeing the manual button. The button stays as the
    // explicit fallback when the verifier rejects.
    if (canClaim && !_autoClaimTried) {
      _autoClaimTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _silentAutoClaim(event.id);
      });
    }
    if (!canClaim && _autoClaimTried) {
      _autoClaimTried = false;
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _HeroArt(event: event)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: AppSpacing.lg),
              if (liveStatus?.badgeId != null)
                SmwhrButton(
                  label: 'Ver tu insignia',
                  variant: SmwhrButtonVariant.primary,
                  leading: const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.md),
                    child: Icon(Icons.auto_awesome_rounded, size: 20),
                  ),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    context.push(AppRoutes.reveal(liveStatus!.badgeId!));
                  },
                )
              else if (canClaim)
                SmwhrButton(
                  label: _claiming ? '…' : 'Reclamar insignia',
                  variant: SmwhrButtonVariant.primary,
                  isLoading: _claiming,
                  leading: const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.md),
                    child: Icon(Icons.workspace_premium_rounded, size: 20),
                  ),
                  onPressed: _claiming ? null : () => _claimBadge(event.id),
                )
              else if (shouldRunQuest && _trackerStartupError != null)
                _TrackerStartupErrorPanel(
                  error: _trackerStartupError!,
                  onRetry: () {
                    setState(() {
                      _trackerStartupError = null;
                      _autoStartTried = false;
                    });
                  },
                )
              else if (shouldRunQuest)
                _QuestInProgressBanner(status: liveStatus)
              else if (event.isPast)
                // Event is over and we have no actionable state: no
                // badge, no claim path, no quest in progress. Showing
                // the "I'll be there" toggle would suggest you can
                // still RSVP, which is misleading. Just stay quiet —
                // the photos + tasks below give the user enough
                // status context.
                const SizedBox.shrink()
              else
                SmwhrButton(
                  label: _busy
                      ? '…'
                      : (hasIntent ? "You're in" : "I'll be there"),
                  variant: hasIntent
                      ? SmwhrButtonVariant.dark
                      : SmwhrButtonVariant.primary,
                  isLoading: _busy,
                  onPressed: _busy ? null : () => _toggleIntent(hasIntent),
                ),
              const SizedBox(height: AppSpacing.md),
              _StatsRow(
                going: event.intentCount,
                network: hasIntent ? 12 : 8,
                verified: 0,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionLabel('The quest'),
              const SizedBox(height: AppSpacing.sm),
              _QuestTaskList(
                liveStatus: liveStatus,
                onCapturePhoto: shouldRunQuest && (liveStatus?.hasArrived ?? false)
                    ? () {
                        HapticFeedback.heavyImpact();
                        context.push(AppRoutes.camera(event.id));
                      }
                    : null,
              ),
              if ((liveStatus?.photos.isNotEmpty ?? false)) ...[
                const SizedBox(height: AppSpacing.xl),
                _SectionLabel('Tus fotos'),
                const SizedBox(height: AppSpacing.sm),
                _PhotoGalleryStrip(photos: liveStatus!.photos),
              ],
              const SizedBox(height: AppSpacing.xl),
              _SectionLabel('Where'),
              const SizedBox(height: AppSpacing.xs),
              EventLocationMap(event: event),
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

  /// True when the user has finished what the verifier needs but the
  /// badge hasn't been issued yet — the moment the manual "Reclamar
  /// insignia" CTA should light up. Mirrors the server-side gates
  /// (`hasArrived` + `presenceRatio >= 0.7`) using the per-task ledger
  /// the status endpoint surfaces, so we never offer the button when
  /// finalize would predictably return null. The photo task is *not*
  /// required — backend scores the photo as bonus points, not a hard
  /// gate. Returning false also when [liveStatus] is null keeps the
  /// button hidden during cold-start before the first poll lands.
  bool _canClaimNow(QuestStatus? liveStatus) {
    if (liveStatus == null) return false;
    if (liveStatus.badgeId != null) return false;
    final tasks = liveStatus.tasks;
    if (tasks.isEmpty) return false;
    final arrival = tasks.firstWhere(
      (t) => t.id == VerificationTaskId.arrival,
      orElse: () => const VerificationTask(
        id: VerificationTaskId.arrival,
        status: VerificationTaskStatus.pending,
      ),
    );
    final spot = tasks.firstWhere(
      (t) => t.id == VerificationTaskId.spotChecks,
      orElse: () => const VerificationTask(
        id: VerificationTaskId.spotChecks,
        status: VerificationTaskStatus.pending,
      ),
    );
    if (!arrival.isDone) return false;
    final n = spot.progressNumerator ?? 0;
    final m = spot.progressDenominator ?? 0;
    if (m == 0) return spot.isDone;
    return (n / m) >= 0.7;
  }

  /// Background finalize attempt with no UX side effects on failure.
  /// On success, invalidates the status provider so the screen flips
  /// to "Ver tu insignia" — no auto-navigation to reveal, the user
  /// stays on the event detail and can decide when to view it. On
  /// failure (network, verifier-rejects, anything), we swallow: the
  /// manual "Reclamar insignia" button is the user-facing fallback.
  Future<void> _silentAutoClaim(String eventId) async {
    try {
      final repo = ref.read(questsRepositoryProvider);
      final badgeId = await repo.finalizeQuest(eventId);
      if (badgeId != null && mounted) {
        ref.invalidate(questStatusProvider(eventId));
      }
    } catch (_) {/* swallow — manual button stays as the fallback */}
  }

  Future<void> _claimBadge(String eventId) async {
    HapticFeedback.heavyImpact();
    setState(() => _claiming = true);
    try {
      final repo = ref.read(questsRepositoryProvider);
      final badgeId = await repo.finalizeQuest(eventId);
      if (!mounted) return;
      if (badgeId != null) {
        // Trigger an immediate status refresh so the next rebuild swaps
        // the claim CTA for "Ver tu insignia". The poll loop would pick
        // it up within 5s anyway, but invalidating here keeps the
        // transition snappy.
        ref.invalidate(questStatusProvider(eventId));
        context.push(AppRoutes.reveal(badgeId));
      } else {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            duration: const Duration(seconds: 6),
            content: Text(
              'Aún no llegamos al umbral de verificación. Sigue capturando o intenta de nuevo en unos minutos.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorBackground,
          duration: const Duration(seconds: 6),
          content: Text(
            'No se pudo emitir tu insignia: $e',
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
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
      ref.invalidate(_hasIntentProvider(_local.id));
    } catch (_) {
      // Snap back to server truth — invalidating refetches the
      // provider, which in turn cancels the optimistic flip.
      if (!mounted) return;
      ref.invalidate(_hasIntentProvider(_local.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                event.title,
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
                '${event.venueName} · ${_formatLongDate(event.startsAt, event.endsAt)}',
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

  static String _formatLongDate(DateTime d, [DateTime? end]) {
    const days = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dow = days[d.weekday - 1];
    final mon = months[d.month - 1];
    final startTime = _hhmm(d);
    final startAmpm = d.hour >= 12 ? 'PM' : 'AM';
    if (end != null) {
      final endTime = _hhmm(end);
      final endAmpm = end.hour >= 12 ? 'PM' : 'AM';
      // Same AM/PM half-day: show the suffix once at the end so the
      // range reads tighter ("8:00 – 9:00 AM" vs "8:00 AM – 9:00 AM").
      final timePart = startAmpm == endAmpm
          ? '$startTime – $endTime $startAmpm'
          : '$startTime $startAmpm – $endTime $endAmpm';
      return '$dow, $mon ${d.day}, ${d.year} · $timePart';
    }
    return '$dow, $mon ${d.day}, ${d.year} · $startTime $startAmpm';
  }

  static String _hhmm(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hour:$mm';
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

/// Verification checklist on the event detail page. Two modes:
///
///   - **Preview** (`liveStatus == null`) — quest hasn't started yet
///     (event is pre, or the user hasn't RSVP'd). Every row shows the
///     pending state with a description of what unlocks it. This is
///     the "promise" we make to the user before they commit.
///   - **Live** (`liveStatus != null`) — the tracker is running. Each
///     row reflects the real state from [QuestStatus] (pending /
///     active / done) including dwell counter and spot-check N/M.
///
/// The same widget renders both so the visual hierarchy stays
/// identical between "what you'll do" and "what you've done".
class _QuestTaskList extends StatelessWidget {
  final QuestStatus? liveStatus;

  /// Tap handler for the photo row. Non-null only when the quest is
  /// running AND the user has arrived at the venue — that's the
  /// moment the camera unlocks. Stays non-null after the first
  /// capture so the user can take additional photos during the show.
  final VoidCallback? onCapturePhoto;

  const _QuestTaskList({this.liveStatus, this.onCapturePhoto});

  @override
  Widget build(BuildContext context) {
    final tasks = liveStatus?.tasks;

    VerificationTask? taskFor(VerificationTaskId id) =>
        tasks?.firstWhere(
          (t) => t.id == id,
          orElse: () => VerificationTask(id: id, status: VerificationTaskStatus.pending),
        );

    // Verification model (R0.1+):
    //   - **Llegada** confirms the user reached the venue.
    //   - **Spot-checks N/M** is the presence signal — a percentage of
    //     random GPS reads inside the polygon. Spoof-resistant by
    //     unpredictable timing; tolerant of brief steps outside (a
    //     bathroom break doesn't blow up a continuous-dwell counter
    //     anymore, because we don't gate on continuous dwell).
    //   - **Foto** anchors the badge to a real captured moment.
    //
    // Server-side `dwellMinutes` is still computed as a soft input to
    // the badge scoring, but we don't surface it as a user-facing task
    // — telling someone they need to "stay 5 min continuous" forces
    // them to white-knuckle the time when the real verification is
    // about presence percentage, not stopwatch time.
    final arrival = taskFor(VerificationTaskId.arrival);
    final spot = taskFor(VerificationTaskId.spotChecks);
    final photo = taskFor(VerificationTaskId.photo);

    final rows = <Widget>[
      VerificationTaskRow(
        label: 'Llega al venue',
        status: arrival?.status ?? VerificationTaskStatus.pending,
        hint: arrival?.isDone == true ? null : 'Confirmamos tu llegada',
      ),
      VerificationTaskRow(
        label: 'Verificaciones aleatorias',
        status: spot?.status ?? VerificationTaskStatus.pending,
        hint: spot?.isDone == true
            ? 'Tu presencia quedó verificada'
            : 'Te verificamos en momentos aleatorios durante el evento',
        trailing: spot?.progressDenominator == null
            ? null
            : '${spot!.progressNumerator ?? 0}/${spot.progressDenominator}',
      ),
      _PhotoTaskRow(
        status: photo?.status ?? VerificationTaskStatus.pending,
        hint: photo?.isDone == true
            ? 'Tap para capturar otra'
            : 'Tómala cuando quieras durante el show',
        onTap: onCapturePhoto,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1)
            const Divider(height: 1, color: AppColors.borderSoft),
        ],
      ],
    );
  }
}

/// Horizontal strip of photo thumbnails captured during the event.
/// Surfaces under the quest checklist as the user accumulates
/// captures — instant visual confirmation that the shutter worked,
/// even before the upload drainer finishes shipping the file.
///
/// First photo (chronologically) gets a magenta border to mark it as
/// the badge anchor. The rest are bonus moments.
class _PhotoGalleryStrip extends StatelessWidget {
  final List<EventPhoto> photos;
  const _PhotoGalleryStrip({required this.photos});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, i) {
          final p = photos[i];
          final isAnchor = i == 0;
          return Container(
            width: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
              border: Border.all(
                color: isAnchor ? AppColors.accent : AppColors.borderSoft,
                width: isAnchor ? 1.5 : 1,
              ),
              color: AppColors.surfaceElevated,
            ),
            clipBehavior: Clip.antiAlias,
            child: p.publicUrl == null || p.publicUrl!.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 22,
                      color: AppColors.textTertiary,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: p.publicUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// Photo row variant — wraps [VerificationTaskRow] with a camera-icon
/// affordance on the right and makes the whole row tappable when the
/// camera is reachable (user has arrived at the venue).
///
/// After the first capture we keep the row tappable so the user can
/// add additional photos during the show — the badge anchors to the
/// FIRST verified photo (server-side), so subsequent captures don't
/// change verification, they just enrich the user's record of the
/// event.
class _PhotoTaskRow extends StatelessWidget {
  final VerificationTaskStatus status;
  final String? hint;
  final VoidCallback? onTap;

  const _PhotoTaskRow({
    required this.status,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    final row = VerificationTaskRow(
      label: 'Foto del momento',
      status: status,
      hint: hint,
      trailing: tappable ? '' : null,
      trailingWidget: tappable
          ? const Icon(
              Icons.camera_alt_rounded,
              size: 22,
              color: AppColors.accent,
            )
          : null,
    );
    if (!tappable) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
        child: row,
      ),
    );
  }
}

/// Status banner shown in place of "I'll be there" while the tracker
/// is running. Pure visual indicator — pulsing accent dot + short
/// status line. NOT tappable: the camera + task progress live
/// directly on this screen now, so there's nowhere to navigate to.
class _QuestInProgressBanner extends StatelessWidget {
  final QuestStatus? status;

  const _QuestInProgressBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.32),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const QuestActivePill(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static String _subtitleFor(QuestStatus? s) {
    if (s == null) return 'Sincronizando…';
    if (!s.hasArrived) return 'Esperando tu llegada al venue';
    if (s.checks.photoCapture) return 'Tu momento ya quedó capturado';
    return 'Capturando tu momento';
  }
}

/// Surfaces a `QuestTracker.startQuest` failure inline. Replaces the
/// optimistic "QUEST ACTIVE · Sincronizando…" banner so the user
/// can't be misled into thinking pings are recording when the
/// tracker actually crashed during startup (typical causes: location
/// permission downgraded to "When in use" instead of "Always", a
/// stale active quest from a previous event id, Hive box error).
class _TrackerStartupErrorPanel extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _TrackerStartupErrorPanel({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded,
                  size: 18, color: AppColors.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Tu quest no arrancó',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            error,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: const Text('Reintentar'),
              ),
              const SizedBox(width: AppSpacing.xs),
              TextButton(
                onPressed: () async {
                  await openAppSettings();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: const Text('Ajustes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

/// Whether the user has RSVP'd to this event. AutoDispose so leaving
/// the screen frees the cache; refetched on every detail-screen open
/// (cheap — single GET) plus on demand after `setIntent` /
/// `removeIntent` via `ref.invalidate`. Intent COUNT used to live in
/// a polling stream here — the cost (overlapping streams + every-30s
/// `/events/by-id` fanout) wasn't worth the live-update; we now read
/// the count from the [Event] model returned by `setIntent` /
/// `removeIntent` and a pull-to-refresh on the home feed.
final _hasIntentProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, eventId) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.hasIntent(eventId);
});
