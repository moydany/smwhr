import 'package:permission_handler/permission_handler.dart';

import '../../../data/models/event.dart';

/// Outcome of a permission request, normalised so call sites don't have to
/// pattern-match against `permission_handler`'s raw [PermissionStatus].
enum PermissionOutcome {
  /// User granted the requested permission (or it was already granted).
  granted,

  /// User explicitly denied this prompt. We can re-prompt later.
  denied,

  /// User permanently denied (or system blocked it). Re-prompts are no-ops;
  /// the caller should drive the user to Settings.
  permanentlyDenied,

  /// On iOS: the user granted "When in use" but we asked for "Always".
  /// Treated as a partial grant — caller decides whether to escalate.
  partial,

  /// Permission isn't applicable on this platform / was already covered
  /// (e.g. notifications on iOS < 12). Treat as a green light.
  notNeeded,
}

class PermissionResult {
  final PermissionOutcome outcome;

  /// True when the only path forward is the system Settings app.
  final bool shouldOpenSettings;

  const PermissionResult({
    required this.outcome,
    this.shouldOpenSettings = false,
  });

  bool get isGranted =>
      outcome == PermissionOutcome.granted || outcome == PermissionOutcome.notNeeded;
}

/// Single entry point for asking for OS-level permissions during the quest
/// pipeline. Each request maps to a specific UX moment so we never prompt
/// "Always location" cold (per `apps/mobile/CLAUDE.md` §Permisos).
///
/// Sequencing (canon):
///   1. Onboarding screen 04 → notifications only.
///   2. First "I'll be there" tap → [requestForIntent] (When-in-use).
///   3. "Start quest" inside the venue window → [requestForActiveQuest]
///      (Always + motion).
///   4. Camera shutter → [requestForCamera].
class PermissionFlow {
  const PermissionFlow();

  /// Step 2. Asks for foreground location only. Cheap prompt, high
  /// acceptance rate. The [event] is plumbed so we can localise copy
  /// later (LATAM-specific reasons, etc.); unused for now.
  Future<PermissionResult> requestForIntent(Event event) async {
    final status = await Permission.locationWhenInUse.request();
    return _mapLocation(status, escalating: false);
  }

  /// Step 3. Asks for background location ("Always") + motion. Called
  /// after the user has opted into the quest from inside the venue
  /// window — the highest-acceptance moment per the playbook.
  ///
  /// iOS requires a strict 2-step escalation: you can only request
  /// `locationAlways` AFTER `locationWhenInUse` is granted. Skipping
  /// straight to Always raises
  /// `PlatformException(MISSING_WHENINUSE_PERMISSION)`. We always
  /// re-check + request when-in-use first, then ask for the upgrade.
  /// On Android both flags are colloquial — `locationAlways.request()`
  /// triggers the right system dialog directly — so the extra check is
  /// harmless (returns granted immediately if already granted).
  Future<PermissionResult> requestForActiveQuest(Event event) async {
    // Step 3a — when-in-use. iOS shows the standard "While Using" sheet.
    final whenInUseStatus = await Permission.locationWhenInUse.request();
    if (!whenInUseStatus.isGranted && !whenInUseStatus.isLimited) {
      return _mapLocation(whenInUseStatus, escalating: false);
    }

    // Step 3b — escalate to always. iOS now shows the second sheet
    // ("Allow even when not using"). On a fresh first run the two
    // sheets fire back-to-back; on subsequent runs only the missing
    // step fires.
    final alwaysStatus = await Permission.locationAlways.request();
    final locationResult = _mapLocation(alwaysStatus, escalating: true);

    // Motion is iOS-only effectively (Android's ACTIVITY_RECOGNITION is
    // declared by the locus plugin); a denial here doesn't block tracking
    // — it just removes a battery optimisation. So we request and ignore.
    await Permission.sensors.request();

    return locationResult;
  }

  /// Step 4. Asks for camera the moment the user reaches the capture
  /// screen. Cold-prompt is fine here; user clearly intends to take a
  /// photo.
  Future<PermissionResult> requestForCamera() async {
    final status = await Permission.camera.request();
    return _mapStatus(status);
  }

  PermissionResult _mapLocation(
    PermissionStatus status, {
    required bool escalating,
  }) {
    if (status.isGranted) {
      return const PermissionResult(outcome: PermissionOutcome.granted);
    }
    if (status.isLimited) {
      // iOS "When in use" returned for an Always request → partial grant.
      return PermissionResult(
        outcome:
            escalating ? PermissionOutcome.partial : PermissionOutcome.granted,
      );
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return const PermissionResult(
        outcome: PermissionOutcome.permanentlyDenied,
        shouldOpenSettings: true,
      );
    }
    return const PermissionResult(outcome: PermissionOutcome.denied);
  }

  PermissionResult _mapStatus(PermissionStatus status) {
    if (status.isGranted) {
      return const PermissionResult(outcome: PermissionOutcome.granted);
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return const PermissionResult(
        outcome: PermissionOutcome.permanentlyDenied,
        shouldOpenSettings: true,
      );
    }
    return const PermissionResult(outcome: PermissionOutcome.denied);
  }
}
