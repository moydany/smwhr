import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class BadgeDetailScreen extends StatelessWidget {
  final String badgeId;
  const BadgeDetailScreen({super.key, required this.badgeId});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        route: '/badge/$badgeId',
        session: 'session 09 · badge detail',
        notes: const [
          'composed badge image hero',
          'serial label (#0001/∞)',
          'venue, date, verification score',
          'share CTA → /share/:badgeId',
        ],
      );
}
