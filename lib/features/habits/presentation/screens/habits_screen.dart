import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/app_clock.dart';
import '../../domain/habit_scheduling.dart';
import '../controllers/habit_controller.dart';
import '../providers/habit_providers.dart';
import '../../../../features/premium/presentation/providers/premium_provider.dart';
import '../widgets/habit_card.dart';
import '../widgets/habit_form.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_completion.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/domain/value_objects/task_schedule.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
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
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    final allHabits = state.habits;
    final todaysCompletions = state.todaysCompletions;

    // Split habits: non-migrated (managed by HabitController) and migrated (managed by TaskController)
    final nonMigratedHabits = ref.watch(nonMigratedHabitsProvider);
    final migratedHabits = ref.watch(migratedHabitsProvider);
    final recurringTasksFromMigrated =
        ref.watch(recurringTasksFromMigratedHabitsProvider);
    final migratedTaskCompletionsAsync =
        ref.watch(migratedHabitTaskCompletionsProvider(AppClock.now()));

    return migratedTaskCompletionsAsync.when(
      data: (migratedTaskCompletions) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context),
              _buildHeroHeader(context),
              _buildCategoryFilter(context),
              _buildHabitLists(
                nonMigratedHabits: nonMigratedHabits,
                migratedHabits: migratedHabits,
                recurringTasksFromMigrated: recurringTasksFromMigrated,
                migratedTaskCompletions: migratedTaskCompletions,
                todaysCompletions: todaysCompletions,
              ),
            ],
          ),
          floatingActionButton: GlowButton(
            label: 'New Habit',
            icon: LucideIcons.plus,
            accent: AppColors.accentPrimary,
            height: 52,
            onPressed: () {
              final isPremium = ref.read(isPremiumProvider);
              final activeHabits = allHabits.where((h) => !h.isArchived).length;

              if (!isPremium &&
                  activeHabits >= AppConstants.freeTierMaxHabits) {
                _showUpgradeDialog(context);
              } else {
                _showHabitForm();
              }
            },
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
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
  Widget _buildHeroHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(habitControllerProvider);

    // Only non-migrated habits contribute to the Habits screen's hero stats.
    // Migrated habits are managed by TaskController and appear in the "Recurring Tasks" section.
    final nonMigratedHabits = ref.watch(nonMigratedHabitsProvider);
    final nonMigratedActive =
        nonMigratedHabits.where((h) => !h.isArchived).toList();

    // Every number below is measured against that same non-migrated set. The
    // ring used to be driven by `todaysProgressProvider`, which spans *all*
    // habits, and `completedCount` by a raw row count that includes Task
    // occurrence rows. After a migration that made the numerator count rows no
    // denominator contained, so the ring could sit next to "3 of 1" — the two
    // halves of one card disagreeing about the same day.
    final dueCount =
        nonMigratedActive.where((h) => h.isDueOnDate(AppClock.now())).length;
    final completedCount = nonMigratedActive
        .where((h) => state.todaysCompletions.any((c) => c.habitId == h.id))
        .length;
    final progress = HabitController.progressFor(
      habits: nonMigratedActive,
      completions: state.todaysCompletions,
    );

    final bestCurrentStreak = nonMigratedActive.isEmpty
        ? 0
        : nonMigratedActive.map((h) => h.currentStreak).reduce(math.max);
    final longestStreak = nonMigratedActive.isEmpty
        ? 0
        : nonMigratedActive.map((h) => h.longestStreak).reduce(math.max);

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
                tint: AppColors.accentPrimary,
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
                      accentA: AppColors.accentPrimary,
                      accentB: AppColors.accentDeep,
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
                              AppColors.accentPrimary,
                              AppColors.accentDeep,
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

  /// Rebuilds the Monday-first week chain for non-migrated habits only.
  ///
  /// Migrated habits are managed by TaskController and don't contribute to
  /// the Habits screen's week chain.
  List<WeekDayState> _buildWeekDays(List<Habit> habits) {
    final active =
        habits.where((h) => !h.isArchived && h.taskId == null).toList();
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

  Widget _buildHabitLists({
    required List<Habit> nonMigratedHabits,
    required List<Habit> migratedHabits,
    required List<Task> recurringTasksFromMigrated,
    required Map<String, bool> migratedTaskCompletions,
    required List<HabitCompletion> todaysCompletions,
  }) {
    final selectedCategory = _categories[_selectedCategory];

    // Filter non-migrated habits by category
    List<Habit> filteredNonMigrated;
    if (selectedCategory == 'All') {
      filteredNonMigrated = nonMigratedHabits;
    } else {
      filteredNonMigrated = nonMigratedHabits
          .where((h) => h.category == selectedCategory)
          .toList();
    }
    filteredNonMigrated.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Filter migrated habits by category (using their original category)
    List<Habit> filteredMigrated;
    if (selectedCategory == 'All') {
      filteredMigrated = migratedHabits;
    } else {
      filteredMigrated =
          migratedHabits.where((h) => h.category == selectedCategory).toList();
    }
    filteredMigrated.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Filter recurring tasks from migrated habits by category
    List<Task> filteredRecurringTasks;
    if (selectedCategory == 'All') {
      filteredRecurringTasks = recurringTasksFromMigrated;
    } else {
      filteredRecurringTasks = recurringTasksFromMigrated
          .where((t) => t.category == selectedCategory)
          .toList();
    }
    filteredRecurringTasks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final hasNonMigrated = filteredNonMigrated.isNotEmpty;
    final hasMigrated =
        filteredMigrated.isNotEmpty || filteredRecurringTasks.isNotEmpty;

    if (!hasNonMigrated && !hasMigrated) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(selectedCategory),
      );
    }

    final children = <Widget>[
      if (hasNonMigrated) ...[
        _buildSectionHeader('Habits'),
        const SizedBox(height: AppSpacingTokens.sm),
        ..._buildNonMigratedHabitCards(
            filteredNonMigrated, todaysCompletions, selectedCategory),
        const SizedBox(height: AppSpacingTokens.lg),
      ],
      if (hasMigrated) ...[
        _buildSectionHeader('Recurring Tasks'),
        const SizedBox(height: AppSpacingTokens.sm),
        ..._buildMigratedTaskCards(filteredMigrated, filteredRecurringTasks,
            migratedTaskCompletions, selectedCategory),
      ],
    ];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacingTokens.gutter,
        AppSpacingTokens.md,
        AppSpacingTokens.gutter,
        120,
      ),
      sliver: SliverList(
        key: ValueKey('habit-lists-$selectedCategory'),
        delegate: SliverChildListDelegate(children),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: AppTextStyles.titleLarge.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  List<Widget> _buildNonMigratedHabitCards(
      List<Habit> habits, List<HabitCompletion> completions, String category) {
    return List<Widget>.generate(habits.length, (index) {
      final habit = habits[index];
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
        onMoreActions: () => _showHabitOptions(habit),
        onSwipeComplete: () async {
          await _completeHabit(habit.id);
          return true;
        },
        onSwipeUncomplete: () async {
          await _uncompleteHabit(habit.id);
          return true;
        },
      )
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 55 * index.clamp(0, 12)),
          )
          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
    });
  }

  List<Widget> _buildMigratedTaskCards(
      List<Habit> migratedHabits,
      List<Task> recurringTasks,
      Map<String, bool> taskCompletions,
      String category) {
    // Build a map from taskId to habit for quick lookup
    final habitByTaskId = {for (final h in migratedHabits) h.taskId!: h};

    // Merge tasks with their habit metadata
    final merged = <_MigratedTaskItem>[];
    for (final task in recurringTasks) {
      final habit = habitByTaskId[task.id];
      if (habit != null) {
        merged.add(_MigratedTaskItem(task: task, habit: habit));
      }
    }
    merged.sort((a, b) => a.task.sortOrder.compareTo(b.task.sortOrder));

    return List<Widget>.generate(merged.length, (index) {
      final item = merged[index];
      final isCompleted = taskCompletions[item.task.id] ?? false;

      return _MigratedTaskCard(
        task: item.task,
        habit: item.habit,
        isCompleted: isCompleted,
        onTap: () => _showTaskOptions(item.task, item.habit),
        onComplete: () => _completeMigratedTask(item.task.id),
        onUncomplete: () => _uncompleteMigratedTask(item.task.id),
      )
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 55 * index.clamp(0, 12)),
          )
          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
    });
  }

  Future<void> _completeMigratedTask(String taskId) async {
    final result = await ref
        .read(taskControllerProvider.notifier)
        .recordOccurrence(taskId, date: AppClock.now());
    if (!result.isRight && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.left?.userMessage ?? 'Unknown error')),
      );
    }
  }

  Future<void> _uncompleteMigratedTask(String taskId) async {
    final result = await ref
        .read(taskControllerProvider.notifier)
        .deleteOccurrence(taskId, date: AppClock.now());
    if (!result.isRight && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.left?.userMessage ?? 'Unknown error')),
      );
    }
  }

  void _showTaskOptions(Task task, Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MigratedTaskOptionsSheet(
        task: task,
        habit: habit,
        onComplete: () => _completeMigratedTask(task.id),
        onUncomplete: () => _uncompleteMigratedTask(task.id),
        onEditHabit: () => _showHabitForm(habit: habit),
        onDelete: () => _confirmDeleteMigratedHabit(habit),
      ),
    );
  }

  Future<bool> _confirmDeleteMigratedHabit(Habit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Task'),
        content: Text(
            'Are you sure you want to delete "${habit.title}"? This will also delete its completion history. This cannot be undone.'),
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

    // Delete the habit (which has the taskId link)
    final result =
        await ref.read(habitControllerProvider.notifier).deleteHabit(habit.id);
    if (result.isLeft && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(result.left?.userMessage ?? 'Could not delete habit')),
      );
    }
    return result.isRight;
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

  void _showHabitOptions(Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HabitOptionsSheet(habit: habit),
    );
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

/// Shared glass scaffold for bottom sheets.
class _SheetScaffold extends StatelessWidget {
  final List<Widget> children;

  const _SheetScaffold({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: AppSpacingTokens.md,
                  bottom: AppSpacingTokens.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: AppSpacingTokens.md),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    final categoryColor = habit.categoryColorFor(theme.brightness);

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
          child: Material(
            type: MaterialType.transparency,
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
                  style:
                      AppTextStyles.bodyMedium.copyWith(color: categoryColor),
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
                icon: LucideIcons.alarmClock,
                title: 'Snooze until tomorrow',
                onTap: () => _pickSchedule(
                  context,
                  ref,
                  title: 'Snooze until',
                  isReschedule: false,
                ),
              ),
              _buildOptionTile(
                context,
                icon: LucideIcons.calendarClock,
                title: 'Reschedule',
                onTap: () => _pickSchedule(
                  context,
                  ref,
                  title: 'Reschedule to',
                  isReschedule: true,
                ),
              ),
              if (habit.currentStreak > 0 && habit.streakFreezesUsed < 3)
                _buildOptionTile(
                  context,
                  icon: Icons.shield_outlined,
                  title:
                      'Use Streak Freeze (${3 - habit.streakFreezesUsed} left)',
                  onTap: () => _useStreakFreeze(context, ref),
                ),
              _buildOptionTile(
                context,
                icon: habit.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                title: habit.isArchived ? 'Unarchive' : 'Archive',
                onTap: () => _toggleArchive(context, ref),
              ),
              _buildOptionTile(
                context,
                icon: Icons.delete_outlined,
                title: 'Delete',
                isDestructive: true,
                onTap: () => _deleteHabit(context, ref),
              ),
              const SizedBox(height: AppSpacingTokens.md),
            ],
            ),
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
      title:
          Text(title, style: AppTextStyles.titleMedium.copyWith(color: color)),
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

  /// Opens the quick-date sheet for Snooze/Reschedule and applies the choice.
  ///
  /// The sheet stays open beneath the picker so the user can back out at any
  /// point; the write only happens once a concrete day is chosen.
  Future<void> _pickSchedule(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required bool isReschedule,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(habitControllerProvider.notifier);
    final now = AppClock.now();

    final choices = isReschedule
        ? [
            _ScheduleChoice('Today', todayAt(now)),
            _ScheduleChoice('Tomorrow', tomorrowAfter(now)),
            _ScheduleChoice('This weekend', thisWeekend(now)),
            _ScheduleChoice('Next week', nextWeek(now)),
          ]
        : [
            _ScheduleChoice('Later today', laterToday(now)),
            _ScheduleChoice('Tomorrow', tomorrowAfter(now)),
            _ScheduleChoice('This weekend', thisWeekend(now)),
            const _ScheduleChoice('Custom…', null),
          ];

    final selected = await showModalBottomSheet<_ScheduleChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _QuickScheduleSheet(title: title, choices: choices),
    );
    if (selected == null || !context.mounted) return;

    var target = selected.target;
    if (target == null) {
      final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null || !context.mounted) return;
      target = DateTime(date.year, date.month, date.day, kDefaultSchedulingHour);
    }

    navigator.pop();

    final result = isReschedule
        ? await controller.rescheduleHabit(habit.id, target)
        : await controller.snoozeHabit(habit.id, target);

    if (result.isLeft) {
      messenger.showSnackBar(SnackBar(
          content: Text(result.left?.userMessage ?? 'Could not update habit')));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(isReschedule
            ? 'Rescheduled to ${_formatScheduled(target)}'
            : 'Snoozed until ${_formatScheduled(target)}'),
      ));
    }
  }

  static String _formatScheduled(DateTime date) =>
      DateFormat('EEE, MMM d').format(date);

  void _deleteHabit(BuildContext context, WidgetRef ref) {
    final controller = ref.read(habitControllerProvider.notifier);
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
              controller.deleteHabit(habit.id);
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

/// One option in a Snooze/Reschedule quick-pick sheet.
///
/// A null [target] means the choice needs a date picker first (the "Custom…"
/// row).
class _ScheduleChoice {
  final String label;
  final DateTime? target;

  const _ScheduleChoice(this.label, this.target);
}

/// The quick "Snooze until" / "Reschedule to" options sheet.
class _QuickScheduleSheet extends StatelessWidget {
  final String title;
  final List<_ScheduleChoice> choices;

  const _QuickScheduleSheet({required this.title, required this.choices});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadiusTokens.sheetTop),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardFill(colorScheme, opacity: 0.9),
            border: Border(
              top: BorderSide(color: AppColors.hairline(colorScheme)),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacingTokens.lg),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacingTokens.sm),
              for (final choice in choices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    choice.label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  trailing: choice.target == null
                      ? Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, choice),
                ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A merged item combining a migrated Habit and its Task.
class _MigratedTaskItem {
  final Task task;
  final Habit habit;

  const _MigratedTaskItem({required this.task, required this.habit});
}

/// Card for a migrated habit shown as a "Recurring Task".
class _MigratedTaskCard extends StatelessWidget {
  final Task task;
  final Habit habit;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onUncomplete;

  const _MigratedTaskCard({
    required this.task,
    required this.habit,
    required this.isCompleted,
    required this.onTap,
    required this.onComplete,
    required this.onUncomplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryColor = habit.categoryColorFor(theme.brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadiusTokens.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacingTokens.md),
          decoration: BoxDecoration(
            color: AppColors.cardFill(colorScheme, opacity: 0.72),
            borderRadius: BorderRadius.circular(AppRadiusTokens.md),
            border: Border.all(color: AppColors.hairline(colorScheme)),
          ),
          child: Row(
            children: [
              // Category indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacingTokens.md),
              // Habit info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.repeat,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _scheduleLabel(task.schedule),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppSpacingTokens.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            habit.category,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Completion button
              _CompletionButton(
                isCompleted: isCompleted,
                onComplete: onComplete,
                onUncomplete: onUncomplete,
                accent: categoryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scheduleLabel(TaskSchedule schedule) {
    if (schedule is Recurring) {
      switch (schedule.rule.frequency) {
        case 'Daily':
          return 'Daily';
        case 'Weekdays':
          return 'Weekdays';
        case 'Weekends':
          return 'Weekends';
        case 'Custom':
          final days = schedule.rule.customWeekdays;
          if (days.isEmpty) return 'Custom';
          const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          return days.map((d) => names[d - 1]).join(', ');
        default:
          return 'Recurring';
      }
    }
    return 'Scheduled';
  }
}

/// Completion button for migrated task cards.
class _CompletionButton extends StatelessWidget {
  final bool isCompleted;
  final VoidCallback onComplete;
  final VoidCallback onUncomplete;
  final Color accent;

  const _CompletionButton({
    required this.isCompleted,
    required this.onComplete,
    required this.onUncomplete,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: AppAnimationTokens.fast,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: child,
      ),
      child: isCompleted
          ? IconButton(
              key: const ValueKey('completed'),
              icon: Icon(
                LucideIcons.checkCircle2,
                color: accent,
                size: 28,
              ),
              onPressed: onUncomplete,
              tooltip: 'Mark as incomplete',
            )
          : IconButton(
              key: const ValueKey('incomplete'),
              icon: Icon(
                LucideIcons.circle,
                color: colorScheme.onSurfaceVariant,
                size: 28,
              ),
              onPressed: onComplete,
              tooltip: 'Mark as complete',
            ),
    );
  }
}

/// Options sheet for a migrated task.
class _MigratedTaskOptionsSheet extends StatelessWidget {
  final Task task;
  final Habit habit;
  final VoidCallback onComplete;
  final VoidCallback onUncomplete;
  final VoidCallback onEditHabit;
  final VoidCallback onDelete;

  const _MigratedTaskOptionsSheet({
    required this.task,
    required this.habit,
    required this.onComplete,
    required this.onUncomplete,
    required this.onEditHabit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryColor = habit.categoryColorFor(theme.brightness);

    return _SheetScaffold(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacingTokens.lg,
          ),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium,
          ),
          subtitle: Text(
            'Recurring Task • ${habit.category}',
            style: AppTextStyles.bodySmall.copyWith(
              color: categoryColor,
            ),
          ),
        ),
        Divider(
          color: AppColors.hairline(colorScheme),
          height: 1,
        ),
        _option(
          context,
          icon: task.schedule is Recurring
              ? (task.schedule as Recurring).rule.frequency == 'Daily'
                  ? LucideIcons.sun
                  : LucideIcons.repeat
              : LucideIcons.calendar,
          label: 'View in Tasks',
          onTap: () => Navigator.pop(context),
        ),
        _option(
          context,
          icon: LucideIcons.pencil,
          label: 'Edit Habit',
          onTap: onEditHabit,
        ),
        Divider(
          color: AppColors.hairline(colorScheme),
          height: 1,
        ),
        _option(
          context,
          icon: LucideIcons.trash2,
          label: 'Delete Recurring Task',
          isDestructive: true,
          onTap: onDelete,
        ),
      ],
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final color =
        isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface;

    return ListTile(
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
      leading: Icon(icon, color: color),
      title:
          Text(label, style: AppTextStyles.titleMedium.copyWith(color: color)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
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
