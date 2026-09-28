import 'dart:math' as math;

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
import '../../../../app/widgets/progress_ring.dart';
import '../../../../app/widgets/week_strip.dart';
import '../../../../app/widgets/stat_tile.dart';
import '../../../../app/widgets/mini_week_strip.dart';
import '../../../../app/widgets/app_empty_state.dart';
import '../../../../core/constants/app_constants.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: AppConstants.habitCategories.length + 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(habitControllerProvider);
    final habits = state.habits;
    final todaysCompletions = state.todaysCompletions;

    final progress = ref.watch(todaysProgressProvider);

    final allCategories = ['All', ...AppConstants.habitCategories];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            titleSpacing: AppSpacingTokens.lg,
            title: Text(
              'Habits',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _buildSliverAppBar(context, progress),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                tabs: allCategories.map((cat) => Tab(text: cat)).toList(),
                onTap: (index) {
                  setState(() {});
                },
              ),
            ),
          ),
          _buildHabitList(habits, todaysCompletions),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final isPremium = ref.read(isPremiumProvider);
          final activeHabits = habits.where((h) => !h.isArchived).length;

          if (!isPremium && activeHabits >= AppConstants.freeTierMaxHabits) {
            _showUpgradeDialog(context);
          } else {
            _showHabitForm();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Habit'),
      ),
    );
  }

  /// Hero header for the Habits tab.
  ///
  /// Deliberately a plain [SliverToBoxAdapter] rather than a collapsing
  /// `FlexibleSpaceBar`: the market pattern (Streaks, Trophy) is a fixed
  /// gradient card with a ring, a week chain and streak stats, and a
  /// non-collapsing box makes overlap structurally impossible.
  Widget _buildSliverAppBar(BuildContext context, double progress) {
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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadiusTokens.xxl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacingTokens.lg,
          AppSpacingTokens.md,
          AppSpacingTokens.lg,
          AppSpacingTokens.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ProgressRing(
                  // `progressFor` returns 1.0 when nothing is due, which drew a
                  // full ring next to "0 of 0" and read as 100% done. Idle days
                  // now show an empty track instead.
                  value: dueCount == 0 ? 0.0 : progress,
                  size: 76,
                  strokeWidth: 8,
                  color: colorScheme.primary,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$completedCount',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      Text(
                        'of $dueCount',
                        style: theme.textTheme.labelSmall?.copyWith(
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _encouragementFor(
                          completed: completedCount,
                          due: dueCount,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacingTokens.md),
            WeekStrip(
              days: _buildWeekDays(state.habits),
              todayIndex: DateTime.now().weekday - 1,
              accent: colorScheme.primary,
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
                    subtitle: longestStreak == 0 ? 'Start today' : 'keep it up',
                    accent: AppColors.habitCraft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    final selectedCategory = _tabController.index == 0
        ? 'All'
        : AppConstants.habitCategories[_tabController.index - 1];

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

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacingTokens.md),
      sliver: SliverList.separated(
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
          ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1, end: 0);
        },
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    final theme = Theme.of(context);
    final isAll = category == 'All';

    // No inline call to action: the "New Habit" FAB is already on screen and a
    // second button collided with it. One primary action per screen, the way
    // the market trackers do it.
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

  void _showHabitOptions(Habit habit) {
    showModalBottomSheet(
      context: context,
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Mind':
        return Icons.psychology_outlined;
      case 'Body':
        return Icons.fitness_center_outlined;
      case 'Craft':
        return Icons.code_outlined;
      case 'Discipline':
        return Icons.shield_outlined;
      default:
        return Icons.star_outline;
    }
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _HabitOptionsSheet extends ConsumerWidget {
  final Habit habit;

  const _HabitOptionsSheet({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryColor = habit.categoryColor;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(AppSpacingTokens.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacingTokens.lg),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(habit.categoryIcon, color: categoryColor),
            ),
            title: Text(habit.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(habit.category,
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: categoryColor)),
          ),
          const Divider(),
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
      title: Text(title,
          style: theme.textTheme.titleMedium?.copyWith(color: color)),
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
