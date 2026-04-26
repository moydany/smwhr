import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import '../../../data/models/quest.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/smwhr_button.dart';
import '../providers/quest_state_provider.dart';
import '../services/quest_tracker.dart';
import '../widgets/quest_active_pill.dart';
import '../widgets/quest_timer.dart';
import '../widgets/verification_check_row.dart';

/// Pantalla 07 — Active quest.
///
/// Auto-starts the mock quest on mount, watches the
/// `QuestsRepository.watchQuestStatus` stream, drives a wall-second
/// counter so the seconds digit on the big timer ticks even when
/// `dwellMinutes` hasn't bumped yet (1 sec real = 1 dwell minute), and
/// enables the "Capture your moment" CTA once
/// `dwellMinutes >= dwellMinimumMin`.
class ActiveQuestScreen extends ConsumerStatefulWidget {
  final String eventId;
  const ActiveQuestScreen({super.key, required this.eventId});

  @override
  ConsumerState<ActiveQuestScreen> createState() => _ActiveQuestScreenState();
}

class _ActiveQuestScreenState extends ConsumerState<ActiveQuestScreen> {
  Timer? _wallTicker;
  int _wallSeconds = 0;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _wallTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _wallSeconds = (_wallSeconds + 1) % 60);
    });
    // Boot the quest after first frame. We call startQuest
    // unconditionally — `getQuestStatus().isActive` reflects the
    // backend's event time-window phase, NOT local tracker state, so we
    // can't use it to decide whether to skip. QuestTracker is idempotent
    // for the same eventId; a re-mount during an in-flight quest no-ops.
    // In real mode this triggers permission prompts (Always location +
    // motion); a denial surfaces as a `QuestPermissionException` we
    // render in the UI.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final repo = ref.read(questsRepositoryProvider);
        await repo.startQuest(widget.eventId);
      } on QuestPermissionException catch (e) {
        if (!mounted) return;
        setState(() {
          _startupError = e.result.shouldOpenSettings
              ? 'Necesitamos permiso de ubicación. Ábrelo en Ajustes y vuelve.'
              : 'Necesitamos permiso de ubicación para verificar el evento.';
        });
      } on QuestException catch (e) {
        if (!mounted) return;
        setState(() => _startupError = e.message);
      } catch (e) {
        if (!mounted) return;
        setState(() => _startupError = 'No se pudo iniciar la quest: $e');
      }
    });
  }

  @override
  void dispose() {
    _wallTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(questEventProvider(widget.eventId));
    final statusAsync = ref.watch(questStatusProvider(widget.eventId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              _TopBar(),
              const SizedBox(height: AppSpacing.lg),
              const QuestActivePill(),
              const SizedBox(height: AppSpacing.lg),
              eventAsync.maybeWhen(
                data: (event) => _Header(event: event),
                orElse: _HeaderSkeleton.new,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_startupError != null)
                _ErrorBanner(message: _startupError!)
              else
                statusAsync.when(
                  loading: () => const _Loader(),
                  error: (e, _) => _ErrorBanner(message: e.toString()),
                  data: (status) => _Body(
                    status: status,
                    event: eventAsync.value,
                    wallSeconds: _wallSeconds,
                    onCapture: () =>
                        _onCapture(context, ref, eventAsync.value),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCapture(BuildContext context, WidgetRef ref, Event? event) {
    if (event == null) return;
    HapticFeedback.heavyImpact();
    context.push(AppRoutes.camera(event.id));
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

class _Header extends StatelessWidget {
  final Event? event;
  const _Header({required this.event});

  @override
  Widget build(BuildContext context) {
    final ev = event;
    if (ev == null) return const _HeaderSkeleton();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "You're at",
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          ev.venueName,
          style: AppTypography.displayLarge.copyWith(
            letterSpacing: -1,
            fontSize: 28,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final QuestStatus status;
  final Event? event;
  final int wallSeconds;
  final VoidCallback onCapture;

  const _Body({
    required this.status,
    required this.event,
    required this.wallSeconds,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final dwellMinimum = event?.dwellMinimumMin ?? 60;
    final readyToCapture = status.dwellMinutes >= dwellMinimum &&
        status.checks.gpsVerified &&
        status.checks.deviceTrusted &&
        status.checks.integrityActive;
    final progress =
        (status.dwellMinutes / dwellMinimum).clamp(0.0, 1.0).toDouble();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestTimer(
            dwellMinutes: status.dwellMinutes,
            wallSeconds: wallSeconds,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Active for ${status.dwellMinutes} minutes · '
            '$dwellMinimum min required for full verification',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppColors.borderSoft,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          VerificationCheckRow(
            label: 'GPS verified',
            passing: status.checks.gpsVerified,
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          VerificationCheckRow(
            label: 'Device trusted',
            passing: status.checks.deviceTrusted,
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          VerificationCheckRow(
            label: 'Integrity active',
            passing: status.checks.integrityActive,
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          VerificationCheckRow(
            label: 'Photo capture',
            passing: status.checks.photoCapture,
            optional: true,
          ),
          const Spacer(),
          SmwhrButton(
            label: 'Capture your moment',
            variant: SmwhrButtonVariant.primary,
            leading: const Padding(
              padding: EdgeInsets.only(left: AppSpacing.md),
              child: Icon(Icons.camera_alt_outlined, size: 20),
            ),
            onPressed: readyToCapture ? onCapture : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) => const Expanded(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        border: Border.all(color: AppColors.errorMuted),
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
      ),
      child: Text(
        message,
        style: AppTypography.bodySmall.copyWith(color: AppColors.error),
      ),
    );
  }
}

// Providers moved to ../providers/quest_state_provider.dart so the
// orchestrator (QuestTracker, the camera screen, share sheet, etc.) can
// reuse them.
