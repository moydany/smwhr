import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        route: '/onboarding/permissions',
        session: 'session 04 · permissions',
        notes: [
          'notifications only (location/camera asked just-in-time)',
          'tap allow → completeOnboarding → /home',
        ],
      );
}
