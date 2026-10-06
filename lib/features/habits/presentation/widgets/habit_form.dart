import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_clock.dart';
import '../../domain/entities/habit.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/glow_button.dart';
import '../../../../app/widgets/pill_chip.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/category_type.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class HabitForm extends ConsumerStatefulWidget {
  final Habit? habit;

  const HabitForm({super.key, this.habit});

  @override
  ConsumerState<HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends ConsumerState<HabitForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cueController = TextEditingController();

  String _category = CategoryType.mind.title;
  String _frequency = AppConstants.frequencyDaily;
  List<int> _customWeekdays = [];
  String _timeOfDay = AppConstants.timeOfDayMorning;
  int _targetCount = 1;
  int _targetDurationMinutes = 0;
  int _sortOrder = 0;

  @override
  void initState() {
    super.initState();
    if (widget.habit != null) {
      _populateFields(widget.habit!);
    }
  }

  void _populateFields(Habit habit) {
    _titleController.text = habit.title;
    _descriptionController.text = habit.description;
    _cueController.text = habit.cue;
    _category = habit.category;
    _frequency = habit.frequency;
    _customWeekdays = List.from(habit.customWeekdays);
    _timeOfDay = habit.timeOfDay;
    _targetCount = habit.targetCount;
    _targetDurationMinutes = habit.targetDuration.inMinutes;
    _sortOrder = habit.sortOrder;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.habit != null;

    // The sheet is opened with a transparent background, so this surface is what
    // the user actually sees. Without it the list behind bled straight through
    // and the form labels collided with the habit rows.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadiusTokens.sheetTop),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            // Translucent, like every other sheet in the app. An opaque
            // `colorScheme.surface` here made this one sheet read as a
            // different app from the rest of the product.
            color: AppColors.cardFill(theme.colorScheme, opacity: 0.94),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadiusTokens.sheetTop),
            ),
            border: Border(
              top: BorderSide(color: AppColors.hairline(theme.colorScheme)),
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  AppSpacingTokens.lg,
              left: AppSpacingTokens.lg,
              right: AppSpacingTokens.lg,
              top: AppSpacingTokens.sm,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle, as every market sheet has.
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin:
                          const EdgeInsets.only(bottom: AppSpacingTokens.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(AppRadiusTokens.full),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        isEditing ? 'Edit Habit' : 'New Habit',
                        style: AppTextStyles.headlineSmall
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      GlowIconButton(
                        icon: LucideIcons.x,
                        accent: theme.colorScheme.onSurfaceVariant,
                        size: 40,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacingTokens.lg),

                  _buildTitleField(),
                  const SizedBox(height: AppSpacingTokens.md),

                  _buildDescriptionField(),
                  const SizedBox(height: AppSpacingTokens.md),

                  _buildCategorySelector(),
                  const SizedBox(height: AppSpacingTokens.md),

                  _buildCueField(),
                  const SizedBox(height: AppSpacingTokens.md),

                  _buildFrequencySelector(),
                  const SizedBox(height: AppSpacingTokens.md),

                  if (_frequency == AppConstants.frequencyCustom)
                    _buildCustomWeekdaysSelector(),
                  if (_frequency == AppConstants.frequencyCustom)
                    const SizedBox(height: AppSpacingTokens.md),

                  _buildTimeOfDaySelector(),
                  const SizedBox(height: AppSpacingTokens.md),

                  _buildTargetFields(),
                  const SizedBox(height: AppSpacingTokens.lg),

                  _buildSaveButton(),
                  const SizedBox(height: AppSpacingTokens.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(
        labelText: 'Habit Title',
        hintText: 'e.g., Morning meditation, Daily exercise',
        prefixIcon: Icon(LucideIcons.flag),
      ),
      // `maxLength` was only validated, never declared, so the field never
      // enforced or displayed the 100-character limit it claimed to have.
      maxLength: 100,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a habit title';
        }
        if (value.trim().length > 100) {
          return 'Title must be less than 100 characters';
        }
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description (optional)',
        hintText: 'Why is this habit important to you?',
        prefixIcon: Icon(LucideIcons.fileText),
        alignLabelWithHint: true,
      ),
      maxLines: 3,
      maxLength: 500,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildCategorySelector() {
    return _buildChipGroup(
      label: 'Category',
      options: AppConstants.habitCategories,
      selected: _category,
      accentFor: _getCategoryColor,
      iconFor: _getCategoryIcon,
      onSelected: (category) => setState(() => _category = category),
    );
  }

  Widget _buildCueField() {
    return TextFormField(
      controller: _cueController,
      decoration: const InputDecoration(
        labelText: 'Cue / Trigger (optional)',
        hintText: 'e.g., After brushing teeth, When I open my laptop',
        prefixIcon: Icon(LucideIcons.lightbulb),
      ),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildFrequencySelector() {
    return _buildChipGroup(
      label: 'Frequency',
      options: AppConstants.frequencies,
      selected: _frequency,
      accentFor: (_) => AppColors.accentPrimary,
      onSelected: (frequency) => setState(() {
        _frequency = frequency;
        if (frequency != AppConstants.frequencyCustom) {
          _customWeekdays = [];
        }
      }),
    );
  }

  Widget _buildCustomWeekdaysSelector() {
    final theme = Theme.of(context);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Days',
          style: AppTextStyles.labelLarge.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: List.generate(7, (index) {
            final dayNum = index + 1;
            final isSelected = _customWeekdays.contains(dayNum);
            return GlassPill(
              label: days[index],
              selected: isSelected,
              accent: AppColors.accentDeep,
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _customWeekdays.remove(dayNum);
                  } else {
                    _customWeekdays.add(dayNum);
                  }
                });
              },
            );
          }),
        ),
        if (_customWeekdays.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacingTokens.xs),
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 14,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pick at least one day',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTimeOfDaySelector() {
    return _buildChipGroup(
      label: 'Time of Day',
      options: AppConstants.timeOfDayTags,
      selected: _timeOfDay,
      // Morning is warm, afternoon neutral, evening violet: the accent carries
      // the meaning of the slot without having to read the label.
      accentFor: (time) => switch (time) {
        'Morning' => AppColors.accentWarm,
        'Afternoon' => AppColors.accentPrimary,
        'Evening' => AppColors.accentDeep,
        _ => AppColors.accentPrimary,
      },
      iconFor: _getTimeIcon,
      onSelected: (time) => setState(() => _timeOfDay = time),
    );
  }

  /// The shared chip row behind category, frequency and time of day.
  ///
  /// These were three near-identical `FilterChip` `Wrap`s. `FilterChip` also
  /// draws its own checkmark, which meant a selected option showed a tick *and*
  /// a colour change, and the tick could not be tinted to match on the dark
  /// theme.
  Widget _buildChipGroup({
    required String label,
    required List<String> options,
    required String selected,
    required Color Function(String) accentFor,
    required void Function(String) onSelected,
    IconData? Function(String)? iconFor,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: [
            for (final option in options)
              GlassPill(
                label: option,
                icon: iconFor?.call(option),
                selected: selected == option,
                accent: accentFor(option),
                onTap: () => onSelected(option),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            initialValue: _targetCount.toString(),
            decoration: const InputDecoration(
              labelText: 'Target Count',
              hintText: '1',
              prefixIcon: Icon(LucideIcons.listOrdered),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => _targetCount = int.tryParse(value) ?? 1,
            validator: (value) {
              final num = int.tryParse(value ?? '');
              if (num == null || num < 1) return 'Must be at least 1';
              return null;
            },
          ),
        ),
        const SizedBox(width: AppSpacingTokens.md),
        Expanded(
          child: TextFormField(
            initialValue: _targetDurationMinutes.toString(),
            decoration: const InputDecoration(
              labelText: 'Duration (min)',
              hintText: '0',
              prefixIcon: Icon(LucideIcons.timer),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) =>
                _targetDurationMinutes = int.tryParse(value) ?? 0,
            validator: (value) {
              final num = int.tryParse(value ?? '');
              if (num == null || num < 0) return 'Must be 0 or more';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final isEditing = widget.habit != null;

    return GlowButton(
      label: isEditing ? 'Save Changes' : 'Create Habit',
      icon: isEditing ? LucideIcons.save : LucideIcons.plus,
      accent: _getCategoryColor(_category),
      width: double.infinity,
      onPressed: _save,
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_frequency == AppConstants.frequencyCustom && _customWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please select at least one day for custom frequency')),
      );
      return;
    }

    final habit = widget.habit?.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _category,
          frequency: _frequency,
          customWeekdays: _customWeekdays,
          timeOfDay: _timeOfDay,
          targetCount: _targetCount,
          targetDuration: Duration(minutes: _targetDurationMinutes),
          cue: _cueController.text.trim(),
          sortOrder: _sortOrder,
          updatedAt: AppClock.now(),
        ) ??
        Habit.create(
          title: _titleController.text.trim(),
          category: _category,
          description: _descriptionController.text.trim(),
          frequency: _frequency,
          customWeekdays: _customWeekdays,
          timeOfDay: _timeOfDay,
          targetCount: _targetCount,
          targetDuration: Duration(minutes: _targetDurationMinutes),
          cue: _cueController.text.trim(),
          sortOrder: _sortOrder,
        );

    Navigator.of(context).pop(habit);
  }

  Color _getCategoryColor(String category) =>
      CategoryType.fromString(category).color;

  IconData _getCategoryIcon(String category) =>
      CategoryType.tryFromString(category)?.icon ?? LucideIcons.star;

  IconData _getTimeIcon(String time) {
    switch (time) {
      case 'Morning':
        return LucideIcons.sun;
      case 'Afternoon':
        return LucideIcons.sun;
      case 'Evening':
        return LucideIcons.moon;
      default:
        return LucideIcons.clock;
    }
  }
}
