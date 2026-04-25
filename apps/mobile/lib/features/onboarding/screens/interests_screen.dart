import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/smwhr_button.dart';
import '../state/onboarding_state.dart';
import '../widgets/interest_card.dart';
import '../widgets/onboarding_shell.dart';

/// Pantalla 03 — Interests. 5 categories in a 2-col grid + an "Everything"
/// row that selects all five at once.
class InterestsScreen extends ConsumerWidget {
  const InterestsScreen({super.key});

  static const _categories = [
    _Category('music', 'Live music', 'Concerts, intimate shows'),
    _Category('sports', 'Sports', 'Stadiums, arenas, matches'),
    _Category('festivals', 'Festivals', 'Multi-day, multi-stage'),
    _Category('outdoor', 'Outdoor', 'Peaks, trails, expeditions'),
    _Category('culture', 'Culture & arts',
        'Theater, exhibitions, performances'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);

    final firstFour = _categories.take(4).toList();
    final lastOne = _categories[4];

    return OnboardingShell(
      currentStep: 2,
      title: 'What do you\ncollect?',
      subtitle: 'Pick everything that moves you. You can always add more.',
      hint: form.interests.isEmpty ? 'Pick at least one' : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2-col grid for the first 4 categories
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstFour.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
          // "Culture & arts" full-width row (matches HTML mock layout)
          InterestCard(
            title: lastOne.title,
            subtitle: lastOne.subtitle,
            selected: form.interests.contains(lastOne.slug),
            fullWidth: true,
            onTap: () => ctrl.toggleInterest(lastOne.slug),
          ),
          const SizedBox(height: AppSpacing.lg),
          InterestCard(
            title: 'Everything',
            subtitle: 'Don\'t limit me',
            selected: ctrl.everythingSelected,
            fullWidth: true,
            onTap: ctrl.toggleEverything,
          ),
        ],
      ),
      cta: SmwhrButton(
        label: 'Continue  →',
        variant: SmwhrButtonVariant.primary,
        onPressed: form.interestsReady
            ? () => context.push(AppRoutes.onboardingPermissions)
            : null,
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
