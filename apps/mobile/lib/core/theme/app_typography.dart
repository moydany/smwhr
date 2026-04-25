import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tokens tipográficos de smwhr.
///
/// Tres familias:
/// - Space Grotesk: display (títulos, hero text)
/// - Inter: body, UI, labels
/// - JetBrains Mono: serials, timers, technical strings
///
/// Implementación: usa `google_fonts` durante R0.1 (cache después del primer
/// load). En Sesión 12 (polish) se bundlean los TTFs locales y se reemplaza
/// `GoogleFonts.X(...)` por TextStyle directo con `fontFamily: '...'`.
class AppTypography {
  AppTypography._();

  // === DISPLAY (Space Grotesk) ============================================

  static TextStyle get displayHero => GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 48,
        height: 1.05,
        letterSpacing: -1.0,
        color: AppColors.textPrimary,
      );

  static TextStyle get displayLarge => GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        height: 1.1,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get displayMedium => GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        height: 1.2,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get displaySmall => GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        height: 1.25,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      );

  // === BODY (Inter) =======================================================

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.45,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  // === LABEL (Inter, uppercase) ===========================================

  static TextStyle get label => GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 1.5,
        color: AppColors.textSecondary,
      );

  // === BUTTON (Inter) =====================================================

  static TextStyle get buttonLarge => GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get buttonMedium => GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.2,
        color: AppColors.textPrimary,
      );

  // === MONO (JetBrains Mono) ==============================================

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get monoLarge => GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w500,
        fontSize: 32,
        letterSpacing: 1.0,
        color: AppColors.textPrimary,
      );

  static TextStyle get monoXLarge => GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w600,
        fontSize: 48,
        letterSpacing: 1.5,
        color: AppColors.textPrimary,
      );
}
