import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

/// A single number with an icon, a label and an optional encouraging line.
///
/// Modelled on the two-up "Current streak / Weekly goal" stat blocks used by
/// market habit trackers, where the value is large and the subtitle carries the
/// encouragement rather than a separate banner.
///
/// The value is set in [AppTextStyles.metricLarge] with the icon as a soft
/// glowing well beside it, so two tiles read as one row rather than as two
/// competing blocks of text.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? subtitle;
  final Color accent;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacingTokens.md - 2),
      decoration: BoxDecoration(
        color: AppColors.cardFill(scheme, opacity: 0.6),
        borderRadius: BorderRadius.circular(AppRadiusTokens.lg),
        border: Border.all(color: AppColors.hairline(scheme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadiusTokens.sm),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(icon, size: 15, color: accent),
              ),
              const Spacer(),
              Text(
                value,
                style: AppTextStyles.metricLarge.copyWith(
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: AppSpacingTokens.sm),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTextStyles.subtitle.copyWith(
                color: accent,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}