import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// An animated circular progress indicator with arbitrary content in the
/// middle.
///
/// Used as the hero element on the Habits screen, the way Streaks and
/// Habitify lead with a completion ring rather than a bare progress bar.
class ProgressRing extends StatelessWidget {
  /// Completion in the `0.0..1.0` range. Values outside are clamped.
  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final List<Color>? gradient;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 96,
    this.strokeWidth = 10,
    this.gradient,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor = color.withValues(alpha: 0.15);

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

  _RingPainter({
    required this.value,
    required this.trackColor,
    required this.color,
    required this.strokeWidth,
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

    canvas.drawArc(rect, start, sweep, false, stroke);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.gradient != gradient;
}
