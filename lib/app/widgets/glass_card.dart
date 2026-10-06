import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';

/// The app's standard card surface.
///
/// A translucent fill plus a 1px hairline, rather than an opaque fill plus a
/// shadow. On the midnight background the translucency is what lets a card read
/// as sitting *on* a surface rather than being cut out of one.
///
/// Defaults to [AppRadiusTokens.lg] (20dp) and, when [onTap] is supplied, wraps
/// itself in a [Pressable] so every card in the app squishes on touch without
/// each call site having to remember to.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;

  /// Replaces the fill with a gradient. Used by the screens whose hero card
  /// carries the accent.
  final Gradient? gradient;

  /// A colour washed over the fill, for category-coding a card without giving
  /// up the glass effect.
  final Color? tint;
  final double tintOpacity;

  final List<BoxShadow>? shadows;
  final Border? border;

  /// When set, the whole card becomes tappable and gains the press response.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final String? semanticLabel;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacingTokens.md),
    this.radius = AppRadiusTokens.lg,
    this.opacity = 0.7,
    this.gradient,
    this.tint,
    this.tintOpacity = 0.09,
    this.shadows,
    this.border,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget card = Container(
      padding: padding,
      decoration: AppColors.glass(
        scheme,
        radius: radius,
        opacity: opacity,
        gradient: gradient,
        tint: tint,
        tintOpacity: tintOpacity,
        shadows: shadows,
        border: border,
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      card = Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: semanticLabel,
        child: card,
      );
    }

    return card;
  }
}
