import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/habit.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/category_type.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadiusTokens.xxl),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(context).viewInsets.bottom + AppSpacingTokens.lg,
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
                  margin: const EdgeInsets.only(bottom: AppSpacingTokens.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadiusTokens.full),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    isEditing ? 'Edit Habit' : 'New Habit',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
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
            ],
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
        prefixIcon: Icon(Icons.flag_outlined),
      ),
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
        prefixIcon: Icon(Icons.description_outlined),
        alignLabelWithHint: true,
      ),
      maxLines: 3,
      maxLength: 500,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildCategorySelector() {
    final theme = Theme.of(context);
    final categories = AppConstants.habitCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: categories.map((category) {
            final isSelected = _category == category;
            final color = _getCategoryColor(category);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getCategoryIcon(category), size: 16),
                  const SizedBox(width: 6),
                  Text(category),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _category = category),
              selectedColor: color.withValues(alpha: 0.2),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                  color: isSelected ? color : theme.colorScheme.outline),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadiusTokens.full)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCueField() {
    return TextFormField(
      controller: _cueController,
      decoration: const InputDecoration(
        labelText: 'Cue / Trigger (optional)',
        hintText: 'e.g., After brushing teeth, When I open my laptop',
        prefixIcon: Icon(Icons.lightbulb_outline),
      ),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildFrequencySelector() {
    final theme = Theme.of(context);
    const frequencies = AppConstants.frequencies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frequency',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: frequencies.map((frequency) {
            final isSelected = _frequency == frequency;
            return FilterChip(
              label: Text(frequency),
              selected: isSelected,
              onSelected: (_) => setState(() {
                _frequency = frequency;
                if (frequency != AppConstants.frequencyCustom) {
                  _customWeekdays = [];
                }
              }),
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadiusTokens.full)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomWeekdaysSelector() {
    final theme = Theme.of(context);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Days',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: List.generate(7, (index) {
            final dayNum = index + 1;
            final isSelected = _customWeekdays.contains(dayNum);
            return FilterChip(
              label: Text(days[index]),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  if (isSelected) {
                    _customWeekdays.remove(dayNum);
                  } else {
                    _customWeekdays.add(dayNum);
                  }
                });
              },
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadiusTokens.full)),
            );
          }),
        ),
        if (_customWeekdays.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacingTokens.xs),
            child: Text(
              'Please select at least one day',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildTimeOfDaySelector() {
    final theme = Theme.of(context);
    const times = AppConstants.timeOfDayTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time of Day',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpacingTokens.sm),
        Wrap(
          spacing: AppSpacingTokens.sm,
          runSpacing: AppSpacingTokens.sm,
          children: times.map((time) {
            final isSelected = _timeOfDay == time;
            final icon = _getTimeIcon(time);
            return FilterChip(
              avatar: Icon(icon,
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant),
              label: Text(time),
              selected: isSelected,
              onSelected: (_) => setState(() => _timeOfDay = time),
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadiusTokens.full)),
            );
          }).toList(),
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
              prefixIcon: Icon(Icons.format_list_numbered_outlined),
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
              prefixIcon: Icon(Icons.timer_outlined),
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

    return FilledButton.icon(
      onPressed: _save,
      icon: Icon(isEditing ? Icons.save_rounded : Icons.add_rounded),
      label: Text(isEditing ? 'Save Changes' : 'Create Habit'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadiusTokens.lg)),
      ),
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
          updatedAt: DateTime.now(),
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
      CategoryType.tryFromString(category)?.icon ?? Icons.star_outline;

  IconData _getTimeIcon(String time) {
    switch (time) {
      case 'Morning':
        return Icons.wb_sunny_outlined;
      case 'Afternoon':
        return Icons.wb_sunny_outlined;
      case 'Evening':
        return Icons.nights_stay_outlined;
      default:
        return Icons.access_time_outlined;
    }
  }
}
