import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/text_styles.dart';
import 'widgets/pressable.dart';
import '../features/today/presentation/screens/today_screen.dart';
import '../features/goals/presentation/screens/goals_screen.dart';
import '../features/projects/presentation/screens/project_detail_screen.dart';
import '../features/projects/presentation/screens/projects_screen.dart';
import '../features/tasks/presentation/screens/tasks_screen.dart';
import '../features/habits/presentation/screens/habits_screen.dart';
import '../features/focus/presentation/screens/focus_screen.dart';
import '../features/journal/presentation/screens/journal_screen.dart';
import '../features/analytics/presentation/screens/analytics_screen.dart';
import '../features/premium/presentation/screens/premium_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/today',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: '/today',
            builder: (context, state) => const TodayScreen(),
          ),
          GoRoute(
            path: '/habits',
            builder: (context, state) => const HabitsScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksScreen(),
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
      // Drilldowns live outside the shell so the seven-item tab bar does not
      // follow you down into a single goal or project. They are pushed on top of
      // a tab, not added to it.
      GoRoute(
        path: '/goals',
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) => const ProjectsScreen(),
      ),
      GoRoute(
        path: '/projects/:id',
        builder: (context, state) => ProjectDetailScreen(
          projectId: state.pathParameters['id']!,
        ),
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
  /// One record per destination rather than three parallel lists.
  ///
  /// `_labels`, `_icons` and `_locations` were indexed in lockstep, which meant
  /// adding a tab meant editing three places and a mismatched index produced a
  /// label from one tab next to another tab's icon.
  static const _destinations = [
    _NavDestination(
      location: '/today',
      label: 'Today',
      icon: LucideIcons.layoutDashboard,
      accent: AppColors.accentWarmDeep,
      accentDark: AppColors.accentWarm,
    ),
    _NavDestination(
      location: '/habits',
      label: 'Habits',
      icon: LucideIcons.target,
      accent: AppColors.accentPrimaryDeep,
      accentDark: AppColors.accentPrimary,
    ),
    _NavDestination(
      location: '/tasks',
      label: 'Tasks',
      icon: LucideIcons.listChecks,
      accent: AppColors.accentLiveDeep,
      accentDark: AppColors.accentLive,
    ),
    _NavDestination(
      location: '/focus',
      label: 'Focus',
      icon: LucideIcons.crosshair,
      accent: AppColors.accentDeep,
      accentDark: AppColors.accentDeepDark,
    ),
    _NavDestination(
      location: '/journal',
      label: 'Journal',
      icon: LucideIcons.bookOpen,
      accent: AppColors.accentLiveDeep,
      accentDark: AppColors.accentLiveDark,
    ),
    _NavDestination(
      location: '/analytics',
      label: 'Analytics',
      icon: LucideIcons.chartNoAxesColumn,
      accent: AppColors.accentWarmDeep,
      accentDark: AppColors.accentWarm,
    ),
    _NavDestination(
      location: '/premium',
      label: 'Premium',
      icon: LucideIcons.diamond,
      accent: AppColors.accentDeep,
      accentDark: AppColors.accentDeepDark,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index =
        _destinations.indexWhere((d) => location.startsWith(d.location));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _GlassNavBar(
        destinations: _destinations,
        currentIndex: currentIndex,
        onSelected: (index) => context.go(_destinations[index].location),
      ),
    );
  }
}

class _NavDestination {
  final String location;
  final String label;
  final IconData icon;

  /// Each tab owns a colour so the bar is not five identical grey icons, and so
  /// the selected tab is identifiable by hue as well as by position.
  ///
  /// Held as a light/dark pair rather than one value because the bar is a
  /// blurred sheet: the colour has to clear 3:1 against *near-white glass* in
  /// light mode and against *obsidian glass* in dark mode, and the neon accents
  /// that work on obsidian only manage 2.6:1 on the light one.
  final Color accent;
  final Color accentDark;

  Color resolve(ColorScheme scheme) =>
      AppColors.accent(scheme, accent, accentDark);

  const _NavDestination({
    required this.location,
    required this.label,
    required this.icon,
    required this.accent,
    required this.accentDark,
  });
}

/// A glass tab bar.
///
/// `NavigationBar` was replaced rather than restyled: its indicator is a filled
/// pill with a hard edge, and its bar has an opaque background, so on a dark
/// theme it read as a solid grey strip pasted under the content. This floats over
/// the page with a blur, so the scrolling content is visible through it.
class _GlassNavBar extends StatelessWidget {
  final List<_NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const _GlassNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardFill(colorScheme, opacity: 0.82),
            border: Border(
              top: BorderSide(color: AppColors.hairline(colorScheme)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: AppSpacingTokens.sm,
            // `extendBody` lets content scroll behind the bar, so the bar needs
            // to absorb the home indicator itself.
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacingTokens.sm,
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = destination.resolve(theme.colorScheme);
    final color = selected
        ? accent
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        semanticButton: false,
        pressScale: 0.9,
        // No haptic per tab. Switching tabs fires an impact on every tap,
        // including when a user taps the current tab or scrolls and lands on
        // another one, which reads as an error rather than a confirmation.
        haptics: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacingTokens.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The selected tab grows slightly and lifts its icon, so the
              // active state is legible without relying on colour alone.
              AnimatedContainer(
                duration: AppAnimationTokens.medium,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.18 : 0),
                  borderRadius: BorderRadius.circular(AppRadiusTokens.full),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: -4,
                          ),
                        ]
                      : null,
                ),
                child: AnimatedScale(
                  duration: AppAnimationTokens.medium,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1.06 : 1.0,
                  child: Icon(destination.icon, size: 22, color: color),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: AppAnimationTokens.medium,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
