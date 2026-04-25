import 'package:flutter/material.dart';

/// Tokens de color para smwhr.
///
/// Source of truth: design/mocks/v1/smwhr_standalone.html (CSS custom props)
/// y apps/mobile/CLAUDE.md (sección Design tokens).
///
/// Reglas:
/// - Único acento: magenta. Usado con restricción.
/// - Backgrounds en escala de gris muy oscura (#050505 → #2A2A2A).
/// - Categorías ambient para glow/halos en cards y reveal.
class AppColors {
  AppColors._();

  // Backgrounds
  static const bg = Color(0xFF050505);
  static const surface = Color(0xFF111111);
  static const surfaceElevated = Color(0xFF1A1A1A);
  static const border = Color(0xFF2A2A2A);
  static const borderSoft = Color(0xFF1E1E1E);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textTertiary = Color(0xFF555555);
  static const textDisabled = Color(0xFF333333);

  // Accent (magenta único)
  static const accent = Color(0xFFFF2D95);
  static const accentMuted = Color(0xFF8B1A51);
  static const accentGlow = Color(0x26FF2D95); // 15% alpha

  // Status
  static const error = Color(0xFFFF8A80);
  static const errorMuted = Color(0xFF5C2B2E);
  static const errorBackground = Color(0xFF2A1215);
  static const success = Color(0xFF2DFF95);

  // Category ambient (para glows en cards y reveal)
  static const musicAmbient = Color(0xFFFF2D95);
  static const sportsAmbient = Color(0xFF2DFF95);
  static const festivalsAmbient = Color(0xFFFF9D2D);
  static const outdoorAmbient = Color(0xFF2DC8FF);
  static const cultureAmbient = Color(0xFF9D2DFF);
}
