import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/premium_provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/text_styles.dart';
import '../../../../app/widgets/glow_button.dart';
import '../../../../app/widgets/glass_card.dart';
import '../../../../app/widgets/pressable.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  @override
  Widget build(BuildContext context) {
    final premiumState = ref.watch(premiumProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacingTokens.gutter,
              0,
              AppSpacingTokens.gutter,
              // Clears the floating nav bar.
              96,
            ),
            sliver: SliverList.separated(
              itemCount: _PremiumFeature.values.length + 3,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) return _buildHeader(context);
                if (index == 1) {
                  return _buildCurrentPlan(context, premiumState)
                      .animate()
                      .fadeIn(duration: AppAnimationTokens.slow)
                      .slideY(begin: 0.05, end: 0);
                }
                if (index == 2) {
                  return _buildPricingCard(context, premiumState)
                      .animate()
                      .fadeIn(
                        delay: const Duration(milliseconds: 90),
                        duration: AppAnimationTokens.slow,
                      )
                      .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
                }
                return _buildFeatureCard(
                  context,
                  _PremiumFeature.values[index - 3],
                  premiumState,
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(
                        milliseconds: (index * 60).clamp(0, 420),
                      ),
                      duration: AppAnimationTokens.slow,
                    )
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: AppSpacingTokens.lg,
      title: ShaderMask(
        shaderCallback:
            AppGradients.action(AppColors.radiantViolet).createShader,
        child: Text(
          'Premium',
          style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: kToolbarHeight + AppSpacingTokens.sm),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacingTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The diamond sits behind the copy rather than beside it: a 150dp
            // glyph next to a headline pushed the text into a narrow column and
            // wrapped it onto three lines.
            SizedBox(
              height: 132,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: AuroraBackdrop(
                      accentA: AppColors.radiantViolet,
                      accentB: AppColors.neonCyan,
                      opacity: 0.26,
                    ),
                  ),
                  Center(
                    child: const Icon(
                      Icons.diamond_rounded,
                      size: 72,
                      color: AppColors.radiantViolet,
                    )
                        // A slow shimmer. This is the one place in the app that
                        // loops forever on its own, because it is the one thing
                        // on the screen asking to be bought.
                        .animate(
                          onPlay: (c) => c.repeat(reverse: true),
                        )
                        .scaleXY(
                          begin: 1,
                          end: 1.08,
                          duration: 1800.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacingTokens.md),
            ShaderMask(
              shaderCallback:
                  AppGradients.action(AppColors.radiantViolet).createShader,
              child: Text(
                'Unlock Your Full Potential',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacingTokens.sm),
            Text(
              'Upgrade to Premium to unlock all features and reach your goals faster.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlan(BuildContext context, PremiumState state) {
    final theme = Theme.of(context);
    final isPremium = state.isPremium;
    final accent = isPremium ? AppColors.emerald : AppColors.radiantViolet;

    return GlassCard(
      tint: accent,
      tintOpacity: isPremium ? 0.18 : 0.1,
      padding: const EdgeInsets.all(AppSpacingTokens.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacingTokens.sm + 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadiusTokens.md),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(
              isPremium ? Icons.diamond_rounded : Icons.lock_outline_rounded,
              size: 26,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // `AnimatedSwitcher` on the plan name: upgrading flips this
                // label in place, and a hard swap read as a page change.
                AnimatedSwitcher(
                  duration: AppAnimationTokens.medium,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    isPremium ? 'Premium Active' : 'Free Plan',
                    key: ValueKey(isPremium),
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? 'Enjoying all premium features'
                      : 'Upgrade to unlock all features',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!isPremium)
            GlowButton(
              label: 'Upgrade',
              accent: AppColors.radiantViolet,
              height: 40,
              onPressed: () => _showUpgradeSheet(context),
            ),
        ],
      ),
    );
  }

  /// The offer itself: price, what it costs per month, and the primary CTA.
  ///
  /// Split out from the feature list because the two answer different questions.
  /// The feature rows say *what* you get; this says *whether* it is worth it.
  Widget _buildPricingCard(BuildContext context, PremiumState state) {
    final theme = Theme.of(context);

    if (state.isPremium) {
      return const GlassCard(
        tint: AppColors.emerald,
        padding: EdgeInsets.all(AppSpacingTokens.lg),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.emerald,
              size: 22,
            ),
            SizedBox(width: AppSpacingTokens.sm + 2),
            Expanded(
              child: Text(
                'Thanks for supporting Ascend. Every feature is unlocked.',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      tint: AppColors.radiantViolet,
      tintOpacity: 0.14,
      padding: const EdgeInsets.all(AppSpacingTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback:
                    AppGradients.action(AppColors.radiantViolet).createShader,
                child: Text(
                  '\$4.99',
                  style: AppTextStyles.displaySmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/month',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '\$39.99/year',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'or \$2.99/month billed yearly — two months free.',
            style: AppTextStyles.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacingTokens.md),
          GlowButton(
            label: 'Upgrade to Premium',
            icon: Icons.diamond_rounded,
            accent: AppColors.radiantViolet,
            width: double.infinity,
            height: 54,
            // The only permanently looping animation in the app, and
            // deliberately so: it is the primary call to action, and a slow
            // breathing glow reads as "this is live" in a way a static gradient
            // does not.
            pulsing: true,
            onPressed: () => _showUpgradeSheet(context),
          ),
          const SizedBox(height: AppSpacingTokens.sm),
          Text(
            'Cancel anytime. No commitment.',
            style: AppTextStyles.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, _PremiumFeature feature, PremiumState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unlocked = feature.isFree || state.isPremium;
    // A free feature gets a muted accent: it should read as already yours
    // rather than as another thing on the paywall list.
    final accent = unlocked ? feature.color : colorScheme.onSurfaceVariant;

    return GlassCard(
      tint: unlocked ? feature.color : null,
      tintOpacity: unlocked ? 0.1 : 0.05,
      padding: const EdgeInsets.all(AppSpacingTokens.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacingTokens.sm + 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: unlocked ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(AppRadiusTokens.md),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(
              unlocked ? feature.icon : Icons.lock_outline_rounded,
              size: 22,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        feature.title,
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: unlocked
                              ? colorScheme.onSurface
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (unlocked)
                      _PlanTag(
                        label: 'INCLUDED',
                        color: feature.color,
                      )
                    else
                      const _PlanTag(
                        label: 'PREMIUM',
                        color: AppColors.radiantViolet,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  feature.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A sheet rather than an `AlertDialog`: a dialog puts a block of text and two
  /// flat buttons on a scrim, which is the least interesting surface in the app
  /// to host the one decision the whole screen exists to make.
  Future<void> _showUpgradeSheet(BuildContext context) async {
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadiusTokens.sheetTop),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardFill(theme.colorScheme, opacity: 0.94),
              border: Border(
                top: BorderSide(color: AppColors.hairline(theme.colorScheme)),
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacingTokens.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.diamond_rounded,
                          color: AppColors.radiantViolet,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacingTokens.sm),
                        const Expanded(
                          child: Text(
                            'Premium',
                            style: AppTextStyles.headlineSmall,
                          ),
                        ),
                        GlowIconButton(
                          icon: Icons.close_rounded,
                          accent: theme.colorScheme.onSurfaceVariant,
                          size: 40,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacingTokens.sm),
                    Text(
                      'Everything in Ascend, with no limits.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacingTokens.lg),
                    for (final feature in _PremiumFeature.values.where(
                      (f) => !f.isFree,
                    ))
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacingTokens.sm + 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.check_rounded,
                                size: 17,
                                color: AppColors.emerald,
                              ),
                            ),
                            const SizedBox(width: AppSpacingTokens.sm + 2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feature.title,
                                    style: AppTextStyles.labelLarge,
                                  ),
                                  Text(
                                    feature.description,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacingTokens.md),
                    GlowButton(
                      label: 'Upgrade Now',
                      icon: Icons.diamond_rounded,
                      accent: AppColors.radiantViolet,
                      width: double.infinity,
                      height: 54,
                      onPressed: () {
                        Navigator.pop(context);
                        _handleUpgrade();
                      },
                    ),
                    const SizedBox(height: AppSpacingTokens.sm),
                    Pressable(
                      onTap: () => Navigator.pop(context),
                      semanticLabel: 'Maybe later',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'Maybe Later',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleUpgrade() {
    // In a real app, this would trigger the purchase flow.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase flow would be triggered here')),
    );
    // For demo purposes, we'll simulate a successful upgrade.
    ref.read(premiumProvider.notifier).upgradeToPremium();
  }
}

/// A small uppercase tag. One widget for both states so the two never drift
/// apart in padding or radius.
class _PlanTag extends StatelessWidget {
  final String label;
  final Color color;

  const _PlanTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadiusTokens.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

enum _PremiumFeature {
  unlimitedHabits(
    title: 'Unlimited Habits',
    description: 'Create as many habits as you need without limits',
    icon: Icons.track_changes_rounded,
    color: AppColors.habitMind,
    isFree: true,
  ),
  advancedAnalytics(
    title: 'Advanced Analytics',
    description: 'Detailed insights, trends, and progress reports',
    icon: Icons.analytics_rounded,
    color: AppColors.neonCyan,
    isFree: false,
  ),
  customFocus(
    title: 'Custom Focus Sessions',
    description: 'Create custom durations, intervals, and break patterns',
    icon: Icons.timer_outlined,
    color: AppColors.habitCraft,
    isFree: false,
  ),
  dataExport(
    title: 'Data Export & Backup',
    description: 'Export your data as CSV/JSON or backup to cloud',
    icon: Icons.download_rounded,
    color: AppColors.habitDiscipline,
    isFree: false,
  ),
  cloudSync(
    title: 'Cloud Sync',
    description: 'Sync across all your devices seamlessly',
    icon: Icons.cloud_sync_rounded,
    color: AppColors.radiantViolet,
    isFree: false,
  ),
  prioritySupport(
    title: 'Priority Support',
    description: 'Get help faster with dedicated support',
    icon: Icons.support_agent_rounded,
    color: AppColors.habitBody,
    isFree: false,
  );

  const _PremiumFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isFree,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isFree;
}
