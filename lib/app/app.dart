import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ascend/app/theme/app_theme.dart';
import 'package:ascend/app/router.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.trending_up_rounded,
                size: 40,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ascend',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Initializing...',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Initialization Failed',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(error,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
