import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class ActiveQuestScreen extends StatelessWidget {
  final String eventId;
  const ActiveQuestScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        route: '/quest/$eventId',
        session: 'session 07 · active quest',
        notes: const [
          'big mono dwell timer (1 sec wall = 1 mock minute)',
          'four verification checks (gps / device / integrity / photo)',
          '"Take photo" CTA enabled at dwellMinimumMin',
        ],
      );
}
