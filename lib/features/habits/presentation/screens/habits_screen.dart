import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../controllers/habit_controller.dart';
import '../providers/habit_providers.dart';
import '../../../../features/premium/presentation/providers/premium_provider.dart';
import '../widgets/habit_card.dart';
import '../widgets/habit_form.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_completion.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/glow_button.dart';
import '../../../../app/widgets/progress_ring.dart';
import '../../../../app/widgets/week_strip.dart';
import '../../../../app/widgets/stat_tile.dart';
import '../../../../app/widgets/mini_week_strip.dart';
import '../../../../app/widgets/pill_chip.dart';
import '../../../../app/widgets/app_empty_state.dart';
import '../../../../core/constants/category_type.dart';
import '../../../../core/constants/app_constants.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  /// Index into `['All', ...AppConstants.habitCategories]`.
  ///
  /// Replaces a `TabController`. The category filter is the same interaction,
  /// but a pill row lets the selected pill animate its own fill and sit on the
  /// header's glass, and it removes the `TabBar`'s full-width underline that
  /// fought the header gradient.
  int _selectedCategory = 0;

  static final List<String> _categories = [
    'All',
    ...AppConstants.habitCategories,
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(habitControllerProvider);
    final habits = state.habits;
    final todaysCompletions = state.todaysCompletions;
    final progress = ref.watch(todaysProgressProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          _buildHeroHeader(context, progress),
          _buildCategoryFilter(context),
          _buildHabitList(habits, todaysCompletions),
        ],
      ),
      floatingActionButton: GlowButton(
        label: 'New Habit',
        icon: Icons.add_rounded,
        accent: AppColors.neonCyan,
        height: 52,
        onPressed: () {
          final isPremium = ref.read(isPremiumProvider);
          final activeHabits = habits.where((h) => !h.isArchived).length;

          if (!isPremium && activeHabits >= AppConstants.freeTierMaxHabits) {
            _showUpgradeDialog(context);
          } else {
            _showHabitForm();
          }
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: AppSpacingTokens.gutter,
      title: Text(
        'Habits',
        style: AppTextStyles.headlineSmall.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  /// Hero header for the Habits tab.
  ///
  /// A plain [SliverToBoxAdapter] rather than a collapsing `FlexibleSpaceBar`: the
  /// market pattern (Streaks, Trophy) is a fixed gradient card with a ring, a
  /// week chain and streak stats, and a non-collapsing box makes overlap
  /// structurally impossible.
  Widget _buildHeroHeader(BuildContext context, double progress) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(habitControllerProvider);

    final completedCount = state.todaysCompletions.length;
    final dueCount =
        state.habits.where((h) => !h.isArchived && _isDueToday(h)).length;
    final active = state.habits.where((h) => !h.isArchived).toList();

    final bestCurrentStreak = active.isEmpty
        ? 0
        : active.map((h) => h.currentStreak).reduce(math.max);
    final longestStreak = active.isEmpty
        ? 0
        : active.map((h) => h.longestStreak).reduce(math.max);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacingTokens.gutter,
          0,
          AppSpacingTokens.gutter,
          AppSpacingTokens.md,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadiusTokens.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              // A dark obsidian panel with a faint neon wash, not a saturated
              // gradient: the ring, the week chain and the streak numbers are
              // the content, and the surface is only there to lift them off the
              // page. `AppColors.glass` resolves the tint into the fill up
              // front, so the two translucent layers do not compound.
              decoration: AppColors.glass(
                colorScheme,
                radius: AppRadiusTokens.xl,
                opacity: 0.55,
                tint: AppColors.neonCyan,
                tintOpacity: 0.07,
                border: Border.all(color: AppColors.hairline(colorScheme)),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacingTokens.md),
              child: Stack(
                children: [
                  // Two off-centre blooms behind the content. Without them the
                  // panel is just a flat rectangle and the glass has nothing to
                  // pick up.
                  const Positioned.fill(
                    child: AuroraBackdrop(
                      accentA: AppColors.neonCyan,
                      accentB: AppColors.radiantViolet,
                      opacity: 0.2,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ProgressRing(
                            // `progressFor` returns 1.0 when nothing is due,
                            // which drew a full ring next to "0 of 0" and read
                            // as 100% done. Idle days show an empty track.
                            value: dueCount == 0 ? 0.0 : progress,
                            size: 84,
                            strokeWidth: 8,
                            color: colorScheme.primary,
                            gradient: const [
                              AppColors.neonCyan,
                              AppColors.radiantViolet,
                            ],
                            glow: 0.55,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedSwitcher(
                                  duration: AppAnimationTokens.medium,
                                  switchInCurve: Curves.easeOutCubic,
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(
                                    scale: animation,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  ),
                                  // Keyed on the number so a completion
                                  // counts up rather than the text being
                                  // swapped in place.
                                  child: Text(
                                    '$completedCount',
                                    key: ValueKey(completedCount),
                                    style: AppTextStyles.metricLarge.copyWith(
                                      fontSize: 24,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  'of $dueCount',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacingTokens.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Today',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _encouragementFor(
                                    completed: completedCount,
                                    due: dueCount,
                                  ),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacingTokens.md),
                      Center(
                        child: WeekStrip(
                          days: _buildWeekDays(state.habits),
                          todayIndex: DateTime.now().weekday - 1,
                          accent: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacingTokens.md),
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              icon: Icons.local_fire_department_rounded,
                              value: '$bestCurrentStreak',
                              label: 'Current streak',
                              subtitle: bestCurrentStreak == 0
                                  ? 'No streak yet'
                                  : bestCurrentStreak == 1
                                      ? 'day in a row'
                                      : 'days in a row',
                              accent: AppColors.habitDiscipline,
                            ),
                          ),
                          const SizedBox(width: AppSpacingTokens.sm),
                          Expanded(
                            child: StatTile(
                              icon: Icons.emoji_events_rounded,
                              value: '$longestStreak',
                              label: 'Personal best',
                              subtitle: longestStreak == 0
                                  ? 'Start today'
                                  : 'keep it up',
                              accent: AppColors.habitCraft,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The category filter, as a row of glass pills pinned under the app bar.
  ///
  /// Pinned so it stays reachable while scrolling a long habit list, but on a
  /// translucent surface: the original opaque `TabBar` background left a solid
  /// band cutting the header in half once the list scrolled under it.
  Widget _buildCategoryFilter(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _FilterHeaderDelegate(
        height: 66,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.cardFill(scheme, opacity: 0.72),
                border: Border(
                  bottom: BorderSide(color: AppColors.hairline(scheme)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacingTokens.sm + 2,
                ),
                child: GlassPillRow(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacingTokens.gutter,
                  ),
                  pills: [
                    for (var i = 0; i < _categories.length; i++)
                      GlassPill(
                        label: _categories[i],
                        selected: _selectedCategory == i,
                        icon: i == 0
                            ? null
                            : CategoryType.tryFromString(_categories[i])?.icon,
                        accent: i == 0
                            ? scheme.primary
                            : CategoryType.tryFromString(
                                    _categories[i],
                                  )?.color ??
                                scheme.primary,
                        onTap: () => _selectCategory(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectCategory(int index) {
    if (_selectedCategory == index) return;
    setState(() => _selectedCategory = index);
  }

  /// Rebuilds the Monday-first week chain for the whole list.
  ///
  /// A day reads as complete only when every active habit kept it, partial
  /// when some did. With no habits at all the chain stays entirely "upcoming"
  /// rather than showing a row of failures before the user has started.
  List<WeekDayState> _buildWeekDays(List<Habit> habits) {
    final active = habits.where((h) => !h.isArchived).toList();
    if (active.isEmpty) {
      return List<WeekDayState>.filled(7, WeekDayState.upcoming);
    }

    return List<WeekDayState>.generate(7, (index) {
      var kept = 0;
      var upcoming = 0;

      for (final habit in active) {
        final chain = deriveWeekStates(
          lastCompletedAt: habit.lastCompletedAt,
          currentStreak: habit.currentStreak,
        );
        switch (chain[index]) {
          case WeekDayState.complete:
            kept++;
          case WeekDayState.upcoming:
            upcoming++;
          case WeekDayState.partial:
          case WeekDayState.missed:
            break;
        }
      }

      // A day that has not happened yet must not be painted as a miss.
      if (upcoming == active.length) return WeekDayState.upcoming;
      if (kept == 0) return WeekDayState.missed;
      if (kept == active.length) return WeekDayState.complete;
      return WeekDayState.partial;
    });
  }

  /// Encouraging copy, in the spirit of Fabulous: say what is left, not what is
  /// missing, and never scold an empty day.
  String _encouragementFor({required int completed, required int due}) {
    if (due == 0) return 'Nothing scheduled today.';
    if (completed == 0) return "Start with one small win.";
    if (completed >= due) return 'All done. That is a full day.';
    final remaining = due - completed;
    return remaining == 1 ? 'One left. Finish strong.' : '$remaining to go.';
  }

  Widget _buildHabitList(
      List<Habit> habits, List<HabitCompletion> completions) {
    final selectedCategory = _categories[_selectedCategory];

    List<Habit> filteredHabits;
    if (selectedCategory == 'All') {
      filteredHabits = habits.where((h) => !h.isArchived).toList();
    } else {
      filteredHabits = habits
          .where((h) => h.category == selectedCategory && !h.isArchived)
          .toList();
    }

    filteredHabits.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (filteredHabits.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(selectedCategory),
      );
    }

    // Keyed on the category so switching filters rebuilds the stagger from the
    // top. Without this the new category's cards inherit the previous one's
    // already-finished animations and appear instantly, which reads as the
    // filter not having applied at all.
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacingTokens.gutter,
        AppSpacingTokens.md,
        AppSpacingTokens.gutter,
        120,
      ),
      sliver: SliverList.separated(
        key: ValueKey('habit-list-$selectedCategory'),
        itemCount: filteredHabits.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppSpacingTokens.sm),
        itemBuilder: (context, index) {
          final habit = filteredHabits[index];
          final completion =
              completions.where((c) => c.habitId == habit.id).firstOrNull;
          final isCompleted = completion != null;

          return HabitCard(
            habit: habit,
            isCompleted: isCompleted,
            onTap: () => _showHabitForm(habit: habit),
            onComplete: () => _completeHabit(habit.id),
            onUncomplete: () => _uncompleteHabit(habit.id),
            onLongPress: () => _showHabitOptions(habit),
            onArchive: () => _archiveHabit(habit),
            onDelete: () => _confirmDeleteHabit(habit),
          )
              .animate()
              // Capped so a long list does not leave the last rows invisible
              // for half a second: 12 cards is already 660ms.
              .fadeIn(
                delay: Duration(milliseconds: 55 * index.clamp(0, 12)),
              )
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    final theme = Theme.of(context);
    final isAll = category == 'All';

    // No inline call to action: the "New Habit" button is already on screen and
    // a second one collided with it. One primary action per screen, the way the
    // market trackers do it.
    return Padding(
      padding: const EdgeInsets.only(bottom: 96),
      child: AppEmptyState(
        icon: isAll ? Icons.track_changes_outlined : _getCategoryIcon(category),
        title: isAll ? 'No habits yet' : 'No $category habits',
        message: isAll
            ? 'Create your first habit to start building better routines'
            : 'Add a habit in the $category category to see it here',
        accent: theme.colorScheme.primary,
      ),
    );
  }

  void _showHabitForm({Habit? habit}) {
    showHabitFormSheet(context, ref.read(habitControllerProvider.notifier),
        habit: habit);
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: const Text(
          'Free tier allows up to 7 habits.\n\n'
          'Upgrade to Premium for:\n'
          '• Unlimited habits\n'
          '• Advanced analytics\n'
          '• Custom focus sessions\n'
          '• Cloud sync & backup\n'
          '• Priority support\n\n'
          '\$4.99/month or \$39.99/year',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(premiumProvider.notifier).upgradeToPremium();
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeHabit(String habitId) async {
    final result =
        await ref.read(habitControllerProvider.notifier).completeHabit(habitId);
    if (!result.isRight && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.left?.userMessage ?? 'Unknown error')),
      );
    }
  }

  Future<void> _uncompleteHabit(String habitId) async {
    final result = await ref
        .read(habitControllerProvider.notifier)
        .uncompleteHabit(habitId);
    if (!result.isRight && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.left?.userMessage ?? 'Unknown error')),
      );
    }
  }

  /// Swipe-to-start.
  ///
  /// Returning the write's success is what lets `Dismissible` actually remove
  /// the row. If the write fails the card springs back into place, which is the
  /// correct outcome: nothing was archived, so nothing should disappear.
  Future<bool> _archiveHabit(Habit habit) async {
    final controller = ref.read(habitControllerProvider.notifier);
    final result = habit.isArchived
        ? await controller.unarchiveHabit(habit.id)
        : await controller.archiveHabit(habit.id);

    if (!result.isRight && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.left?.userMessage ?? 'Could not archive habit'),
        ),
      );
    }
    return result.isRight;
  }

  /// Swipe-to-end.
  ///
  /// Delete is destructive and irreversible, so it asks first. The confirmation
  /// is awaited inside `confirmDismiss`, so letting go of the card past the
  /// threshold pauses at the "held" position until the user answers, then
  /// animates out or springs back.
  Future<bool> _confirmDeleteHabit(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text(
            'Are you sure you want to delete "${habit.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    await ref.read(habitControllerProvider.notifier).deleteHabit(habit.id);
    return true;
  }

  void _showHabitOptions(Habit habit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _HabitOptionsSheet(habit: habit),
    );
  }

  bool _isDueToday(Habit habit) {
    final today = DateTime.now();
    final weekday = today.weekday;

    switch (habit.frequency) {
      case 'Daily':
        return true;
      case 'Weekdays':
        return weekday >= 1 && weekday <= 5;
      case 'Weekends':
        return weekday >= 6 && weekday <= 7;
      case 'Custom':
        return habit.customWeekdays.contains(weekday);
      default:
        return false;
    }
  }

  IconData _getCategoryIcon(String category) =>
      CategoryType.tryFromString(category)?.icon ?? Icons.star_outline;
}

/// Pins the glass category-filter strip to the top of the list.
///
/// A fixed extent rather than a `TabBar`'s intrinsic height, because the strip's
/// height now comes from the pills' own padding plus the blur's insets and would
/// otherwise change as pills scroll horizontally.
class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _FilterHeaderDelegate({required this.height, required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(height: height, child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

/// The long-press options sheet for a habit.
///
/// Presented on glass rather than a solid `surface` rectangle: the sheet is the
/// only thing between the user and the list behind it, and a translucent panel
/// keeps the card they just pressed visible so the action reads as applying to
/// it.
class _HabitOptionsSheet extends ConsumerWidget {
  final Habit habit;

  const _HabitOptionsSheet({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryColor = habit.categoryColor;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadiusTokens.sheetTop),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardFill(colorScheme, opacity: 0.88),
            border: Border(
              top: BorderSide(color: AppColors.hairline(colorScheme)),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacingTokens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacingTokens.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadiusTokens.sm),
                  ),
                  child: Icon(habit.categoryIcon, color: categoryColor),
                ),
                title: Text(
                  habit.title,
                  style: AppTextStyles.titleMedium,
                ),
                subtitle: Text(
                  habit.category,
                  style: AppTextStyles.bodyMedium.copyWith(color: categoryColor),
                ),
              ),
              Divider(color: AppColors.hairline(colorScheme), height: 1),
              _buildOptionTile(
                context,
                icon: Icons.edit_outlined,
                title: 'Edit Habit',
                onTap: () {
                  Navigator.pop(context);
                  _showEditForm(context, ref);
                },
              ),
              _buildOptionTile(
                context,
                icon: habit.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                title: habit.isArchived ? 'Unarchive' : 'Archive',
                onTap: () => _toggleArchive(context, ref),
              ),
              if (habit.currentStreak > 0 && habit.streakFreezesUsed < 3)
                _buildOptionTile(
                  context,
                  icon: Icons.shield_outlined,
                  title: 'Use Streak Freeze (${3 - habit.streakFreezesUsed} left)',
                  onTap: () => _useStreakFreeze(context, ref),
                ),
              _buildOptionTile(
                context,
                icon: Icons.delete_outlined,
                title: 'Delete Habit',
                isDestructive: true,
                onTap: () => _deleteHabit(context, ref),
              ),
              const SizedBox(height: AppSpacingTokens.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final color =
        isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: AppTextStyles.titleMedium.copyWith(color: color)),
      onTap: onTap,
    );
  }

  void _showEditForm(BuildContext context, WidgetRef ref) {
    final controller = ref.read(habitControllerProvider.notifier);
    showHabitFormSheet(context, controller, habit: habit);
  }

  void _toggleArchive(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    final controller = ref.read(habitControllerProvider.notifier);
    if (habit.isArchived) {
      controller.unarchiveHabit(habit.id);
    } else {
      controller.archiveHabit(habit.id);
    }
  }

  void _useStreakFreeze(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    ref.read(habitControllerProvider.notifier).useStreakFreeze(habit.id);
  }

  void _deleteHabit(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text(
            'Are you sure you want to delete "${habit.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(habitControllerProvider.notifier).deleteHabit(habit.id);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Opens [HabitForm] and persists the result through [controller].
///
/// When [habit] is provided the existing habit is updated, otherwise a new
/// habit is created.
Future<void> showHabitFormSheet(
  BuildContext context,
  HabitController controller, {
  Habit? habit,
}) async {
  final edited = await showModalBottomSheet<Habit>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => HabitForm(habit: habit),
  );
  if (edited == null) return;

  final result = habit == null
      ? await controller.createHabit(
          title: edited.title,
          category: edited.category,
          description: edited.description,
          frequency: edited.frequency,
          customWeekdays: edited.customWeekdays,
          timeOfDay: edited.timeOfDay,
          targetCount: edited.targetCount,
          targetDuration: edited.targetDuration,
          cue: edited.cue,
        )
      : await controller.updateHabit(edited);

  if (result.isLeft && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(result.left?.userMessage ?? 'Could not save habit')),
    );
  }
}
