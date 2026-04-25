import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
        route: '/home',
        session: 'session 05 · home feed',
        notes: [
          'featured carousel (BTS x3)',
          'event grid pulled from EventsRepository.listEvents',
          'pull-to-refresh, skeleton loading, empty state',
        ],
      );
}
