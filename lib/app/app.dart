import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ascend/app/theme/app_colors.dart';
import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/app/theme/text_styles.dart';
import 'package:ascend/app/router.dart';
import 'package:ascend/app/widgets/glow_button.dart';
import 'package:ascend/core/database/database.dart';
import 'package:ascend/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AscendScrollBehavior extends MaterialScrollBehavior {
  /// Android 12+ draws a stretchy overscroll by default, which pulls the whole
  /// page past its bounds and looks broken on a screen that is mostly a
  /// gradient header. A glow indicator is used on Android instead, and iOS
  /// keeps its native bounce.
  const AscendScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // A glow tints the edge; the Android 12+ default instead scales and
    // deforms the content, which is the "stretches when I scroll" effect.
    switch (details.direction) {
      case AxisDirection.down:
        return GlowingOverscrollIndicator(
          axisDirection: AxisDirection.down,
          color: Theme.of(context).colorScheme.primary,
          child: child,
        );
      case AxisDirection.up:
        return GlowingOverscrollIndicator(
          axisDirection: AxisDirection.up,
          color: Theme.of(context).colorScheme.primary,
          child: child,
        );
      case AxisDirection.left:
      case AxisDirection.right:
        return child;
    }
  }
}

/// Stateful only so Retry can start a *new* `initialize()` future.
///
/// This has to be state *here*, not in the error screen. `FutureBuilder`
/// compares the new `future` against the old one and restarts only if it
/// changed, so the retry needs to replace the future on the widget that owns
/// the builder. Rebuilding `_ErrorScreen` alone - which is what a `setState`
/// inside it does - hands the builder the identical future it already
/// completed, and the user taps Retry and nothing happens.
class AscendApp extends ConsumerStatefulWidget {
  const AscendApp({super.key});

  @override
  ConsumerState<AscendApp> createState() => _AscendAppState();
}

class _AscendAppState extends ConsumerState<AscendApp> {
  static const _scrollBehavior = AscendScrollBehavior();

  /// Bumped by Retry. The future is derived from it during build rather than
  /// created in the tap handler - see [_databaseFuture].
  int _attempt = 0;

  /// The attempt number [_databaseFuture] was built for.
  int _futureForAttempt = -1;
  Future<void>? _databaseFuture;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // The future is created *here*, in the same synchronous pass that hands it
    // to the `FutureBuilder` below, so the builder can subscribe before the
    // future completes. Creating it inside the Retry handler instead leaves a
    // gap: `setState` only schedules a rebuild, so a fast-failing future
    // completes in a microtask with nothing listening, and Dart reports the
    // error as unhandled even though the builder is about to handle it.
    if (_futureForAttempt != _attempt) {
      _futureForAttempt = _attempt;
      _databaseFuture = _initialize();
    }

    return FutureBuilder(
      future: _databaseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            scrollBehavior: _scrollBehavior,
            home: const _LoadingScreen(),
            debugShowCheckedModeBanner: false,
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            scrollBehavior: _scrollBehavior,
            home: _ErrorScreen(
              error: snapshot.error.toString(),
              onRetry: _retry,
            ),
            debugShowCheckedModeBanner: false,
          );
        }

        return MaterialApp.router(
          title: 'Ascend',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          scrollBehavior: _scrollBehavior,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  /// Brings storage up to the current schema, then runs the Habit -> Task
  /// migration if this install has not completed it.
  ///
  /// Both steps are in the one future that gates the first frame, and the order
  /// matters: the migration resolves its repositories through `ref`, so it must
  /// be the *same* cached provider instances the UI will later read through.
  /// Running it first means the repositories hydrate once, already migrated, and
  /// no two in-memory copies of the habit list can race a write.
  ///
  /// The migration short-circuits on a stored marker, so every launch after the
  /// first costs one key read. See [HabitTaskMigrationRunner] for why this is
  /// awaited rather than left in the background.
  Future<void> _initialize() async {
    await ref.read(databaseServiceProvider).initialize();
    await ref.read(habitTaskMigrationRunnerProvider).runIfRequired();
  }

  /// `DatabaseService.initialize` short-circuits on its own `_isInitialized`
  /// flag, and a failed attempt leaves that flag false, so calling it again
  /// genuinely re-runs `SharedPreferences.getInstance()`.
  void _retry() => setState(() => _attempt++);
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(
              color: AppColors.surfaceDark,
              child: AuroraBackdrop(
                accentA: AppColors.accentPrimary,
                accentB: AppColors.accentDeep,
                opacity: 0.18,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The mark pulses rather than sitting behind a spinner: it is
                // the first thing seen on launch, and a still logo plus a
                // spinning circle reads as a blocked app.
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: const AuroraBackdrop(
                          accentA: AppColors.accentPrimary,
                          accentB: AppColors.accentDeep,
                          opacity: 0.24,
                        )
                            .animate(
                              onPlay: (c) => c.repeat(reverse: true),
                            )
                            .scaleXY(
                              begin: 0.85,
                              end: 1.0,
                              duration: 1600.ms,
                              curve: Curves.easeInOut,
                            ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              AppColors.accentPrimary.withValues(alpha: 0.16),
                          border: Border.all(
                            color:
                                AppColors.accentPrimary.withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentPrimary
                                  .withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.trendingUp,
                          size: 32,
                          color: AppColors.accentPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacingTokens.lg),
                ShaderMask(
                  shaderCallback:
                      AppGradients.action(AppColors.accentPrimary).createShader,
                  child: const Text(
                    'Ascend',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacingTokens.sm),
                Text(
                  'Initializing your data…',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;

  /// Starts a fresh database attempt. Owned by `_AscendAppState` because only
  /// it can replace the future the `FutureBuilder` is watching.
  final VoidCallback onRetry;

  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Scrollable: a verbose database error on a small phone used to
            // overflow, which hid the retry button entirely.
            padding: const EdgeInsets.all(AppSpacingTokens.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: AuroraBackdrop(
                            accentA: theme.colorScheme.error,
                            accentB: AppColors.accentWarm,
                            opacity: 0.2,
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                theme.colorScheme.error.withValues(alpha: 0.16),
                            border: Border.all(
                              color: theme.colorScheme.error
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            LucideIcons.circleAlert,
                            size: 30,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacingTokens.lg),
                  Text(
                    "Couldn't open your data",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineSmall
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacingTokens.sm),
                  Text(
                    'Your habits and sessions live in a local database. If it '
                    'could not be opened, nothing has been lost yet.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacingTokens.md),
                  // The raw message is kept, but demoted to small monospace in
                  // an inset well: it is diagnostic detail, not the headline,
                  // and at body size it was the first thing on screen. The
                  // generic 'monospace' keyword resolved to a different face per
                  // platform, so this now names the bundled family directly.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacingTokens.sm + 4),
                    decoration: BoxDecoration(
                      color: AppColors.insetFill(
                        theme.colorScheme,
                        opacity: 0.5,
                      ),
                      borderRadius:
                          BorderRadius.circular(AppRadiusTokens.input),
                    ),
                    child: Text(
                      error,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontFamily: AppTextStyles.monoFontFamily,
                        fontSize: 11,
                        height: 1.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacingTokens.lg),
                  GlowButton(
                    label: 'Retry',
                    icon: LucideIcons.refreshCw,
                    accent: theme.colorScheme.primary,
                    width: double.infinity,
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
