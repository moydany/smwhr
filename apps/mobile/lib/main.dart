import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'smoke_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force the dark status bar at cold start (avoids the iOS default white flash).
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ),
  );

  // R0.1 is portrait-only.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  runApp(const ProviderScope(child: SmwhrApp()));
}

class SmwhrApp extends StatelessWidget {
  const SmwhrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'smwhr',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SmokeScreen(),
    );
  }
}
