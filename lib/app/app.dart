import 'package:flutter/material.dart';
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
  const AscendScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
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

class AscendApp extends ConsumerStatefulWidget {
  const AscendApp({super.key});

  @override
  ConsumerState<AscendApp> createState() => _AscendAppState();
}

class _AscendAppState extends ConsumerState<AscendApp> {
  static const _scrollBehavior = AscendScrollBehavior();

  int _attempt = 0;
  int _futureForAttempt = -1;
  Future<void>? _databaseFuture;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
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

  Future<void> _initialize() async {
    await ref.read(databaseServiceProvider).initialize();
    await ref.read(habitTaskMigrationRunnerProvider).runIfRequired();
  }

  void _retry() => setState(() => _attempt++);
}

class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _shouldAnimate = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      _shouldAnimate = !disableAnimations;
      if (_shouldAnimate) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _buildLoaderChildren(Color accentColor, bool shouldAnimate, AnimationController controller) {
    if (!shouldAnimate) {
      return [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2.5),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: 0.12),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          ),
          child: Icon(LucideIcons.trendingUp, size: 28, color: accentColor),
        ),
      ];
    }

    return [
      AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final progress = controller.value;
          double scale, opacity;
          if (progress < 0.5) {
            scale = 0.6 + progress * 0.8;
            opacity = 0.4 - progress * 0.3;
          } else {
            scale = 1.0 - (progress - 0.5) * 0.6;
            opacity = 0.25 - (progress - 0.5) * 0.25;
          }
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2.5),
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final progress = (controller.value + 0.3) % 1.0;
          double scale, opacity;
          if (progress < 0.5) {
            scale = 0.5 + progress * 0.7;
            opacity = 0.35 - progress * 0.25;
          } else {
            scale = 0.85 - (progress - 0.5) * 0.45;
            opacity = 0.225 - (progress - 0.5) * 0.225;
          }
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.7), width: 2),
                ),
              ),
            ),
          );
        },
      ),
      AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final pulse = 0.95 + 0.05 * (1 - (controller.value * 2).clamp(0.0, 1.0)).abs();
          return Transform.scale(
            scale: pulse,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.12),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Icon(LucideIcons.trendingUp, size: 28, color: accentColor),
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final accentColor = isDark ? AppColors.accentPrimaryDark : AppColors.accentPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: bgColor,
              child: AuroraBackdrop(
                accentA: accentColor,
                accentB: isDark ? AppColors.accentDeepDark : AppColors.accentDeep,
                opacity: isDark ? 0.18 : 0.08,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: _buildLoaderChildren(accentColor, _shouldAnimate, _controller),
                  ),
                ),
                const SizedBox(height: AppSpacingTokens.lg),
                ShaderMask(
                  shaderCallback: AppGradients.action(accentColor).createShader,
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
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : scheme.onSurfaceVariant.withValues(alpha: 0.7),
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
  final VoidCallback onRetry;

  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final errorColor = scheme.error;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
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
                            accentA: errorColor,
                            accentB: AppColors.accentWarm,
                            opacity: isDark ? 0.2 : 0.1,
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: errorColor.withValues(alpha: 0.16),
                            border: Border.all(color: errorColor.withValues(alpha: 0.4)),
                          ),
                          child: Icon(LucideIcons.circleAlert, size: 30, color: errorColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacingTokens.lg),
                  Text(
                    "Couldn't open your data",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacingTokens.sm),
                  Text(
                    'Your habits and sessions live in a local database. If it '
                    'could not be opened, nothing has been lost yet.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacingTokens.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacingTokens.sm + 4),
                    decoration: BoxDecoration(
                      color: AppColors.insetFill(scheme, opacity: 0.5),
                      borderRadius: BorderRadius.circular(AppRadiusTokens.input),
                    ),
                    child: Text(
                      error,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontFamily: AppTextStyles.monoFontFamily,
                        fontSize: 11,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacingTokens.lg),
                  GlowButton(
                    label: 'Retry',
                    icon: LucideIcons.refreshCw,
                    accent: scheme.primary,
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