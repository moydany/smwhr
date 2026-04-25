import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Theme dark de smwhr (no hay light mode en R0.1).
///
/// Compone los tokens en un `ThemeData` consistente para `MaterialApp`.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      splashColor: AppColors.accentGlow,
      highlightColor: AppColors.accentGlow,

      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        surface: AppColors.bg,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surface,
        primary: AppColors.accent,
        onPrimary: AppColors.textPrimary,
        secondary: AppColors.accent,
        onSecondary: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textPrimary,
        outline: AppColors.border,
      ),

      textTheme: TextTheme(
        displayLarge: AppTypography.displayHero,
        displayMedium: AppTypography.displayLarge,
        displaySmall: AppTypography.displayMedium,
        headlineMedium: AppTypography.displaySmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.buttonLarge,
        labelMedium: AppTypography.buttonMedium,
        labelSmall: AppTypography.label,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.displaySmall,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.bg,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 24,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        labelStyle: AppTypography.label,
        border: _buildInputBorder(AppColors.border),
        enabledBorder: _buildInputBorder(AppColors.border),
        focusedBorder: _buildInputBorder(AppColors.accent, width: 1.5),
        errorBorder: _buildInputBorder(AppColors.error),
        focusedErrorBorder: _buildInputBorder(AppColors.error, width: 1.5),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.border,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: false,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _buildInputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
