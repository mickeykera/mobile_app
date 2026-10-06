import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Tactile press wrapper.
///
/// Every interactive surface in the app goes through this so a tap always
/// produces the same two signals: the target visibly squishes to
/// [AppAnimationTokens.pressScale] while held, and a light haptic fires on
/// press-down. Without both, a tap on a dark surface with no elevation change
/// gives almost no confirmation that anything happened.
///
/// Deliberately built on `GestureDetector` rather than `InkWell`: `InkWell`
/// paints a splash on the nearest `Material`, which on a translucent card means
/// the ripple is painted on the *page* behind it and appears as a grey smudge
/// at the card's edge.
class Pressable extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  /// How far down the target shrinks while held.
  final double pressScale;

  /// Fire a light impact haptic on press-down. Turn off for repeated controls
  /// (a scrollable row of chips) where one tap per second becomes noise.
  final bool haptics;

  /// Whether this is the chosen option in a set of mutually exclusive choices.
  ///
  /// Announced as "selected". Without it a chip row is a row of interchangeable
  /// buttons to a screen reader, which makes the current filter or category
  /// undiscoverable. Null means "not part of a single-choice group", which
  /// leaves the flag out of the semantics tree entirely rather than reporting
  /// `false` for every ordinary button.
  final bool? selected;

  /// Declares this control as one option of a single-choice group, e.g. the
  /// category or weekday chips.
  final bool inMutuallyExclusiveGroup;

  /// Drop the child's own semantics, keeping only this wrapper's.
  ///
  /// Set when [semanticLabel] already says everything the child would: a chip
  /// whose label is "Mind" and whose child text is also "Mind" otherwise gets
  /// announced twice, which is how a chip row ends up sounding like a list of
  /// duplicated words to a screen reader.
  final bool excludeChildSemantics;

  /// Marks the node as a button for screen readers. On by default; turn off
  /// when wrapping something that is already exposed as one (an `InkWell`, a
  /// `ListTile`) to avoid a doubled announcement.
  final bool semanticButton;

  /// Identity for the semantic node, e.g. the label of the thing it wraps.
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = AppAnimationTokens.pressScale,
    this.haptics = true,
    this.semanticButton = true,
    this.semanticLabel,
    this.selected,
    this.inMutuallyExclusiveGroup = false,
    this.excludeChildSemantics = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;

    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (_) {
              _setPressed(true);
              if (widget.haptics) HapticFeedback.lightImpact();
            }
          : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.pressScale : 1.0,
        // Short on the way down so the press feels immediate, and slower on the
        // way back out so the target springs up rather than snapping.
        duration: Duration(
          milliseconds: _pressed
              ? AppAnimationTokens.fast.inMilliseconds
              : AppAnimationTokens.medium.inMilliseconds,
        ),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );

    // Selection state is announced even when `semanticButton` is off: a chip row
    // usually needs `semanticButton: false` because each pill's child text would
    // otherwise produce a doubled announcement, and the selection flag must not
    // be lost along with it.
    if ((widget.semanticButton && enabled) ||
        widget.selected != null ||
        widget.inMutuallyExclusiveGroup) {
      result = Semantics(
        container: widget.semanticButton && enabled,
        button: widget.semanticButton && enabled,
        label: widget.semanticLabel,
        selected: widget.selected,
        inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
        excludeSemantics: widget.excludeChildSemantics,
        child: result,
      );
    }

    return result;
  }
}
