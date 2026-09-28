import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'text_styles.dart';

class AppTheme {
  static ThemeData lightTheme = _buildTheme(AppColors.lightColorScheme, false);
  static ThemeData darkTheme = _buildTheme(AppColors.darkColorScheme, true);

  static ThemeData _buildTheme(ColorScheme colorScheme, bool isDark) {
    final TextTheme textTheme = TextTheme(
      displayLarge:
          AppTextStyles.displayLarge.copyWith(color: colorScheme.onSurface),
      displayMedium:
          AppTextStyles.displayMedium.copyWith(color: colorScheme.onSurface),
      displaySmall:
          AppTextStyles.displaySmall.copyWith(color: colorScheme.onSurface),
      headlineLarge:
          AppTextStyles.headlineLarge.copyWith(color: colorScheme.onSurface),
      headlineMedium:
          AppTextStyles.headlineMedium.copyWith(color: colorScheme.onSurface),
      headlineSmall:
          AppTextStyles.headlineSmall.copyWith(color: colorScheme.onSurface),
      titleLarge:
          AppTextStyles.titleLarge.copyWith(color: colorScheme.onSurface),
      titleMedium:
          AppTextStyles.titleMedium.copyWith(color: colorScheme.onSurface),
      titleSmall:
          AppTextStyles.titleSmall.copyWith(color: colorScheme.onSurface),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: colorScheme.onSurface),
      bodyMedium: AppTextStyles.bodyMedium
          .copyWith(color: colorScheme.onSurfaceVariant),
      bodySmall:
          AppTextStyles.bodySmall.copyWith(color: colorScheme.onSurfaceVariant),
      labelLarge:
          AppTextStyles.labelLarge.copyWith(color: colorScheme.onSurface),
      labelMedium: AppTextStyles.labelMedium
          .copyWith(color: colorScheme.onSurfaceVariant),
      labelSmall: AppTextStyles.labelSmall
          .copyWith(color: colorScheme.onSurfaceVariant),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: colorScheme.surfaceTint,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle:
            AppTextStyles.titleLarge.copyWith(color: colorScheme.onSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class AppSpacingTokens {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadiusTokens {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 999;
}

class AppAnimationTokens {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
}
