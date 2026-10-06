import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/glass_card.dart';
import '../../../../app/widgets/mini_week_strip.dart';
import '../../../../app/widgets/pressable.dart';
import '../../domain/entities/habit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A single habit row.
///
/// The surface is a translucent card with a category-coloured wash, the
/// completion control is a custom animated circle rather than a checkbox, and
/// the whole card can be swiped to complete or undo a completion.
///
/// [onTap] opens the editor. [onLongPress] and [onMoreActions] both open the
/// options sheet - the trailing button is there because long press is not
/// discoverable, so the two entry points have to reach the same place.
/// [onComplete] / [onUncomplete] drive the completion circle, and the swipe
/// callbacks return whether the dismiss should stand.
class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onUncomplete;
  final VoidCallback? onLongPress;
  final VoidCallback? onMoreActions;

  /// Invoked on a swipe-to-the-start. Returning false cancels the dismiss.
  /// Used for complete/uncomplete actions.
  final FutureOr<bool> Function()? onSwipeComplete;
  final FutureOr<bool> Function()? onSwipeUncomplete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.isCompleted,
    required this.onTap,
    this.onComplete,
    this.onUncomplete,
    this.onLongPress,
    this.onMoreActions,
    this.onSwipeComplete,
    this.onSwipeUncomplete,
  });

  @override
  Widget build(BuildContext context) {
    final card = _buildCard(context);

    final canSwipe = onSwipeComplete != null || onSwipeUncomplete != null;
    if (!canSwipe) return card;

    return _SwipeableHabitCard(
      habit: habit,
      onComplete: onSwipeComplete,
      onUncomplete: onSwipeUncomplete,
      child: card,
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = habit.categoryColorFor(Theme.of(context).brightness);

    return Semantics(
      button: true,
      label: '${habit.title}, ${habit.category}'
          '${isCompleted ? ', completed today' : ''}',
      child: ExcludeSemantics(
        child: GlassCard(
          onTap: onTap,
          onLongPress: onLongPress,
          padding: const EdgeInsets.all(AppSpacingTokens.md - 2),
          tint: accent,
          // Completed rows get a stronger wash and a lit border so the list
          // reads at a glance: done rows recede, pending rows pop.
          tintOpacity: isCompleted ? 0.16 : 0.07,
          border: Border.all(
            color: isCompleted
                ? accent.withValues(alpha: 0.45)
                : AppColors.hairline(scheme),
            width: isCompleted ? 1.5 : 1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CompletionToggle(
                isCompleted: isCompleted,
                accent: accent,
                onTap: () {
                  if (isCompleted) {
                    onUncomplete?.call();
                  } else {
                    onComplete?.call();
                  }
                },
              ),
              const SizedBox(width: AppSpacingTokens.md - 2),
              Expanded(child: _buildHabitInfo(context)),
              const SizedBox(width: AppSpacingTokens.sm),
              _buildStreakBadge(context),
              const SizedBox(width: AppSpacingTokens.sm),
              // Trailing "more actions" button
              if (onMoreActions != null)
                _MoreActionsButton(
                  habit: habit,
                  onPressed: onMoreActions!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitInfo(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = habit.categoryColorFor(Theme.of(context).brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _CategoryTag(label: habit.category, accent: accent),
            if (habit.targetDuration.inMinutes > 0)
              _MetaTag(
                icon: LucideIcons.timer,
                label: '${habit.targetDuration.inMinutes} min',
              ),
            // The card stays in the library while snoozed, so it needs to say
            // why it is missing from Today's workload.
            if (habit.isSnoozed)
              const _MetaTag(icon: LucideIcons.clock, label: 'Snoozed'),
          ],
        ),
        const SizedBox(height: AppSpacingTokens.sm - 2),
        // The title strikes through rather than fading, so "done" is legible
        // without relying on colour alone.
        AnimatedDefaultTextStyle(
          duration: AppAnimationTokens.medium,
          curve: Curves.easeOutCubic,
          style: AppTextStyles.titleMedium.copyWith(
            color: isCompleted ? scheme.onSurfaceVariant : scheme.onSurface,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            decorationColor: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          child: Text(
            habit.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (habit.description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            habit.description,
            style: AppTextStyles.bodySmall.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacingTokens.sm),
        // The seven-tile chain gives a per-habit read on consistency that the
        // streak number alone cannot: it shows *where* in the week it broke.
        MiniWeekStrip(
          days: deriveWeekStates(
            lastCompletedAt: habit.lastCompletedAt,
            currentStreak: habit.currentStreak,
          ),
          accent: accent,
        ),
        const SizedBox(height: AppSpacingTokens.sm),
        Row(
          children: [
            Icon(
              _timeOfDayIcon(habit.timeOfDay),
              size: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 4),
            Text(
              habit.timeOfDay,
              style: AppTextStyles.labelSmall.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(width: AppSpacingTokens.sm),
            Icon(
              _frequencyIcon(habit.frequency),
              size: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _frequencyLabel(habit.frequency, habit.customWeekdays),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakBadge(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = habit.categoryColorFor(Theme.of(context).brightness);

    if (habit.currentStreak == 0 && habit.longestStreak == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: AppAnimationTokens.medium,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadiusTokens.full),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.2),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.flame,
                size: 14,
                color: accent,
              ),
              const SizedBox(width: 3),
              Text(
                '${habit.currentStreak}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (habit.longestStreak > habit.currentStreak) ...[
          const SizedBox(height: 4),
          Text(
            'Best ${habit.longestStreak}',
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 9.5,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }

  IconData _timeOfDayIcon(String timeOfDay) {
    switch (timeOfDay) {
      case 'Morning':
        return LucideIcons.sunset;
      case 'Afternoon':
        return LucideIcons.sun;
      case 'Evening':
        return LucideIcons.moon;
      default:
        return LucideIcons.clock;
    }
  }

  IconData _frequencyIcon(String frequency) {
    switch (frequency) {
      case 'Daily':
        return LucideIcons.repeat;
      case 'Weekdays':
        return LucideIcons.calendar;
      case 'Weekends':
        return LucideIcons.calendarDays;
      case 'Custom':
        return LucideIcons.slidersHorizontal;
      default:
        return LucideIcons.repeat;
    }
  }

  String _frequencyLabel(String frequency, List<int> customWeekdays) {
    switch (frequency) {
      case 'Daily':
        return 'Daily';
      case 'Weekdays':
        return 'Mon-Fri';
      case 'Weekends':
        return 'Sat-Sun';
      case 'Custom':
        if (customWeekdays.isEmpty) return 'Custom';
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return customWeekdays.map((d) => days[d - 1]).join(', ');
      default:
        return frequency;
    }
  }
}

/// The trailing "more actions" affordance.
///
/// Long press reaches the same options sheet, but long press is invisible until
/// you already know it exists, so the sheet needs a labelled control too. The
/// callback comes from the list, which owns the sheet and the dialogs behind it:
/// a card that built its own sheet had no way to reach the screen's navigator
/// safely, and ended up deferring its dialog to a post-frame callback.
class _MoreActionsButton extends StatelessWidget {
  final Habit habit;
  final VoidCallback onPressed;

  const _MoreActionsButton({required this.habit, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      semanticLabel: 'More actions for ${habit.title}',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacingTokens.xs),
        child: Icon(
          LucideIcons.moreHorizontal,
          size: 20,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SwipeableHabitCard extends StatefulWidget {
  final Habit habit;
  final FutureOr<bool> Function()? onComplete;
  final FutureOr<bool> Function()? onUncomplete;
  final Widget child;

  const _SwipeableHabitCard({
    required this.habit,
    required this.child,
    this.onComplete,
    this.onUncomplete,
  });

  @override
  State<_SwipeableHabitCard> createState() => _SwipeableHabitCardState();
}

class _SwipeableHabitCardState extends State<_SwipeableHabitCard> {
  /// Live drag distance, 0..1, fed from `Dismissible.onUpdate`.
  ///
  /// Dismissible exposes no progress to its backgrounds, so this is how the
  /// icon grows and rotates as the card is dragged rather than snapping in at
  /// the commit threshold.
  final ValueNotifier<double> _progress = ValueNotifier(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canComplete =
        widget.onComplete != null && !widget.habit.isCompletedToday;
    final canUncomplete =
        widget.onUncomplete != null && widget.habit.isCompletedToday;
    final canSwipe = canComplete || canUncomplete;
    if (!canSwipe) return widget.child;

    final isCompleted = widget.habit.isCompletedToday;
    const accent = AppColors.accentWarm; // Green for complete

    return Dismissible(
      key: ValueKey('habit-${widget.habit.id}'),
      background: canComplete
          ? _SwipeBackground(
              progress: _progress,
              alignment: Alignment.centerLeft,
              accent: accent,
              icon: LucideIcons.check,
              label: 'Complete',
            )
          : canUncomplete
              ? _SwipeBackground(
                  progress: _progress,
                  alignment: Alignment.centerLeft,
                  accent: AppColors.accentWarm,
                  icon: LucideIcons.rotateCcw,
                  label: 'Undo',
                )
              : null,
      secondaryBackground: null, // Right swipe handled by trailing button
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (isCompleted) {
            return await widget.onUncomplete?.call() ?? false;
          } else {
            return await widget.onComplete?.call() ?? false;
          }
        }
        return false;
      },
      onUpdate: (details) => _progress.value = details.progress,
      child: widget.child,
    );
  }
}

/// The rounded panel revealed behind a swiped card.
///
/// The radius is asymmetric: square against the trailing edge the card is
/// sliding away from, rounded on the leading edge where the card still sits, so
/// the revealed shape follows the card rather than looking like a second card.
class _SwipeBackground extends StatelessWidget {
  final ValueListenable<double> progress;
  final Alignment alignment;
  final Color accent;
  final IconData icon;
  final String label;

  const _SwipeBackground({
    required this.progress,
    required this.alignment,
    required this.accent,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacingTokens.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.horizontal(
          // The card covers the outer edge, so only the inner edge is visible.
          left: Radius.circular(isLeft ? 0 : AppRadiusTokens.lg),
          right: Radius.circular(isLeft ? AppRadiusTokens.lg : 0),
        ),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, value, child) {
          // Ramp the icon in over the first 40% of the drag, then hold. Scaling
          // it linearly with the whole drag made it look like it was falling
          // behind the card.
          final t = (value / 0.4).clamp(0.0, 1.0);
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.7 + t * 0.3,
              child: child,
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLeft) Text(label, style: _labelStyle(accent)),
            if (!isLeft) const SizedBox(width: 8),
            Icon(icon, color: accent, size: 22),
            if (isLeft) const SizedBox(width: 8),
            if (isLeft) Text(label, style: _labelStyle(accent)),
          ],
        ),
      ),
    );
  }

  TextStyle _labelStyle(Color accent) => AppTextStyles.labelLarge.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
      );
}

/// The custom animated completion circle.
///
/// Replaces Material's checkbox. On the way to completed it runs a
/// celebratory two-stage pop - out past 1.1, then an elastic settle back to 1 -
/// and crosses a heavier haptic, because this is the single most important
/// interaction in the app and deserves more than the light impact a generic tap
/// gets.
class _CompletionToggle extends StatefulWidget {
  final bool isCompleted;
  final Color accent;
  final VoidCallback onTap;

  const _CompletionToggle({
    required this.isCompleted,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_CompletionToggle> createState() => _CompletionToggleState();
}

class _CompletionToggleState extends State<_CompletionToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  /// The squash-in / overshoot / elastic-settle curve, sampled off [_pop].
  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 0.8, end: 1.12).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 28,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.12, end: 1).chain(
        CurveTween(curve: Curves.elasticOut),
      ),
      weight: 72,
    ),
  ]).animate(_pop);

  static const double _diameter = 46;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
      // Rests at 1, which maps to the end of the sequence and therefore to a
      // scale of exactly 1.0. Starting at 0 would rest the circle visibly
      // squashed.
      value: 1,
    );
  }

  @override
  void didUpdateWidget(_CompletionToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted == oldWidget.isCompleted) return;

    if (widget.isCompleted) {
      HapticFeedback.mediumImpact();
      _pop.forward(from: 0);
    } else {
      // Return to rest so an interrupt mid-bounce does not leave the circle
      // stuck slightly oversized.
      _pop.animateTo(1, duration: AppAnimationTokens.medium);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accent;
    // Done is always brand blue, whatever category the habit is. Four category
    // hues meant four different meanings for one filled circle, so a glance
    // down the list could not answer "how am I doing" - only "what is this
    // one". The incomplete ring keeps the category accent, so nothing about
    // the habit's identity is lost.
    const doneColor = AppColors.accentPrimary;
    final ink = AppColors.onColorFor(doneColor, scheme);

    return Semantics(
        checked: widget.isCompleted,
        button: true,
        child: Tooltip(
          message:
              widget.isCompleted ? 'Mark as incomplete' : 'Mark as complete',
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _pop,
              builder: (context, child) {
                // A single tween cannot express this: the brief's
                // `.scale(begin: Offset(0.8, 0.8), end: Offset(1.1, 1.1))` has to
                // land on 1.0, not 1.1, or the circle is left permanently 10%
                // oversized. So squash in, overshoot to 1.12, then settle back to
                // exactly 1.0. `elasticOut` on the second half is what makes it
                // read as a bounce rather than a plain ease-out.
                final scale = _popScale.value;
                return Transform.scale(scale: scale, child: child);
              },
              child: AnimatedContainer(
                duration: AppAnimationTokens.medium,
                curve: Curves.easeOutCubic,
                width: _diameter,
                height: _diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.isCompleted
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            doneColor,
                            Color.lerp(doneColor, AppColors.accentDeep, 0.3)!,
                          ],
                        )
                      : null,
                  color: widget.isCompleted
                      ? null
                      : accent.withValues(alpha: 0.08),
                  border: Border.all(
                    color: widget.isCompleted
                        ? Colors.transparent
                        : accent.withValues(alpha: 0.45),
                    width: 2,
                  ),
                  boxShadow: widget.isCompleted
                      ? [
                          BoxShadow(
                            color: doneColor.withValues(alpha: 0.45),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: AppAnimationTokens.medium,
                  switchInCurve: Curves.easeOutBack,
                  // The tick cross-fades in but the surrounding circle is already
                  // scaling, so fading the outgoing icon out over the same window
                  // would make two ticks visible at once mid-pop.
                  transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      )),
                  child: widget.isCompleted
                      ? Icon(
                          LucideIcons.check,
                          key: const ValueKey('done'),
                          size: 24,
                          color: ink,
                        )
                      : Icon(
                          LucideIcons.plus,
                          key: const ValueKey('todo'),
                          size: 22,
                          color: accent.withValues(alpha: 0.75),
                        ),
                ),
              ),
            ),
          ),
        ));
  }
}

/// A small rounded category pill.
///
/// The dot carries the category colour and the text stays muted, so a card with
/// four chips in it does not turn into four competing colours.
class _CategoryTag extends StatelessWidget {
  final String label;
  final Color accent;

  const _CategoryTag({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadiusTokens.full),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accent, blurRadius: 4, spreadRadius: 0.5),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadiusTokens.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
