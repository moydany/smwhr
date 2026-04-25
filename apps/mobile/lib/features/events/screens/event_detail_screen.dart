import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class EventDetailScreen extends StatelessWidget {
  final String slug;
  const EventDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        route: '/events/$slug',
        session: 'session 06 · event detail',
        notes: const [
          'hero poster',
          'locked badge preview (silhouette + "?")',
          'intent toggle button',
          'other-attendees stub',
        ],
      );
}
