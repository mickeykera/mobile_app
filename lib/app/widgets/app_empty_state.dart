import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import 'glow_button.dart';

/// Shared "there is nothing here yet" panel.
///
/// Market trackers never render a bare blank screen: they show an icon, a
/// plain explanation of what will appear, and the single action that fills it.
///
/// The icon sits in a gradient disc with an aurora behind it rather than a flat
/// tinted circle, because this is the first thing a new user sees on an empty
/// account and a flat grey circle reads as "broken".
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = accent ?? scheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacingTokens.gutter,
          vertical: AppSpacingTokens.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: AuroraBackdrop(
                      accentA: tint,
                      accentB: AppColors.radiantViolet,
                      opacity: 0.22,
                    ),
                  ),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tint.withValues(alpha: 0.22),
                          tint.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(color: tint.withValues(alpha: 0.35)),
                    ),
                    child: Icon(icon, size: 32, color: tint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacingTokens.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacingTokens.xs + 2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacingTokens.lg),
              GlowButton(
                label: actionLabel!,
                accent: tint,
                icon: Icons.add_rounded,
                onPressed: onAction,
                height: 50,
              ),
            ],
          ],
        ),
      ),
    );
  }
}