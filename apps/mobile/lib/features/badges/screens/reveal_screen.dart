import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class RevealScreen extends StatelessWidget {
  final String badgeId;
  const RevealScreen({super.key, required this.badgeId});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        route: '/reveal/$badgeId',
        session: 'session 09 · reveal animation',
        notes: const [
          'AnimationController 1.6s, Curves.easeOutBack',
          'frame slide → photo composite → serial typewriter',
          'heavy haptic at composite moment',
        ],
      );
}
