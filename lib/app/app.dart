import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ascend/app/theme/app_colors.dart';
import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/app/theme/text_styles.dart';
import 'package:ascend/app/router.dart';
import 'package:ascend/app/widgets/glow_button.dart';
import 'package:ascend/core/database/database.dart';

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

class AscendApp extends ConsumerWidget {
  const AscendApp({super.key});

  static const _scrollBehavior = AscendScrollBehavior();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final database = ref.watch(databaseServiceProvider);

    return FutureBuilder(
      future: database.initialize(),
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
            home: _ErrorScreen(error: snapshot.error.toString()),
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
                accentA: AppColors.neonCyan,
                accentB: AppColors.radiantViolet,
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
                          accentA: AppColors.neonCyan,
                          accentB: AppColors.radiantViolet,
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
                          color: AppColors.neonCyan.withValues(alpha: 0.16),
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonCyan.withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
                          size: 32,
                          color: AppColors.neonCyan,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacingTokens.lg),
                ShaderMask(
                  shaderCallback:
                      AppGradients.action(AppColors.neonCyan).createShader,
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

/// Stateful only so Retry can call `setState` and ask the enclosing
/// `FutureBuilder` to run `database.initialize()` again.
class _ErrorScreen extends StatefulWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  State<_ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<_ErrorScreen> {
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
                            accentB: AppColors.coralOrange,
                            opacity: 0.2,
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.error
                                .withValues(alpha: 0.16),
                            border: Border.all(
                              color: theme.colorScheme.error
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            Icons.error_outline,
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
                  // and at body size it was the first thing on screen.
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
                      widget.error,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacingTokens.lg),
                  GlowButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    accent: theme.colorScheme.primary,
                    width: double.infinity,
                    // No navigation callback: `FutureBuilder` re-runs
                    // `database.initialize()` on the next rebuild of this
                    // widget, so the retry is just this screen rebuilding. The
                    // old `pushNamedAndRemoveUntil('/')` pushed a named route
                    // onto a `MaterialApp` that has no `onGenerateRoute`, which
                    // threw instead of retrying.
                    onPressed: () => setState(() {}),
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
