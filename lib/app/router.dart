import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/habits/presentation/screens/habits_screen.dart';
import '../features/focus/presentation/screens/focus_screen.dart';
import '../features/journal/presentation/screens/journal_screen.dart';
import '../features/analytics/presentation/screens/analytics_screen.dart';
import '../features/premium/presentation/screens/premium_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/habits',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/habits',
            builder: (context, state) => const HabitsScreen(),
          ),
          GoRoute(
            path: '/focus',
            builder: (context, state) => const FocusScreen(),
          ),
          GoRoute(
            path: '/journal',
            builder: (context, state) => const JournalScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/premium',
            builder: (context, state) => const PremiumScreen(),
          ),
        ],
      ),
    ],
  );
});

class _MainShell extends ConsumerStatefulWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  final _locations = [
    '/habits',
    '/focus',
    '/journal',
    '/analytics',
    '/premium'
  ];
  final _labels = ['Habits', 'Focus', 'Journal', 'Analytics', 'Premium'];
  final _icons = [
    Icons.track_changes_rounded,
    Icons.center_focus_strong_rounded,
    Icons.book_outlined,
    Icons.analytics_outlined,
    Icons.diamond_outlined,
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _locations.indexWhere((l) => location.startsWith(l));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          context.go(_locations[index]);
        },
        destinations: List.generate(_labels.length, (index) {
          return NavigationDestination(
            icon: Icon(_icons[index]),
            selectedIcon: Icon(_icons[index], fill: 1.0),
            label: _labels[index],
          );
        }),
      ),
    );
  }
}
