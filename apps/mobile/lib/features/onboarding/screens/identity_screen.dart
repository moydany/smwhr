import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class IdentityScreen extends StatelessWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        route: '/onboarding/identity',
        session: 'session 04 · identity',
        notes: [
          'handle (live validation, reserved list)',
          'displayName',
          'city',
        ],
      );
}
