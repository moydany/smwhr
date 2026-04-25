import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/smwhr_button.dart';
import '../../../shared/widgets/smwhr_text_field.dart';
import '../state/onboarding_state.dart';
import '../widgets/onboarding_shell.dart';

/// Pantalla 02 — Identity. Handle, display name, city.
class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  late final TextEditingController _handle;
  late final TextEditingController _displayName;
  late final TextEditingController _city;

  @override
  void initState() {
    super.initState();
    final s = ref.read(onboardingControllerProvider);
    _handle = TextEditingController(text: s.handle);
    _displayName = TextEditingController(text: s.displayName);
    _city = TextEditingController(text: s.city);
  }

  @override
  void dispose() {
    _handle.dispose();
    _displayName.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);

    return OnboardingShell(
      currentStep: 1,
      title: 'Claim your\nsomewhere.',
      subtitle: 'Takes 30 seconds. Promise.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmwhrTextField(
            label: 'Your handle',
            hint: 'yourname',
            prefix: const Text('@'),
            controller: _handle,
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
            isValid: form.handleStatus == HandleStatus.available,
            errorText: form.handleError,
            helperText: form.handleError == null
                ? 'This is your smwhr URL. Make it yours.'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          SmwhrTextField(
            label: 'Display name',
            hint: 'How should we call you?',
            controller: _displayName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            onChanged: ctrl.setDisplayName,
          ),
          const SizedBox(height: AppSpacing.lg),
          SmwhrTextField(
            label: 'Where are you based?',
            controller: _city,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            prefix: const Icon(Icons.place_outlined),
            suffix: 'AUTO',
            onChanged: ctrl.setCity,
            helperText: 'We use this to show events near you.',
          ),
        ],
      ),
      cta: SmwhrButton(
        label: 'Continue  →',
        variant: SmwhrButtonVariant.primary,
        onPressed: form.identityReady
            ? () => context.push(AppRoutes.onboardingInterests)
            : null,
      ),
    );
  }
}
