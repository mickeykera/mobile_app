import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import 'pressable.dart';

/// A pill-shaped primary action with a gradient fill and a matching glow.
///
/// Used wherever an action is the reason the user opened the screen: Start
/// Session, Unlock Premium, Create Habit. The glow is the point - on an obsidian
/// background a filled button with no shadow reads as a sticker, and the
/// shadow is what makes it read as lit.
class GlowButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// The gradient's leading colour. Also drives the glow.
  final Color accent;

  /// Pill width. Defaults to hugging the label.
  final double? width;

  /// Overrides the pill height.
  final double height;

  /// Continuously pulse the glow. Reserved for a single screen's single
  /// conversion action; more than one pulsing element on screen defeats it.
  static bool debugDisablePulsing = false;

  final bool pulsing;

  /// A brighter gradient with dark foreground text, for use on top of an
  /// already-bright surface.
  final bool inverted;

  const GlowButton({
    super.key,
    required this.label,
    required this.accent,
    this.icon,
    this.onPressed,
    this.width,
    this.height = 56,
    this.pulsing = false,
    this.inverted = false,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Only run the ticker when it is actually visible: an always-running
    // 2s controller on an off-screen tab is pure battery cost.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.pulsing && !GlowButton.debugDisablePulsing) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GlowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing &&
        !GlowButton.debugDisablePulsing &&
        !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.pulsing && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final accent = widget.inverted ? Colors.white : widget.accent;
    final ink = widget.inverted
        ? AppColors.accentInk
        : AppColors.onColorFor(widget.accent, Theme.of(context).colorScheme);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // 0.3 -> 0.5 as the pulse breathes. The floor stays high enough that the
        // button is visibly a light source even at rest.
        final glow = 0.3 + _pulse.value * 0.2;
        return Pressable(
          onTap: widget.onPressed,
          semanticLabel: widget.label,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Container(
              width: widget.width,
              height: widget.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppGradients.action(accent),
                borderRadius: BorderRadius.circular(AppRadiusTokens.full),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: glow),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: ink, size: 20),
            const SizedBox(width: AppSpacingTokens.sm),
          ],
          Text(
            widget.label,
            style: AppTextStyles.labelLarge.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small glowing circular icon button, for secondary actions that still need
/// to look tappable against a busy background.
class GlowIconButton extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  const GlowIconButton({
    super.key,
    required this.icon,
    required this.accent,
    this.onPressed,
    this.tooltip,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onPressed,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: size * 0.45, color: accent),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// A decorative radial "aurora" wash for a header.
///
/// Two large, very low-alpha radial gradients. This is what stops the midnight
/// background from being a flat slab of near-black behind a card grid, at the
/// cost of one extra `Paint` per screen.
class AuroraBackdrop extends StatelessWidget {
  final Color accentA;
  final Color accentB;
  final double opacity;

  const AuroraBackdrop({
    super.key,
    this.accentA = AppColors.accentPrimary,
    this.accentB = AppColors.accentDeep,
    this.opacity = 0.16,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _AuroraPainter(
          accentA: accentA,
          accentB: accentB,
          opacity: opacity,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final Color accentA;
  final Color accentB;
  final double opacity;

  _AuroraPainter({
    required this.accentA,
    required this.accentB,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    blob(
      Offset(size.width * 0.85, size.height * 0.1),
      size.width * 0.6,
      accentA,
    );
    blob(
      Offset(size.width * 0.05, size.height * 0.55),
      size.width * 0.55,
      accentB,
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.accentA != accentA ||
      oldDelegate.accentB != accentB ||
      oldDelegate.opacity != opacity;
}

/// A soft outer glow drawn behind a circle, used by the focus timer ring.
///
/// A `BoxShadow` cannot do this: it needs to follow a ring's radius and it must
/// not fill the middle.
class RingGlow extends StatelessWidget {
  final Color color;
  final double size;
  final double intensity;

  const RingGlow({
    super.key,
    required this.color,
    required this.size,
    this.intensity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: intensity),
              blurRadius: size * 0.28,
              spreadRadius: size * 0.02,
            ),
            BoxShadow(
              color: color.withValues(alpha: intensity * 0.5),
              blurRadius: size * 0.6,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }
}

/// Utility: clamps a value into `0..1`, used by the progress painters.
double clamp01(double value) => math.max(0.0, math.min(1.0, value));
