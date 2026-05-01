import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user.dart';
import '../../../data/providers.dart';
import '../../../shared/utils/handle_validator.dart';
import '../../onboarding/state/onboarding_state.dart';

/// Form snapshot for the Edit Profile screen. Mirrors [OnboardingForm] for
/// the fields that are editable post-onboarding (everything except push
/// settings) plus a `dirty` flag so the screen can disable Save until the
/// user actually changes something.
class EditProfileForm {
  final String handle;
  final String displayName;
  final String bio;
  final String city;
  final String language;
  final List<String> interests;

  /// Avatar URL currently displayed (mirrors the User after the most
  /// recent successful upload / removal). Null when the user has no avatar.
  final String? avatarUrl;

  /// True while an avatar upload / removal is in flight. Disables the
  /// avatar tap target and shows a spinner inside the circle.
  final bool isAvatarBusy;

  /// Lifecycle of the live handle availability check. Mirrors the
  /// onboarding flow but treats the user's *current* handle as available
  /// without a server round-trip.
  final HandleStatus handleStatus;
  final String? handleError;

  /// True while a `PATCH /me` is in flight.
  final bool isSubmitting;
  final String? submitError;

  /// Set by [EditProfileController.markSaved] after a successful submit so
  /// the screen can pop on next frame.
  final bool didSave;

  const EditProfileForm({
    this.handle = '',
    this.displayName = '',
    this.bio = '',
    this.city = '',
    this.language = 'es',
    this.interests = const [],
    this.avatarUrl,
    this.isAvatarBusy = false,
    this.handleStatus = HandleStatus.available,
    this.handleError,
    this.isSubmitting = false,
    this.submitError,
    this.didSave = false,
  });

  bool get handleReady =>
      handleStatus == HandleStatus.available && handleError == null;

  bool get displayNameReady => displayName.trim().length >= 2;

  bool get cityReady => city.trim().isNotEmpty;

  bool get interestsReady => interests.isNotEmpty;

  bool get readyToSave =>
      handleReady && displayNameReady && cityReady && interestsReady;

  EditProfileForm copyWith({
    String? handle,
    String? displayName,
    String? bio,
    String? city,
    String? language,
    List<String>? interests,
    String? avatarUrl,
    bool clearAvatar = false,
    bool? isAvatarBusy,
    HandleStatus? handleStatus,
    String? handleError,
    bool clearHandleError = false,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
    bool? didSave,
  }) {
    return EditProfileForm(
      handle: handle ?? this.handle,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      language: language ?? this.language,
      interests: interests ?? this.interests,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      isAvatarBusy: isAvatarBusy ?? this.isAvatarBusy,
      handleStatus: handleStatus ?? this.handleStatus,
      handleError:
          clearHandleError ? null : (handleError ?? this.handleError),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError:
          clearSubmitError ? null : (submitError ?? this.submitError),
      didSave: didSave ?? this.didSave,
    );
  }

  /// True iff anything in the form drifted from the seed values.
  bool isDirtyAgainst(User seed) {
    final seedHandle = seed.handle;
    final seedInterests = [...seed.interests]..sort();
    final currentInterests = [...interests]..sort();
    return handle != seedHandle ||
        displayName != seed.displayName ||
        (bio) != (seed.bio ?? '') ||
        city != seed.city ||
        language != seed.language ||
        currentInterests.join(',') != seedInterests.join(',');
  }
}

/// Mutates [EditProfileForm] in response to user input. Seeded from the
/// current [User] on first build via [seed]. Submits through
/// [usersRepositoryProvider] so the same code path covers mock + real.
class EditProfileController extends StateNotifier<EditProfileForm> {
  EditProfileController(this._ref) : super(const EditProfileForm());

  final Ref _ref;
  Timer? _handleDebounce;

  /// Initial handle stamped at seed time. Used to short-circuit availability
  /// checks when the user types their own handle back unchanged.
  String _seedHandle = '';
  bool _seeded = false;

  /// Initialise the form from [User]. Idempotent — only the first call has
  /// effect, so the screen can call it during build without thrashing.
  void seed(User user) {
    if (_seeded) return;
    _seeded = true;
    _seedHandle = user.handle;
    state = EditProfileForm(
      handle: user.handle,
      displayName: user.displayName,
      bio: user.bio ?? '',
      city: user.city,
      language: user.language,
      interests: List.of(user.interests),
      avatarUrl: user.avatarUrl,
      handleStatus: HandleStatus.available,
    );
  }

  /// Upload a fresh avatar. Persists immediately so the new image is
  /// reflected outside this form too — invalidates [meProvider] on
  /// success so other screens (the public profile, etc.) refresh.
  Future<void> uploadAvatar(File file) async {
    state = state.copyWith(isAvatarBusy: true, clearSubmitError: true);
    try {
      final repo = _ref.read(usersRepositoryProvider);
      final updated = await repo.uploadAvatar(file);
      _ref.invalidate(meProvider);
      if (!mounted) return;
      state = state.copyWith(
        avatarUrl: updated.avatarUrl,
        isAvatarBusy: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isAvatarBusy: false,
        submitError: _humanizeError(e),
      );
    }
  }

  /// Clear the current avatar.
  Future<void> removeAvatar() async {
    state = state.copyWith(isAvatarBusy: true, clearSubmitError: true);
    try {
      final repo = _ref.read(usersRepositoryProvider);
      await repo.removeAvatar();
      _ref.invalidate(meProvider);
      if (!mounted) return;
      state = state.copyWith(
        clearAvatar: true,
        isAvatarBusy: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isAvatarBusy: false,
        submitError: _humanizeError(e),
      );
    }
  }

  void setHandle(String raw) {
    final normalized = HandleValidator.normalize(raw);
    state = state.copyWith(
      handle: normalized,
      clearHandleError: true,
      handleStatus: normalized == _seedHandle
          ? HandleStatus.available
          : (normalized.isEmpty
              ? HandleStatus.idle
              : HandleStatus.checking),
    );

    if (normalized == _seedHandle) return;

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
      final inFlight = normalized;
      final repo = _ref.read(authRepositoryProvider);
      final available = await repo.checkHandleAvailable(inFlight);
      if (!mounted) return;
      if (state.handle != inFlight) return;
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

  void setBio(String v) => state = state.copyWith(bio: v);

  void setCity(String v) => state = state.copyWith(city: v);

  void setLanguage(String code) =>
      state = state.copyWith(language: code);

  void toggleInterest(String slug) {
    final next = [...state.interests];
    if (next.contains(slug)) {
      next.remove(slug);
    } else {
      next.add(slug);
    }
    state = state.copyWith(interests: next);
  }

  /// Submits the diff against [seed]. Returns true on success. Only fields
  /// that actually changed are sent — keeps the audit log clean and skips
  /// the handle uniqueness check on the backend when the handle is
  /// untouched.
  Future<bool> submit(User seed) async {
    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      final repo = _ref.read(usersRepositoryProvider);
      await repo.updateMe(
        handle: state.handle == seed.handle ? null : state.handle,
        displayName:
            state.displayName == seed.displayName ? null : state.displayName,
        bio: state.bio == (seed.bio ?? '') ? null : state.bio,
        city: state.city == seed.city ? null : state.city,
        language: state.language == seed.language ? null : state.language,
        interests: _interestsEqual(state.interests, seed.interests)
            ? null
            : state.interests,
      );
      if (!mounted) return true;
      state = state.copyWith(isSubmitting: false, didSave: true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        submitError: _humanizeError(e),
      );
      return false;
    }
  }

  static bool _interestsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  static String _humanizeError(Object e) {
    final msg = e.toString();
    if (msg.contains('HANDLE_TAKEN')) return 'Ese handle ya está tomado.';
    if (msg.contains('INVALID_HANDLE')) return 'Handle inválido.';
    return msg;
  }

  @override
  void dispose() {
    _handleDebounce?.cancel();
    super.dispose();
  }
}

/// Provider — `autoDispose` so leaving the screen drops form state.
///
/// We seed the controller automatically off [meProvider] via `ref.listen`
/// (with `fireImmediately`) so the form's initial values are wired up
/// outside the widget build phase — calling `seed` from inside `build`
/// would mutate StateNotifier state mid-frame and trip the "Tried to
/// modify state during build" assertion.
final editProfileControllerProvider = StateNotifierProvider.autoDispose<
    EditProfileController, EditProfileForm>((ref) {
  final ctrl = EditProfileController(ref);
  ref.listen<AsyncValue<User?>>(
    meProvider,
    (prev, next) {
      final user = next.valueOrNull;
      if (user != null) ctrl.seed(user);
    },
    fireImmediately: true,
  );
  return ctrl;
});
