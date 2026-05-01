import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/user.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/smwhr_text_field.dart';
import '../../onboarding/state/onboarding_state.dart' show HandleStatus;
import '../../onboarding/widgets/interest_card.dart';
import '../state/edit_profile_state.dart';
import '../widgets/profile_top.dart';

/// Pantalla — Edit profile.
///
/// Reuses the onboarding identity / interests fields but allows partial
/// edits and live-validates the handle against the user's current value
/// (no round-trip if you didn't change it). On save, the form sends only
/// the diff to `PATCH /me` and invalidates [meProvider] so the profile
/// shows the new values when we pop back.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  TextEditingController? _handleCtrl;
  TextEditingController? _displayNameCtrl;
  TextEditingController? _bioCtrl;
  TextEditingController? _cityCtrl;

  static const _categories = [
    _Category('music', 'Live music', 'Concerts, intimate shows'),
    _Category('sports', 'Sports', 'Stadiums, arenas, matches'),
    _Category('festivals', 'Festivals', 'Multi-day, multi-stage'),
    _Category('outdoor', 'Outdoor', 'Peaks, trails, expeditions'),
    _Category('culture', 'Culture & arts',
        'Theater, exhibitions, performances'),
  ];

  void _seedControllers(User user) {
    _handleCtrl ??= TextEditingController(text: user.handle);
    _displayNameCtrl ??= TextEditingController(text: user.displayName);
    _bioCtrl ??= TextEditingController(text: user.bio ?? '');
    _cityCtrl ??= TextEditingController(text: user.city);
  }

  @override
  void dispose() {
    _handleCtrl?.dispose();
    _displayNameCtrl?.dispose();
    _bioCtrl?.dispose();
    _cityCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(meProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: userAsync.when(
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
          data: (user) {
            if (user == null) {
              return const Center(child: Text('User not found'));
            }
            // Form-state seed lives in the provider's `ref.listen` so it
            // happens outside `build`; here we only seed the text-edit
            // controllers (creating a controller is not a reactive write).
            _seedControllers(user);
            return _Form(
              user: user,
              handleCtrl: _handleCtrl!,
              displayNameCtrl: _displayNameCtrl!,
              bioCtrl: _bioCtrl!,
              cityCtrl: _cityCtrl!,
              categories: _categories,
            );
          },
        ),
      ),
    );
  }
}

class _Form extends ConsumerWidget {
  final User user;
  final TextEditingController handleCtrl;
  final TextEditingController displayNameCtrl;
  final TextEditingController bioCtrl;
  final TextEditingController cityCtrl;
  final List<_Category> categories;

  const _Form({
    required this.user,
    required this.handleCtrl,
    required this.displayNameCtrl,
    required this.bioCtrl,
    required this.cityCtrl,
    required this.categories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(editProfileControllerProvider);
    final ctrl = ref.read(editProfileControllerProvider.notifier);

    // Pop on successful save — wait for the next frame so the snackbar
    // has time to schedule against the still-valid Scaffold.
    ref.listen<EditProfileForm>(editProfileControllerProvider, (prev, next) {
      if (next.didSave && (prev?.didSave ?? false) == false) {
        // Force the profile screen to refetch /me when we pop back.
        ref.invalidate(meProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            duration: const Duration(seconds: 2),
            content: Text(
              'Perfil actualizado',
              style: AppTypography.bodySmall,
            ),
          ),
        );
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (context.mounted && Navigator.of(context).canPop()) {
            context.pop();
          }
        });
      }
    });

    final canSave = form.readyToSave &&
        form.isDirtyAgainst(user) &&
        !form.isSubmitting;

    final firstFour = categories.take(4).toList();
    final lastOne = categories[4];

    return Column(
      children: [
        _TopBar(
          isSubmitting: form.isSubmitting,
          canSave: canSave,
          onSave: () async {
            HapticFeedback.mediumImpact();
            await ctrl.submit(user);
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit profile',
                  style: AppTypography.displayLarge.copyWith(
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tu identidad pública. Cambia lo que necesites.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Avatar ─────────────────────────────────────────────
                Center(
                  child: _AvatarEditor(
                    avatarUrl: form.avatarUrl,
                    isBusy: form.isAvatarBusy,
                    onPick: () => _pickAvatar(context, ref),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Identity ───────────────────────────────────────────
                SmwhrTextField(
                  label: 'Handle',
                  hint: 'yourname',
                  prefix: const Text('@'),
                  controller: handleCtrl,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9_]'),
                    ),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  onChanged: ctrl.setHandle,
                  isLoading: form.handleStatus == HandleStatus.checking,
                  isValid: form.handleStatus == HandleStatus.available &&
                      form.handle != user.handle,
                  errorText: form.handleError,
                  helperText: form.handleError == null
                      ? 'Este es tu URL en smwhr.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                SmwhrTextField(
                  label: 'Display name',
                  hint: 'How should we call you?',
                  controller: displayNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  onChanged: ctrl.setDisplayName,
                ),
                const SizedBox(height: AppSpacing.lg),
                SmwhrTextField(
                  label: 'Bio',
                  hint: 'A short line about you',
                  controller: bioCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 140,
                  inputFormatters: [LengthLimitingTextInputFormatter(140)],
                  onChanged: ctrl.setBio,
                  helperText: '${form.bio.length}/140',
                ),
                const SizedBox(height: AppSpacing.lg),
                SmwhrTextField(
                  label: 'City',
                  controller: cityCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(60)],
                  prefix: const Icon(Icons.place_outlined),
                  onChanged: ctrl.setCity,
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Language ───────────────────────────────────────────
                _SectionLabel(label: 'Language'),
                const SizedBox(height: AppSpacing.xs),
                _LanguageToggle(
                  selected: form.language,
                  onChanged: ctrl.setLanguage,
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Interests ──────────────────────────────────────────
                _SectionLabel(label: 'Interests'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Pick everything that moves you.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: firstFour.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.xs,
                    mainAxisSpacing: AppSpacing.xs,
                    mainAxisExtent: 100,
                  ),
                  itemBuilder: (context, i) {
                    final c = firstFour[i];
                    return InterestCard(
                      title: c.title,
                      subtitle: c.subtitle,
                      selected: form.interests.contains(c.slug),
                      onTap: () => ctrl.toggleInterest(c.slug),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                InterestCard(
                  title: lastOne.title,
                  subtitle: lastOne.subtitle,
                  selected: form.interests.contains(lastOne.slug),
                  fullWidth: true,
                  onTap: () => ctrl.toggleInterest(lastOne.slug),
                ),

                if (form.submitError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorBackground,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Text(
                      form.submitError!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool isSubmitting;
  final bool canSave;
  final VoidCallback onSave;
  const _TopBar({
    required this.isSubmitting,
    required this.canSave,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: isSubmitting
                    ? null
                    : () {
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
          const Spacer(),
          _SaveAction(
            isSubmitting: isSubmitting,
            canSave: canSave,
            onSave: onSave,
          ),
        ],
      ),
    );
  }
}

class _SaveAction extends StatelessWidget {
  final bool isSubmitting;
  final bool canSave;
  final VoidCallback onSave;
  const _SaveAction({
    required this.isSubmitting,
    required this.canSave,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = canSave && !isSubmitting;
    final bg = enabled
        ? AppColors.accent
        : AppColors.accent.withValues(alpha: 0.35);
    final fg = enabled ? Colors.white : Colors.white.withValues(alpha: 0.7);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        onTap: enabled ? onSave : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          ),
          child: SizedBox(
            height: 22,
            child: isSubmitting
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                : Center(
                    child: Text(
                      'Save',
                      style: AppTypography.buttonMedium.copyWith(
                        color: fg,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.textTertiary,
        fontSize: 11,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _LanguageToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          _LanguageOption(
            code: 'es',
            label: 'Español',
            selected: selected == 'es',
            onTap: () => onChanged('es'),
          ),
          _LanguageOption(
            code: 'en',
            label: 'English',
            selected: selected == 'en',
            onTap: () => onChanged('en'),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageOption({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.buttonMedium.copyWith(
                color: selected
                    ? AppColors.bg
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Category {
  final String slug;
  final String title;
  final String subtitle;
  const _Category(this.slug, this.title, this.subtitle);
}

/// Avatar circle wrapped in an InkWell. Tap opens the picker sheet; while
/// an upload/remove is in flight we show a spinner overlay and disable
/// the tap so a second tap can't double-fire the picker.
class _AvatarEditor extends StatelessWidget {
  final String? avatarUrl;
  final bool isBusy;
  final VoidCallback onPick;
  const _AvatarEditor({
    required this.avatarUrl,
    required this.isBusy,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ProfileAvatar(avatarUrl: avatarUrl, size: 112),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isBusy ? null : onPick,
              child: isBusy
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bg, width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Open a bottom sheet that lets the user pick the avatar source. Calls
/// the controller's upload/remove methods directly — the sheet itself
/// stays presentational.
Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
  final form = ref.read(editProfileControllerProvider);
  final ctrl = ref.read(editProfileControllerProvider.notifier);
  final hasAvatar = form.avatarUrl != null;

  final action = await showModalBottomSheet<_AvatarAction>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _SheetTile(
            icon: Icons.photo_library_outlined,
            label: 'Elegir de la galería',
            onTap: () => Navigator.of(ctx).pop(_AvatarAction.gallery),
          ),
          _SheetTile(
            icon: Icons.camera_alt_outlined,
            label: 'Tomar una foto',
            onTap: () => Navigator.of(ctx).pop(_AvatarAction.camera),
          ),
          if (hasAvatar)
            _SheetTile(
              icon: Icons.delete_outline_rounded,
              label: 'Quitar avatar',
              destructive: true,
              onTap: () => Navigator.of(ctx).pop(_AvatarAction.remove),
            ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    ),
  );

  if (action == null) return;

  if (action == _AvatarAction.remove) {
    HapticFeedback.mediumImpact();
    await ctrl.removeAvatar();
    return;
  }

  final picker = ImagePicker();
  final source = action == _AvatarAction.camera
      ? ImageSource.camera
      : ImageSource.gallery;
  final picked = await picker.pickImage(
    source: source,
    // Server caps avatars at 5 MB; downsampling on the client keeps the
    // upload fast and avoids hitting that limit on modern phone cameras.
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (picked == null) return;
  HapticFeedback.mediumImpact();
  await ctrl.uploadAvatar(File(picked.path));
}

enum _AvatarAction { gallery, camera, remove }

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
