import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class InterestsScreen extends StatelessWidget {
  const InterestsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        route: '/onboarding/interests',
        session: 'session 04 · interests',
        notes: [
          '5 EventCategory chips + Everything',
          'multi-select with selectionClick haptic',
        ],
      );
}
