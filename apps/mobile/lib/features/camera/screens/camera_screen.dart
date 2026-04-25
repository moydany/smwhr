import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class CameraScreen extends StatelessWidget {
  final String eventId;
  const CameraScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        route: '/camera/$eventId',
        session: 'session 08 · camera',
        notes: const [
          'in-app camera (no gallery)',
          'badge frame overlay per event.category',
          'capture → preview → confirm → /reveal',
        ],
      );
}
