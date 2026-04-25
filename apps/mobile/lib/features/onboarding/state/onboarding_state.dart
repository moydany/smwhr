import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../shared/utils/handle_validator.dart';

/// Aggregated onboarding form state across the 3 onboarding screens.
class OnboardingForm {
  final String handle;
  final String displayName;
  final String city;
  final List<String> interests;
  final bool notificationsEnabled;

  /// Per-field UX state.
  final HandleStatus handleStatus;
  final String? handleError;

  /// True while `completeOnboarding` is in flight on the final screen.
  final bool isSubmitting;
  final String? submitError;

  const OnboardingForm({
    this.handle = '',
    this.displayName = '',
    this.city = 'Tulancingo, MX',
    this.interests = const [],
    this.notificationsEnabled = false,
    this.handleStatus = HandleStatus.idle,
    this.handleError,
    this.isSubmitting = false,
    this.submitError,
  });

  bool get identityReady =>
      handleStatus == HandleStatus.available &&
      displayName.trim().length >= 2 &&
      city.trim().isNotEmpty;

  bool get interestsReady => interests.isNotEmpty;

  OnboardingForm copyWith({
    String? handle,
    String? displayName,
    String? city,
    List<String>? interests,
    bool? notificationsEnabled,
    HandleStatus? handleStatus,
    String? handleError,
    bool clearHandleError = false,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return OnboardingForm(
      handle: handle ?? this.handle,
      displayName: displayName ?? this.displayName,
      city: city ?? this.city,
      interests: interests ?? this.interests,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      handleStatus: handleStatus ?? this.handleStatus,
      handleError: clearHandleError ? null : (handleError ?? this.handleError),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

/// Lifecycle of the live handle-availability check.
enum HandleStatus { idle, checking, available, taken, invalid }

/// Riverpod controller. Owns:
/// - debounced live handle availability (400 ms after last keystroke);
/// - interest toggle (single-shot via category slug, with "Everything" being
///   a synthetic "all 5 selected" shortcut);
/// - submit pipe to `AuthRepository.completeOnboarding`.
class OnboardingController extends StateNotifier<OnboardingForm> {
  OnboardingController(this._ref) : super(const OnboardingForm());

  final Ref _ref;
  Timer? _handleDebounce;

  // ── Identity ──────────────────────────────────────────────────────────

  void setHandle(String raw) {
    final normalized = HandleValidator.normalize(raw);
    state = state.copyWith(
      handle: normalized,
      handleStatus: normalized.isEmpty
          ? HandleStatus.idle
          : HandleStatus.checking,
      clearHandleError: true,
    );

    final localErr = HandleValidator.localError(normalized);
    if (localErr != null) {
      state = state.copyWith(
        handleStatus: HandleStatus.invalid,
        handleError: localErr,
      );
      return;
    }
    if (normalized.isEmpty) return;

    _handleDebounce?.cancel();
    _handleDebounce = Timer(const Duration(milliseconds: 400), () async {
      // Capture the value at the moment the debounce fired — if the user
      // kept typing, we'll bail when the state has moved on.
      final inFlight = normalized;
      final repo = _ref.read(authRepositoryProvider);
      final available = await repo.checkHandleAvailable(inFlight);
      if (!mounted) return; // controller disposed (autoDispose triggered)
      if (state.handle != inFlight) return; // a newer keystroke won
      state = state.copyWith(
        handleStatus:
            available ? HandleStatus.available : HandleStatus.taken,
        handleError: available ? null : 'Ese handle ya está tomado.',
        clearHandleError: available,
      );
    });
  }

  void setDisplayName(String v) =>
      state = state.copyWith(displayName: v);

  void setCity(String v) => state = state.copyWith(city: v);

  // ── Interests ─────────────────────────────────────────────────────────

  /// Slugs of all selectable categories. Mirrors `EventCategory.values`.
  static const List<String> allCategorySlugs = [
    'music',
    'sports',
    'festivals',
    'outdoor',
    'culture',
  ];

  void toggleInterest(String slug) {
    final next = [...state.interests];
    if (next.contains(slug)) {
      next.remove(slug);
    } else {
      next.add(slug);
    }
    state = state.copyWith(interests: next);
  }

  void toggleEverything() {
    final allSelected = allCategorySlugs.every(state.interests.contains);
    state = state.copyWith(
      interests: allSelected ? [] : List.of(allCategorySlugs),
    );
  }

  bool get everythingSelected =>
      allCategorySlugs.every(state.interests.contains);

  // ── Permissions / submit ──────────────────────────────────────────────

  void setNotificationsEnabled(bool v) =>
      state = state.copyWith(notificationsEnabled: v);

  /// Calls AuthRepository.completeOnboarding with the form payload.
  /// Returns true on success — the splash redirect picks the user up
  /// from there. Caller should route to /home on success.
  Future<bool> submit() async {
    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.completeOnboarding(
        handle: state.handle,
        displayName: state.displayName.trim(),
        city: state.city.trim(),
        interests: state.interests,
        notificationsEnabled: state.notificationsEnabled,
      );
      if (!mounted) return true;
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        submitError: e.toString(),
      );
      return false;
    }
  }

  @override
  void dispose() {
    _handleDebounce?.cancel();
    super.dispose();
  }
}

/// Provider — `autoDispose` so leaving onboarding clears the form.
final onboardingControllerProvider = StateNotifierProvider.autoDispose<
    OnboardingController, OnboardingForm>((ref) {
  return OnboardingController(ref);
});
