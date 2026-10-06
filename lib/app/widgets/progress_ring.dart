import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// An animated circular progress indicator with arbitrary content in the
/// middle.
///
/// Used as the hero element on the Habits screen, the way Streaks and
/// Habitify lead with a completion ring rather than a bare progress bar.
///
/// Two details that matter on a dark background: the track is a translucent
/// wash of the accent rather than a grey, and the arc carries a `MaskFilter`
/// blur behind it so the stroke reads as emitting light. Without the glow a
/// ring on obsidian is just a coloured line.
class ProgressRing extends StatelessWidget {
  /// Completion in the `0.0..1.0` range. Values outside are clamped.
  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final List<Color>? gradient;
  final Widget? child;

  /// Blur radius of the halo drawn behind the arc. Zero disables it.
  final double glow;

  /// Opacity of the unfilled track.
  final double trackOpacity;

  /// Sweeps the arc from 12 o'clock clockwise. When false the arc depletes
  /// from the end instead, which is what the focus timer wants.
  final bool clockwise;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 96,
    this.strokeWidth = 10,
    this.gradient,
    this.child,
    this.glow = 6,
    this.trackOpacity = 0.14,
    this.clockwise = true,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor = color.withValues(alpha: trackOpacity);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: AppAnimationTokens.slow,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: animatedValue,
              trackColor: trackColor,
              color: color,
              strokeWidth: strokeWidth,
              gradient: gradient,
              glow: glow,
              clockwise: clockwise,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color color;
  final double strokeWidth;
  final List<Color>? gradient;
  final double glow;
  final bool clockwise;

  _RingPainter({
    required this.value,
    required this.trackColor,
    required this.color,
    required this.strokeWidth,
    required this.glow,
    required this.clockwise,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = trackColor,
    );

    if (value <= 0) return;

    // Start at 12 o'clock so the arc grows clockwise from the top.
    const start = -math.pi / 2;
    final sweep = math.pi * 2 * value;

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (gradient != null && gradient!.length >= 2) {
      stroke.shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: gradient!,
        transform: const GradientRotation(start),
      ).createShader(rect);
    } else {
      stroke.color = color;
    }

    // Halo pass: the same arc, blurred, at low alpha. Drawn first so the crisp
    // stroke sits on top of its own light.
    if (glow > 0) {
      canvas.drawArc(
        rect,
        start,
        clockwise ? sweep : -sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 1.6
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
      );
    }

    canvas.drawArc(rect, start, clockwise ? sweep : -sweep, false, stroke);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.glow != glow ||
      oldDelegate.clockwise != clockwise ||
      oldDelegate.gradient != gradient;
}

/// A small filled ring used as a day marker in the week strip.
///
/// Separate from [ProgressRing] because the strip needs a cheap version: seven
/// of these rebuild on every completion, and a full [ProgressRing] each would
/// put seven independent 350ms tweens on the timeline behind a habit tick.
/// Set [animate] to false to settle instantly instead.
class DayRing extends StatelessWidget {
  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final bool animate;

  const DayRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 32,
    this.strokeWidth = 3,
    this.child,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: animate ? AppAnimationTokens.medium : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: animated,
              trackColor: color.withValues(alpha: 0.16),
              color: color,
              strokeWidth: strokeWidth,
              gradient: null,
              glow: 0,
              clockwise: true,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
