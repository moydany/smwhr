import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

/// Pantalla 01 — Splash / Auth. Real impl lands in Session 3.
class SplashAuthScreen extends StatelessWidget {
  const SplashAuthScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        route: '/',
        session: 'session 03 · splash + auth',
        notes: [
          'wordmark + magenta accent',
          '3 buttons: Apple, Google, Email',
          'tap → 800–1200 ms latency → /home or /onboarding/identity',
        ],
      );
}
