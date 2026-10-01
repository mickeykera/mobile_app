import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/journal_controller.dart';
import '../../domain/entities/journal_entry.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/glass_card.dart';
import '../../../../app/widgets/glow_button.dart';
import '../../../../app/widgets/pill_chip.dart';
import '../../../../app/widgets/pressable.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  /// 0 = Morning, 1 = Evening.
  ///
  /// An index rather than a `TabController`: the Morning/Evening choice is a
  /// two-way toggle, not a tab strip, and driving it from state lets the content
  /// cross-fade through an `AnimatedSwitcher` instead of the `TabBar`'s
  /// controller-driven swap. `setSelectedType` on the controller is unchanged,
  /// so persistence is unaffected.
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalControllerProvider);
    final entry = _selected == 0 ? state.morningEntry : state.eveningEntry;

    return Scaffold(
      floatingActionButton: GlowButton(
        label: 'New Entry',
        icon: Icons.edit_rounded,
        accent: AppColors.radiantViolet,
        height: 52,
        onPressed: () => _showEntrySheet(context),
      ),
      body: CustomScrollView(
        slivers: [
          _buildHero(context, state),
          _buildTypeToggle(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacingTokens.gutter,
              AppSpacingTokens.md,
              AppSpacingTokens.gutter,
              120,
            ),
            // Cross-fade between Morning and Evening. `layoutBuilder` keeps the
            // outgoing and incoming children stacked during the transition
            // instead of resizing to the tallest one, so the swap does not
            // collapse the whole page halfway through.
            sliver: SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: AppAnimationTokens.medium,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, if (current != null) current],
                ),
                child: KeyedSubtree(
                  key: ValueKey(_selected),
                  child: _buildJournalBody(context, entry),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The hero: a gradient glass panel carrying the title, the date picker and
  /// whatever mood/energy the current entry already carries.
  ///
  /// Fixed-height rather than a collapsing `FlexibleSpaceBar`. The mood/energy
  /// pills change width as they appear and disappear, and a collapsing title bar
  /// re-anchors its title every frame, which made the two drift into each other.
  Widget _buildHero(BuildContext context, JournalState state) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacingTokens.gutter,
          kToolbarHeight + AppSpacingTokens.sm,
          AppSpacingTokens.gutter,
          0,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadiusTokens.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppGradients.journalHeader(colorScheme),
                borderRadius: BorderRadius.circular(AppRadiusTokens.xl),
                border: Border.all(color: AppColors.hairline(colorScheme)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacingTokens.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ShaderMask(
                          shaderCallback:
                              AppGradients.action(AppColors.radiantViolet)
                                  .createShader,
                          child: Text(
                            'Reflection',
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      _buildDateSelector(context, state),
                    ],
                  ),
                  const SizedBox(height: AppSpacingTokens.md),
                  // Reserved height so the pills fading in and out never push
                  // the panel's own edges around.
                  SizedBox(
                    height: 34,
                    child: AnimatedSwitcher(
                      duration: AppAnimationTokens.medium,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          axis: Axis.horizontal,
                          sizeFactor: animation,
                          child: child,
                        ),
                      ),
                      child: _buildMoodEnergyIndicators(context, state),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, JournalState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = state.selectedDate ?? DateTime.now();

    return GlassPill(
      label: date.formatRelative(),
      icon: Icons.calendar_today_outlined,
      selected: true,
      accent: colorScheme.primary,
      onTap: () => _pickDate(context),
    );
  }

  Widget _buildTypeToggle(BuildContext context) {
    const types = ['Morning', 'Evening'];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacingTokens.md),
        child: Center(
          child: GlassPillRow(
            pills: [
              for (var i = 0; i < types.length; i++)
                GlassPill(
                  label: types[i],
                  selected: _selected == i,
                  icon: i == 0
                      ? Icons.wb_sunny_outlined
                      : Icons.nights_stay_outlined,
                  // Morning leans warm, Evening leans violet: the pill colour
                  // tells you which half of the day you are in before you read
                  // the label.
                  accent: i == 0
                      ? AppColors.coralOrange
                      : AppColors.radiantViolet,
                  onTap: () => _selectType(i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectType(int index) {
    if (_selected == index) return;
    setState(() => _selected = index);
    ref
        .read(journalControllerProvider.notifier)
        .setSelectedType(index == 0 ? 'Morning' : 'Evening');
  }

  Widget _buildMoodEnergyIndicators(BuildContext context, JournalState state) {
    final entry = state.selectedType == 'Morning'
        ? state.morningEntry
        : state.eveningEntry;

    final indicators = <Widget>[
      if (entry?.moodRating != null)
        _RatingIndicator(
          label: 'Mood',
          rating: entry!.moodRating!,
          icon: Icons.sentiment_satisfied_outlined,
        ),
      if (entry?.energyRating != null) ...[
        if (entry?.moodRating != null) const SizedBox(width: AppSpacingTokens.sm),
        _RatingIndicator(
          label: 'Energy',
          rating: entry!.energyRating!,
          icon: Icons.battery_charging_full_rounded,
        ),
      ],
    ];

    if (indicators.isEmpty) {
      return Align(
        key: const ValueKey('no-ratings'),
        alignment: Alignment.centerLeft,
        child: Text(
          'No check-in yet today',
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Keyed on both ratings so switching from 3/5 to 4/5 cross-fades rather than
    // swapping the digits in place.
    return Row(
      key: ValueKey('${entry?.moodRating}-${entry?.energyRating}'),
      mainAxisSize: MainAxisSize.min,
      children: indicators,
    );
  }

  Widget _buildJournalBody(BuildContext context, JournalEntry? entry) {
    final prompts = ref
        .read(journalControllerProvider.notifier)
        .getPromptsForType(_selected == 0 ? 'Morning' : 'Evening');

    if (entry == null || !entry.hasContent) {
      return _buildEmptyPromptView(
        context,
        _selected == 0 ? 'Morning Intention' : 'Evening Debrief',
        _selected == 0 ? 'Start your day with clarity' : 'Reflect on your day',
        _selected == 0
            ? Icons.wb_sunny_outlined
            : Icons.nights_stay_outlined,
        _selected == 0 ? AppColors.coralOrange : AppColors.radiantViolet,
      );
    }

    return Column(
      children: [
        _JournalPromptCard(
          // A stable key per slot: without it, Flutter reuses the state of the
          // previous card when the list changes length, so a typed response
          // would reappear under a different prompt. Keyed on the entry id, not
          // its hashCode - `saveEntry` returns a new object every keystroke, and
          // a changing key would tear down the field being typed into.
          key: ValueKey('mood-$_selected-${entry.id}'),
          prompt: 'How are you feeling?',
          icon: Icons.favorite_outline_rounded,
          accent: AppColors.radiantViolet,
          readOnlyText: entry.moodRating == null && entry.energyRating == null
              ? null
              : 'Mood ${entry.moodRating ?? '–'}/5   ·   '
                  'Energy ${entry.energyRating ?? '–'}/5',
          child: Row(
            children: [
              Expanded(
                child: _RatingScale(
                  label: 'Mood',
                  icon: Icons.sentiment_satisfied_outlined,
                  rating: entry.moodRating,
                  onChanged: _updateMood,
                ),
              ),
              const SizedBox(width: AppSpacingTokens.md),
              Expanded(
                child: _RatingScale(
                  label: 'Energy',
                  icon: Icons.battery_charging_full_rounded,
                  rating: entry.energyRating,
                  onChanged: _updateEnergy,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: AppAnimationTokens.slow)
            .slideY(begin: 0.06, end: 0),
        for (var i = 0; i < prompts.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacingTokens.md),
            child: _JournalPromptCard(
              key: ValueKey('prompt-$_selected-$i-${prompts[i]}'),
              prompt: prompts[i],
              icon: _promptIcon(prompts[i]),
              accent: _accentForPrompt(prompts[i]),
              initialText: entry.getResponse(prompts[i]),
              onChanged: (value) => _updateResponse(prompts[i], value),
            )
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: (i + 1) * 45),
                  duration: AppAnimationTokens.slow,
                )
                .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
          ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacingTokens.md),
          child: _JournalPromptCard(
            key: ValueKey('gratitude-$_selected-${entry.id}'),
            prompt: 'Gratitude',
            icon: Icons.favorite_outline_rounded,
            accent: AppColors.coralOrange,
            initialText: entry.gratitudeNote ?? '',
            hintText: 'What are you grateful for?',
            maxLength: 500,
            maxLines: 3,
            onChanged: _updateGratitude,
          )
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: (prompts.length + 1) * 45),
                duration: AppAnimationTokens.slow,
              )
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
        ),
      ],
    );
  }

  IconData _promptIcon(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('gratitude')) return Icons.volunteer_activism_outlined;
    if (lower.contains('went well') || lower.contains('win')) {
      return Icons.trending_up_rounded;
    }
    if (lower.contains('learn') || lower.contains('lesson')) {
      return Icons.lightbulb_outline_rounded;
    }
    if (lower.contains('tomorrow') || lower.contains('next')) {
      return Icons.arrow_forward_rounded;
    }
    return Icons.edit_note_rounded;
  }

  /// Prompt cards are tinted, not all the same colour. A wall of identical grey
  /// cards makes a long journal read as a form rather than as a page; giving each
  /// prompt an accent gives the eye somewhere to rest.
  Color _accentForPrompt(String prompt) {
    const accents = [
      AppColors.neonCyan,
      AppColors.radiantViolet,
      AppColors.coralOrange,
      AppColors.emerald,
    ];
    return accents[prompt.hashCode.abs() % accents.length];
  }

  Widget _buildEmptyPromptView(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: AuroraBackdrop(
                      accentA: color,
                      accentB: AppColors.radiantViolet,
                      opacity: 0.2,
                    ),
                  ),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icon, size: 38, color: color),
                  ),
                ],
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: AppSpacingTokens.lg),
            Text(
              title,
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacingTokens.xs + 2),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            // No inline call to action: the "New Entry" button is already on
            // screen, and two buttons competed for the same job.
          ],
        ),
      ),
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
      // `setSelectedDate` resets `selectedType` back to Morning, so the visible
      // toggle has to follow it - otherwise the highlighted half of the day and
      // the entry that `saveEntry` writes to would disagree.
      if (_selected != 0) setState(() => _selected = 0);
    }
  }
}

/// A compact "Mood 4/5" pill for the hero panel.
class _RatingIndicator extends StatelessWidget {
  final String label;
  final int rating;
  final IconData icon;

  const _RatingIndicator({
    required this.label,
    required this.rating,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.ratingScaleColor(
      Theme.of(context).colorScheme,
      rating,
    );

    return Semantics(
      container: true,
      label: '$label $rating out of 5',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadiusTokens.full),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              '$label $rating/5',
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 1-5 check-in scale.
///
/// Each step carries its own colour, so the row reads as a gradient the user
/// chooses a point on rather than five interchangeable buttons. The selected
/// step lights, grows and glows; the rest stay as tinted wells so the full range
/// remains legible.
class _RatingScale extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? rating;
  final ValueChanged<int> onChanged;

  const _RatingScale({
    required this.label,
    required this.icon,
    required this.rating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Row(
          children: List.generate(5, (index) {
            final value = index + 1;
            return Expanded(
              child: _RatingStep(
                value: value,
                color: AppColors.ratingScaleColor(colorScheme, value),
                selected: rating == value,
                onTap: () => onChanged(value),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _RatingStep extends StatelessWidget {
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RatingStep({
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      // `container: true` matters here: `Pressable` is asked not to emit a node
      // of its own, so without it this annotation has nothing to attach to and
      // the label is silently dropped from the semantics tree.
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      // The digit below is redundant once the node says "4 out of 5".
      excludeSemantics: true,
      label: '$value out of 5',
      child: Pressable(
        onTap: onTap,
        // A slightly deeper press than the default: five of these sit side by
        // side, and a 0.96 squash was too small to feel like a deliberate hit.
        pressScale: 0.9,
        semanticButton: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedContainer(
            duration: AppAnimationTokens.medium,
            curve: Curves.easeOutCubic,
            // Grows on selection so the chosen step is identifiable by shape
            // as well as by colour.
            height: selected ? 38 : 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 1 : 0.12),
              borderRadius: BorderRadius.circular(AppRadiusTokens.sm),
              border: Border.all(
                color: color.withValues(alpha: selected ? 1 : 0.3),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: AppAnimationTokens.medium,
                style: AppTextStyles.labelLarge.copyWith(
                  color: selected
                      ? AppColors.onColorFor(color, colorScheme)
                      : color,
                  fontWeight: FontWeight.w700,
                ),
                child: Text('$value'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One prompt: the question on top, a dark borderless writing area below.
///
/// Statefully owns its [TextEditingController]. The previous version built a
/// controller inside `build`, which meant every keystroke - each one saving and
/// rebuilding the screen - threw the controller away and made a new one from the
/// stored text. That reset the caret and selection mid-sentence and broke
/// autocorrect and IME composition outright.
class _JournalPromptCard extends StatefulWidget {
  final String prompt;
  final IconData icon;
  final Color accent;
  final String initialText;
  final String hintText;
  final ValueChanged<String>? onChanged;

  /// When set, the card shows this instead of a text field. Used by the mood
  /// card, which embeds a rating scale rather than a paragraph.
  final String? readOnlyText;
  final Widget? child;
  final int maxLength;
  final int maxLines;

  const _JournalPromptCard({
    super.key,
    required this.prompt,
    required this.icon,
    required this.accent,
    this.initialText = '',
    this.hintText = 'Tap to write your reflection…',
    this.onChanged,
    this.readOnlyText,
    this.child,
    this.maxLength = 1000,
    this.maxLines = 4,
  });

  @override
  State<_JournalPromptCard> createState() => _JournalPromptCardState();
}

class _JournalPromptCardState extends State<_JournalPromptCard> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_JournalPromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt an externally changed value only when the user is not in the field.
    // Otherwise switching dates mid-sentence would yank the text out from under
    // the caret.
    if (widget.initialText == _controller.text) return;
    if (_focus.hasFocus) return;
    _controller.text = widget.initialText;
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Lift the accent while writing. The card responds to being touched, which
    // is the only place a journal gives you continuous feedback that the words
    // are going somewhere.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final focused = _focus.hasFocus;

    return GlassCard(
      tint: widget.accent,
      tintOpacity: focused ? 0.14 : 0.07,
      border: Border.all(
        color: focused
            ? widget.accent.withValues(alpha: 0.5)
            : AppColors.hairline(colorScheme),
        width: focused ? 1.5 : 1,
      ),
      padding: const EdgeInsets.all(AppSpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadiusTokens.sm),
                ),
                child: Icon(widget.icon, size: 16, color: widget.accent),
              ),
              const SizedBox(width: AppSpacingTokens.sm + 2),
              Expanded(
                child: Text(
                  widget.prompt,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacingTokens.md),
          if (widget.child != null)
            widget.child!
          else ...[
            if (widget.readOnlyText != null)
              Text(
                widget.readOnlyText!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              // A darker inset well with no border: the writing surface should
              // read as a hole cut into the card, not as another control on top
              // of it.
              Container(
                decoration: BoxDecoration(
                  color: AppColors.insetFill(colorScheme, opacity: 0.55),
                  borderRadius: BorderRadius.circular(AppRadiusTokens.input),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacingTokens.md,
                  vertical: AppSpacingTokens.sm + 4,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  maxLines: widget.maxLines,
                  minLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  cursorColor: widget.accent,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    // No counter: it counts down on every keystroke and pushes
                    // the layout around, which is exactly what a journal wants
                    // to feel like it does not do.
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
          ],
        ],
      ),
    );
  }
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

    return Padding(
      // The sheet grows with the keyboard. Padding the outer container and
      // scrolling the inner body is what lets the save button stay reachable
      // while a field at the bottom has focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadiusTokens.sheetTop),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardFill(theme.colorScheme, opacity: 0.92),
              border: Border(
                top: BorderSide(color: AppColors.hairline(theme.colorScheme)),
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacingTokens.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _type == 'Morning'
                                ? 'Morning Intention'
                                : 'Evening Debrief',
                            style: AppTextStyles.headlineSmall,
                          ),
                        ),
                        GlowIconButton(
                          icon: Icons.close_rounded,
                          accent: theme.colorScheme.onSurfaceVariant,
                          size: 40,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacingTokens.md),
                    _buildTypeSelector(),
                    const SizedBox(height: AppSpacingTokens.md),
                    _buildDateSelector(),
                    const SizedBox(height: AppSpacingTokens.lg),
                    _buildMoodEnergySelector(),
                    const SizedBox(height: AppSpacingTokens.lg),
                    ...prompts.map(_buildPromptField),
                    _buildGratitudeField(),
                    const SizedBox(height: AppSpacingTokens.md),
                    _buildTagsField(),
                    const SizedBox(height: AppSpacingTokens.lg),
                    GlowButton(
                      label: 'Save Entry',
                      icon: Icons.check_rounded,
                      accent: AppColors.radiantViolet,
                      width: double.infinity,
                      onPressed: _saveEntry,
                    ),
                    const SizedBox(height: AppSpacingTokens.sm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    const types = ['Morning', 'Evening'];

    return Row(
      children: [
        for (var i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacingTokens.sm),
          Expanded(
            child: GlassPill(
              label: types[i],
              selected: _type == types[i],
              icon: i == 0
                  ? Icons.wb_sunny_outlined
                  : Icons.nights_stay_outlined,
              accent:
                  i == 0 ? AppColors.coralOrange : AppColors.radiantViolet,
              onTap: () => _selectType(types[i]),
            ),
          ),
        ],
      ],
    );
  }

  void _selectType(String type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      // Dispose the previous fields' controllers before dropping them: they are
      // owned here, and the old code just cleared the map, leaking one
      // controller per prompt on every type switch.
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _moodRating = null;
      _energyRating = null;
      _gratitudeController.clear();

      final prompts =
          ref.read(journalControllerProvider.notifier).getPromptsForType(_type);
      for (final prompt in prompts) {
        _controllers[prompt] = TextEditingController();
      }
    });
  }

  Widget _buildDateSelector() {
    final theme = Theme.of(context);

    return GlassPill(
      label: _date.formatRelative(),
      icon: Icons.calendar_today_outlined,
      selected: true,
      accent: theme.colorScheme.primary,
      onTap: _pickDate,
    );
  }

  Widget _buildMoodEnergySelector() {
    return Row(
      children: [
        Expanded(
          child: _RatingScale(
            label: 'Mood',
            icon: Icons.sentiment_satisfied_outlined,
            rating: _moodRating,
            onChanged: (r) => setState(() => _moodRating = r),
          ),
        ),
        const SizedBox(width: AppSpacingTokens.md),
        Expanded(
          child: _RatingScale(
            label: 'Energy',
            icon: Icons.battery_charging_full_rounded,
            rating: _energyRating,
            onChanged: (r) => setState(() => _energyRating = r),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptField(String prompt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt, style: AppTextStyles.labelLarge),
          const SizedBox(height: AppSpacingTokens.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.insetFill(
                Theme.of(context).colorScheme,
                opacity: 0.55,
              ),
              borderRadius: BorderRadius.circular(AppRadiusTokens.input),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacingTokens.md,
              vertical: AppSpacingTokens.sm + 4,
            ),
            child: TextField(
              controller: _controllers[prompt],
              maxLines: 3,
              minLines: 3,
                  maxLength: 1000,
                  cursorColor: AppColors.radiantViolet,
                  style: AppTextStyles.bodyLarge.copyWith(height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Your reflection…',
                    counterText: '',
                    border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGratitudeField() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.favorite_outline_rounded,
              size: 16,
              color: AppColors.coralOrange,
            ),
            SizedBox(width: 6),
            Text('Gratitude', style: AppTextStyles.labelLarge),
          ],
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.insetFill(theme.colorScheme, opacity: 0.55),
            borderRadius: BorderRadius.circular(AppRadiusTokens.input),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacingTokens.md,
            vertical: AppSpacingTokens.sm + 4,
          ),
          child: TextField(
            controller: _gratitudeController,            maxLines: 3,
            minLines: 3,
            maxLength: 500,
            cursorColor: AppColors.coralOrange,
            style: AppTextStyles.bodyLarge.copyWith(height: 1.5),
            decoration: const InputDecoration(
              hintText: 'What are you grateful for?',
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsField() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tags', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacingTokens.sm),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.insetFill(theme.colorScheme, opacity: 0.55),
                  borderRadius: BorderRadius.circular(AppRadiusTokens.input),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacingTokens.md),
                child: TextField(
                  controller: _tagController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTag(),
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: 'work, health, family…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacingTokens.sm),
            GlowIconButton(
              icon: Icons.add_rounded,
              accent: theme.colorScheme.primary,
              size: 48,
              tooltip: 'Add tag',
              onPressed: _addTag,
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacingTokens.sm + 2),
          Wrap(
            spacing: AppSpacingTokens.sm,
            runSpacing: AppSpacingTokens.sm,
            children: [
              for (final tag in _tags)
                GlassPill(
                  label: tag,
                  selected: true,
                  accent: AppColors.emerald,
                  icon: Icons.close_rounded,
                  onTap: () => setState(() => _tags.remove(tag)),
                ),
            ],
          ),
        ],
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
