/// Tokens de espaciado y radios de smwhr. Escala 4px.
///
/// Importar como `import 'package:smwhr/core/theme/app_spacing.dart';`
/// y usar siempre en padding/margin/gap. Cero valores hardcoded en widgets.
class AppSpacing {
  AppSpacing._();

  // Spacing scale
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  // Border radius
  static const double radiusSmall = 8;
  static const double radiusChip = 10;
  static const double radiusBadge = 12;
  static const double radiusButton = 14; // matches HTML mock auth buttons
  static const double radiusCard = 16;
  static const double radiusFrame = 54;
  static const double radiusFull = 999;

  // Stroke
  static const double strokeThin = 1.0;
  static const double strokeIcon = 1.5;
  static const double strokeThick = 2.0;

  // Reusable durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationDefault = Duration(milliseconds: 280);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationReveal = Duration(milliseconds: 1600);
}
