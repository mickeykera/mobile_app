import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../controllers/journal_controller.dart';
import '../../domain/entities/journal_entry.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalControllerProvider);
    final controller = ref.read(journalControllerProvider.notifier);

    final morningEntry = state.morningEntry;
    final eveningEntry = state.eveningEntry;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.wb_sunny_outlined), text: 'Morning'),
                  Tab(icon: Icon(Icons.nights_stay_outlined), text: 'Evening'),
                ],
                onTap: (index) {
                  controller
                      .setSelectedType(index == 0 ? 'Morning' : 'Evening');
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _tabController.index == 0
                ? _buildMorningView(context, morningEntry)
                : _buildEveningView(context, eveningEntry),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEntrySheet(context),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New Entry'),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(journalControllerProvider);

    return SliverAppBar(
      expandedHeight: 168,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Reflection',
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.tertiaryContainer,
                colorScheme.secondaryContainer,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.tertiary.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                // The FlexibleSpaceBar title owns the bottom edge of this box;
                // anchoring the row there as well made them overlap.
                top: kToolbarHeight + 12,
                child: Row(
                  children: [
                    _buildDateSelector(context),
                    const Spacer(),
                    _buildMoodEnergyIndicators(context, state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(journalControllerProvider);
    final date = state.selectedDate ?? DateTime.now();

    return GestureDetector(
      onTap: () => _pickDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              date.formatRelative(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodEnergyIndicators(BuildContext context, JournalState state) {
    final entry = state.selectedType == 'Morning'
        ? state.morningEntry
        : state.eveningEntry;

    return Row(
      children: [
        if (entry?.moodRating != null) ...[
          _buildRatingIndicator(context, 'Mood', entry!.moodRating!,
              Icons.sentiment_satisfied_outlined),
          const SizedBox(width: 12),
        ],
        if (entry?.energyRating != null)
          _buildRatingIndicator(context, 'Energy', entry!.energyRating!,
              Icons.battery_charging_full_outlined),
      ],
    );
  }

  Widget _buildRatingIndicator(
      BuildContext context, String label, int rating, IconData icon) {
    final theme = Theme.of(context);
    final color = _getRatingColor(rating);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$rating/5',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Resolved through the app palette rather than raw `Colors.red`/`orange`/
  /// `green`, which ignored light and dark entirely. Each widget class keeps
  /// its own copy because there is no shared context above them.
  Color _getRatingColor(int rating) =>
      AppColors.ratingColor(Theme.of(context).colorScheme, rating);

  Widget _buildMorningView(BuildContext context, JournalEntry? entry) {
    final prompts = ref
        .read(journalControllerProvider.notifier)
        .getPromptsForType('Morning');

    if (entry == null || !entry.hasContent) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyPromptView(
          context,
          'Morning Intention',
          'Start your day with clarity',
          Icons.wb_sunny_outlined,
          Theme.of(context).colorScheme.tertiary,
          () => _showEntrySheet(context),
        ),
      );
    }

    return SliverList.separated(
      itemCount: prompts.length + 2,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildMoodEnergySelector(context, 'Morning', entry);
        }
        if (index == prompts.length + 1) {
          return _buildGratitudeSection(context, entry);
        }
        final prompt = prompts[index - 1];
        final response = entry.getResponse(prompt);
        return _buildPromptCard(context, prompt, response, isEditable: true);
      },
    );
  }

  Widget _buildEveningView(BuildContext context, JournalEntry? entry) {
    final prompts = ref
        .read(journalControllerProvider.notifier)
        .getPromptsForType('Evening');

    if (entry == null || !entry.hasContent) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyPromptView(
          context,
          'Evening Debrief',
          'Reflect on your day',
          Icons.nights_stay_outlined,
          Theme.of(context).colorScheme.primary,
          () => _showEntrySheet(context),
        ),
      );
    }

    return SliverList.separated(
      itemCount: prompts.length + 2,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildMoodEnergySelector(context, 'Evening', entry);
        }
        if (index == prompts.length + 1) {
          return _buildGratitudeSection(context, entry);
        }
        final prompt = prompts[index - 1];
        final response = entry.getResponse(prompt);
        return _buildPromptCard(context, prompt, response, isEditable: true);
      },
    );
  }

  Widget _buildEmptyPromptView(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 50, color: color),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacingTokens.sm),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            // No inline call to action: the "New Entry" FAB is already on
            // screen, and two buttons competed for the same job.
          ],
        ),
      ),
    );
  }

  Widget _buildMoodEnergySelector(
      BuildContext context, String type, JournalEntry entry) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling?',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildRatingSelector(
                      context,
                      'Mood',
                      entry.moodRating,
                      (r) => _updateMood(r),
                      Icons.sentiment_satisfied_outlined)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildRatingSelector(
                      context,
                      'Energy',
                      entry.energyRating,
                      (r) => _updateEnergy(r),
                      Icons.battery_charging_full_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSelector(BuildContext context, String label, int? rating,
      ValueChanged<int> onChanged, IconData icon) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final value = index + 1;
            final isSelected = rating == value;
            final color = _getRatingColor(value);
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSelected ? color : theme.colorScheme.outline),
                  ),
                  child: Center(
                    child: Text(
                      '$value',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? AppColors.onColorFor(color, theme.colorScheme)
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  void _updateMood(int rating) {
    final controller = ref.read(journalControllerProvider.notifier);
    final entry = controller.getCurrentEntry();
    if (entry != null) {
      controller.saveEntry(
        responses: entry.responses,
        moodRating: rating,
        energyRating: entry.energyRating,
        tags: entry.tags,
        gratitudeNote: entry.gratitudeNote,
      );
    }
  }

  void _updateEnergy(int rating) {
    final controller = ref.read(journalControllerProvider.notifier);
    final entry = controller.getCurrentEntry();
    if (entry != null) {
      controller.saveEntry(
        responses: entry.responses,
        moodRating: entry.moodRating,
        energyRating: rating,
        tags: entry.tags,
        gratitudeNote: entry.gratitudeNote,
      );
    }
  }

  Widget _buildPromptCard(BuildContext context, String prompt, String response,
      {bool isEditable = true}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (isEditable)
            TextField(
              controller: TextEditingController.fromValue(
                  TextEditingValue(text: response)),
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Tap to write your reflection...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) => _updateResponse(prompt, value),
            )
          else
            Text(
              response.isEmpty ? 'No response yet' : response,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: response.isEmpty
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : theme.colorScheme.onSurface,
                fontStyle:
                    response.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
        ],
      ),
    );
  }

  void _updateResponse(String prompt, String response) {
    final controller = ref.read(journalControllerProvider.notifier);
    final entry = controller.getCurrentEntry();
    if (entry != null) {
      final updatedResponses = Map<String, String>.from(entry.responses);
      if (response.trim().isEmpty) {
        updatedResponses.remove(prompt);
      } else {
        updatedResponses[prompt] = response;
      }
      controller.saveEntry(
        responses: updatedResponses,
        moodRating: entry.moodRating,
        energyRating: entry.energyRating,
        tags: entry.tags,
        gratitudeNote: entry.gratitudeNote,
      );
    }
  }

  Widget _buildGratitudeSection(BuildContext context, JournalEntry entry) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline,
                  color: theme.colorScheme.tertiary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Gratitude',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController.fromValue(
                TextEditingValue(text: entry.gratitudeNote ?? '')),
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'What are you grateful for?',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (value) => _updateGratitude(value),
          ),
        ],
      ),
    );
  }

  void _updateGratitude(String note) {
    final controller = ref.read(journalControllerProvider.notifier);
    final entry = controller.getCurrentEntry();
    if (entry != null) {
      controller.saveEntry(
        responses: entry.responses,
        moodRating: entry.moodRating,
        energyRating: entry.energyRating,
        tags: entry.tags,
        gratitudeNote: note,
      );
    }
  }

  void _showEntrySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EntrySheet(
        initialType: ref.read(journalControllerProvider).selectedType,
        initialDate:
            ref.read(journalControllerProvider).selectedDate ?? DateTime.now(),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final currentDate =
        ref.read(journalControllerProvider).selectedDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      ref.read(journalControllerProvider.notifier).setSelectedDate(date);
      // `setSelectedDate` resets `selectedType` back to Morning, so the tab
      // must follow it - otherwise the visible tab and the entry that
      // `saveEntry` writes to would disagree.
      _tabController.animateTo(0);
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

class _EntrySheet extends ConsumerStatefulWidget {
  final String initialType;
  final DateTime initialDate;

  const _EntrySheet({required this.initialType, required this.initialDate});

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late String _type;
  late DateTime _date;
  final _controllers = <String, TextEditingController>{};
  int? _moodRating;
  int? _energyRating;
  final _gratitudeController = TextEditingController();
  final _tagController = TextEditingController();
  final _tags = <String>[];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _date = widget.initialDate;

    final prompts =
        ref.read(journalControllerProvider.notifier).getPromptsForType(_type);
    for (final prompt in prompts) {
      _controllers[prompt] = TextEditingController();
    }

    final existingEntry = _type == 'Morning'
        ? ref.read(morningEntryProvider)
        : ref.read(eveningEntryProvider);

    if (existingEntry != null) {
      for (final prompt in prompts) {
        _controllers[prompt]?.text = existingEntry.getResponse(prompt);
      }
      _moodRating = existingEntry.moodRating;
      _energyRating = existingEntry.energyRating;
      _gratitudeController.text = existingEntry.gratitudeNote ?? '';
      if (existingEntry.tags != null) {
        _tags.addAll(existingEntry.tags!);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _gratitudeController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prompts =
        ref.read(journalControllerProvider.notifier).getPromptsForType(_type);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _type == 'Morning' ? 'Morning Intention' : 'Evening Debrief',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTypeSelector(),
            const SizedBox(height: 16),
            _buildDateSelector(),
            const SizedBox(height: 24),
            _buildMoodEnergySelector(),
            const SizedBox(height: 24),
            ...prompts.map((prompt) => _buildPromptField(prompt)),
            const SizedBox(height: 16),
            _buildGratitudeField(),
            const SizedBox(height: 16),
            _buildTagsField(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saveEntry,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Save Entry'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'Morning',
                  label: Text('Morning'),
                  icon: Icon(Icons.wb_sunny_outlined)),
              ButtonSegment(
                  value: 'Evening',
                  label: Text('Evening'),
                  icon: Icon(Icons.nights_stay_outlined)),
            ],
            selected: {_type},
            onSelectionChanged: (selection) {
              setState(() {
                _type = selection.first;
                _controllers.clear();
                final prompts = ref
                    .read(journalControllerProvider.notifier)
                    .getPromptsForType(_type);
                for (final prompt in prompts) {
                  _controllers[prompt] = TextEditingController();
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final theme = Theme.of(context);

    return InkWell(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              _date.formatRelative(),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodEnergySelector() {
    return Row(
      children: [
        Expanded(
            child: _buildRatingSelector(
                'Mood',
                _moodRating,
                (r) => setState(() => _moodRating = r),
                Icons.sentiment_satisfied_outlined)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildRatingSelector(
                'Energy',
                _energyRating,
                (r) => setState(() => _energyRating = r),
                Icons.battery_charging_full_outlined)),
      ],
    );
  }

  Widget _buildRatingSelector(
      String label, int? rating, ValueChanged<int> onChanged, IconData icon) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final value = index + 1;
            final isSelected = rating == value;
            final color = _getRatingColor(value);
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSelected ? color : theme.colorScheme.outline),
                  ),
                  child: Center(
                    child: Text(
                      '$value',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? AppColors.onColorFor(color, theme.colorScheme)
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Resolved through the app palette rather than raw `Colors.red`/`orange`/
  /// `green`, which ignored light and dark entirely. Each widget class keeps
  /// its own copy because there is no shared context above them.
  Color _getRatingColor(int rating) =>
      AppColors.ratingColor(Theme.of(context).colorScheme, rating);

  Widget _buildPromptField(String prompt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[prompt],
        maxLines: 3,
        maxLength: 1000,
        decoration: InputDecoration(
          labelText: prompt,
          hintText: 'Your reflection...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildGratitudeField() {
    final theme = Theme.of(context);

    return TextField(
      controller: _gratitudeController,
      maxLines: 3,
      maxLength: 500,
      decoration: InputDecoration(
        labelText: 'Gratitude',
        hintText: 'What are you grateful for?',
        prefixIcon:
            Icon(Icons.favorite_outline, color: theme.colorScheme.tertiary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildTagsField() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map((tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                )),
            ActionChip(
              label: const Text('Add Tag'),
              avatar: const Icon(Icons.add, size: 16),
              onPressed: _addTag,
            ),
          ],
        ),
      ],
    );
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() => _date = date);
    }
  }

  void _saveEntry() {
    final responses = <String, String>{};
    for (final entry in _controllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        responses[entry.key] = entry.value.text.trim();
      }
    }

    final result = ref.read(journalControllerProvider.notifier).saveEntry(
          responses: responses,
          moodRating: _moodRating,
          energyRating: _energyRating,
          tags: _tags.isEmpty ? null : _tags,
          gratitudeNote: _gratitudeController.text.trim().isEmpty
              ? null
              : _gratitudeController.text.trim(),
        );

    result.then((r) {
      if (r.isRight && mounted) {
        Navigator.pop(context);
      }
    });
  }
}
