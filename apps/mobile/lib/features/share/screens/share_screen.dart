import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class ShareScreen extends StatelessWidget {
  final String badgeId;
  const ShareScreen({super.key, required this.badgeId});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        route: '/share/$badgeId',
        session: 'session 11 · share',
        notes: const [
          '1080x1920 RepaintBoundary → dart:ui → temp PNG',
          'iOS share sheet handoff (Instagram Stories)',
        ],
      );
}
