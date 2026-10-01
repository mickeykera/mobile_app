import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import 'pressable.dart';

/// A filter / preset chip with a glassy backdrop.
///
/// Material's `FilterChip` cannot do this: its selected state is a flat fill,
/// and its shape is a rounded rectangle with a hard outline. These are pills
/// that pick up whatever is behind them, which is what makes a row of them sit
/// on a gradient header instead of looking pasted onto it.
class GlassPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color accent;
  final bool haptics;

  const GlassPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.accent = AppColors.neonCyan,
    this.haptics = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = selected ? accent : scheme.onSurface;

    return Pressable(
      onTap: onTap,
      haptics: haptics,
      pressScale: 0.94,
      semanticLabel: label,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      // The label below already reads the pill's text, so letting the child
      // contribute its own would announce every pill twice.
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: AppAnimationTokens.medium,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacingTokens.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadiusTokens.full),
          color: selected
              ? accent.withValues(alpha: 0.18)
              : scheme.onSurface.withValues(alpha: 0.06),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : AppColors.hairline(scheme),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadiusTokens.full),
          child: BackdropFilter(
            // Selected pills blur, unselected ones do not: blurring every chip
            // in a scrolling row is a per-frame read of the backdrop, and it is
            // invisible on a flat surface anyway.
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    AnimatedSwitcher(
                      duration: AppAnimationTokens.fast,
                      child: Icon(
                        icon,
                        key: ValueKey('$label-$selected'),
                        size: 15,
                        color: selected
                            ? accent
                            : scheme.onSurfaceVariant
                                .withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: selected ? tint : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
}

/// A horizontally scrolling row of [GlassPill]s.
///
/// Used for the category filters, the focus mode presets and the analytics
/// period selector. Scroll physics are set to snap-free and fling-only so a
/// flick glides the whole strip rather than stopping it between pills.
class GlassPillRow extends StatelessWidget {
  final List<Widget> pills;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const GlassPillRow({
    super.key,
    required this.pills,
    this.padding = EdgeInsets.zero,
    this.spacing = AppSpacingTokens.sm,
  });

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < pills.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            pills[i],
          ],
        ],
      ),
    );
  }
}