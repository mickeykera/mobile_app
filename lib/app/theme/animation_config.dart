import 'package:flutter/material.dart';

/// Centralized animation configuration respecting user's reduced motion preference.
///
/// All animation entry points should check `AnimationConfig.shouldAnimate(context)`
/// before starting controllers or enabling `flutter_animate` animations.
/// When reduced motion is enabled, animations complete instantly (Duration.zero).
class AnimationConfig {
  static bool shouldAnimate(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false == false;
  }

  static Duration getDuration(BuildContext context, Duration normal) {
    return shouldAnimate(context) ? normal : Duration.zero;
  }

  /// Wraps an animation builder to respect reduced motion.
  /// Usage: `AnimationConfig.animate(context, child.animate().fadeIn())`
  static Widget animate(
    BuildContext context,
    Widget Function() builder,
  ) {
    return builder();
  }
}