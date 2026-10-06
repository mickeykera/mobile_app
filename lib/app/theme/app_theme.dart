import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'text_styles.dart';

/// Spacing scale. A 4pt grid; the four steps between `xs` and `md` are the ones
/// that actually get used, the rest exist so a screen never has to invent one.
class AppSpacingTokens {
  const AppSpacingTokens._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page gutter. Wider than [md] on purpose: the old 16dp gutter
  /// put cards almost edge to edge, which is what made the list look cramped.
  static const double gutter = 20;
}

/// Corner radii.
///
/// Three steps and a pill. More than that and a screen starts to look like it
/// was assembled from different kits.
class AppRadiusTokens {
  const AppRadiusTokens._();

  /// Small chips and icon wells.
  static const double sm = 8;

  /// Compact controls. Day cells in the week strip.
  static const double md = 12;

  /// Major cards: habit rows, stat tiles, journal prompts.
  static const double lg = 20;

  /// Sheets and dialogs.
  static const double xl = 24;

  /// Fully rounded pills, action chips, the FAB.
  static const double full = 999;

  /// Input fields and buttons.
  static const double input = 16;

  /// Backwards-compatible alias: the old `xl`/`xxl` names were used for sheet
  /// corner radii, which are now [xl] and [sheetTop].
  static const double xxl = 28;
  static const double sheetTop = 28;
}

/// Motion tokens.
///
/// Durations are short on purpose. A productivity app is used in short
/// sessions and often one-handed, so a 600ms transition is a tax the user pays
/// on every navigation. Everything here completes inside a quarter second
/// except entrance staggers, which are per-item delays rather than per-item
/// durations.
class AppAnimationTokens {
  const AppAnimationTokens._();

  /// Press-down response and icon morphs.
  static const Duration fast = Duration(milliseconds: 150);

  /// State flips: checkbox fills, chip selection, crossfades.
  static const Duration medium = Duration(milliseconds: 250);

  /// Entrance staggers and larger layout changes.
  static const Duration slow = Duration(milliseconds: 350);

  /// The scale a [Pressable] shrinks to while held.
  static const double pressScale = 0.96;

  /// Delay between consecutive children in a staggered list.
  static const Duration stagger = Duration(milliseconds: 55);
}

class AppTheme {
  const AppTheme._();

  static ThemeData lightTheme = _buildTheme(AppColors.lightColorScheme, false);
  static ThemeData darkTheme = _buildTheme(AppColors.darkColorScheme, true);

  static ThemeData _buildTheme(ColorScheme colorScheme, bool isDark) {
    final TextTheme textTheme = _textThemeFor(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // The explicit `textTheme` above already sets this on all fifteen styles,
      // but the theme-level family is what catches anything Material builds for
      // itself - a default text selection menu, a date picker header, a
      // tooltip - which never goes through `AppTextStyles`.
      fontFamily: AppTextStyles.fontFamily,

      // The app paints its own gradient headers on most screens, so the default
      // surface tint is only ever a fallback.
      canvasColor: colorScheme.surface,

      splashFactory: InkSparkle.splashFactory,

      cardTheme: CardThemeData(
        color: AppColors.cardFill(colorScheme),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.lg),
        ),
        margin: EdgeInsets.zero,
      ),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),

      // Transparent, because every header in this app is a gradient box that
      // needs to show through the app bar. The previous solid `surface` here
      // painted an opaque bar across the top of every gradient header.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadiusTokens.sheetTop),
          ),
        ),
        showDragHandle: false,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardFill(colorScheme, opacity: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.lg),
        ),
        titleTextStyle:
            AppTextStyles.headlineSmall.copyWith(color: colorScheme.onSurface),
        contentTextStyle: AppTextStyles.bodyMedium
            .copyWith(color: colorScheme.onSurfaceVariant),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.hairline(colorScheme),
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: _inputTheme(colorScheme),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: AppTextStyles.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: AppTextStyles.labelLarge,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: AppTextStyles.labelLarge,
          side: BorderSide(color: AppColors.hairline(colorScheme)),
          shape: const StadiumBorder(),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppTextStyles.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const StadiumBorder(),
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: AppColors.onColorFor(colorScheme.primary, colorScheme),
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: AppTextStyles.labelLarge,
        shape: const StadiumBorder(),
      ),

      // Action chips and filters are pills with a hairline, not Material's
      // rounded-rectangle chips with a heavy selected outline.
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: colorScheme.primary.withValues(alpha: 0.16),
        side: BorderSide(color: AppColors.hairline(colorScheme)),
        labelStyle: AppTextStyles.labelLarge.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? AppColors.surfaceRaisedDark : colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.labelSmall.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: colorScheme.primary, width: 2.5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
        overlayColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: 0.06),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(AppTextStyles.labelLarge),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.hairline(colorScheme)),
          ),
          shape: const WidgetStatePropertyAll(
            StadiumBorder(),
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        titleTextStyle:
            AppTextStyles.titleMedium.copyWith(color: colorScheme.onSurface),
        subtitleTextStyle: AppTextStyles.bodySmall
            .copyWith(color: colorScheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadiusTokens.md),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cardFill(colorScheme, opacity: 0.96),
        contentTextStyle:
            AppTextStyles.bodyMedium.copyWith(color: colorScheme.onSurface),
        actionTextColor: colorScheme.primary,
        elevation: 0,
        shape: const StadiumBorder(),
        insetPadding: const EdgeInsets.all(AppSpacingTokens.md),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.cardFill(colorScheme, opacity: 0.96),
          borderRadius: BorderRadius.circular(AppRadiusTokens.sm),
          border: Border.all(color: AppColors.hairline(colorScheme)),
        ),
        textStyle:
            AppTextStyles.labelSmall.copyWith(color: colorScheme.onSurface),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        thumbColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primary.withValues(alpha: 0.2),
        trackHeight: 4,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primary.withValues(alpha: 0.15),
        circularTrackColor: colorScheme.primary.withValues(alpha: 0.15),
      ),
    );
  }

  /// Inputs are borderless: a soft filled container with no outline at all.
  ///
  /// The previous theme drew a 1px `OutlineInputBorder` on every field, which
  /// put roughly forty hard rectangles on the Journal screen and made it look
  /// like a form rather than a page. The focus state is carried by the fill
  /// colour and the label instead.
  static InputDecorationTheme _inputTheme(ColorScheme scheme) {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadiusTokens.input),
      borderSide: BorderSide.none,
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.insetFill(scheme),
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline,
      errorBorder: outline,
      focusedErrorBorder: outline,
      disabledBorder: outline,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacingTokens.md,
        vertical: AppSpacingTokens.md,
      ),
      hintStyle: AppTextStyles.placeholder.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      floatingLabelStyle: AppTextStyles.labelMedium.copyWith(
        color: scheme.primary,
      ),
      errorStyle: AppTextStyles.labelSmall.copyWith(color: scheme.error),
      prefixIconColor: scheme.onSurfaceVariant.withValues(alpha: 0.7),
      suffixIconColor: scheme.onSurfaceVariant.withValues(alpha: 0.7),
      counterStyle: AppTextStyles.labelSmall.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }

  static TextTheme _textThemeFor(ColorScheme scheme) {
    return TextTheme(
      displayLarge:
          AppTextStyles.displayLarge.copyWith(color: scheme.onSurface),
      displayMedium:
          AppTextStyles.displayMedium.copyWith(color: scheme.onSurface),
      displaySmall:
          AppTextStyles.displaySmall.copyWith(color: scheme.onSurface),
      headlineLarge:
          AppTextStyles.headlineLarge.copyWith(color: scheme.onSurface),
      headlineMedium:
          AppTextStyles.headlineMedium.copyWith(color: scheme.onSurface),
      headlineSmall:
          AppTextStyles.headlineSmall.copyWith(color: scheme.onSurface),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: scheme.onSurface),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: scheme.onSurface),
      titleSmall: AppTextStyles.titleSmall.copyWith(color: scheme.onSurface),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: scheme.onSurface),
      bodyMedium:
          AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
      bodySmall:
          AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: scheme.onSurface),
      labelMedium:
          AppTextStyles.labelMedium.copyWith(color: scheme.onSurfaceVariant),
      labelSmall:
          AppTextStyles.labelSmall.copyWith(color: scheme.onSurfaceVariant),
    );
  }
}
