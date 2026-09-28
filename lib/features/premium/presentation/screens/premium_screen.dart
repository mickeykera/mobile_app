import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/premium_provider.dart';

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
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: _PremiumFeature.values.length + 2,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) return _buildHeader(context);
                if (index == 1) return _buildCurrentPlan(context, premiumState);
                return _buildFeatureCard(
                    context, _PremiumFeature.values[index - 2], premiumState);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Premium',
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer,
                colorScheme.secondaryContainer,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                right: -30,
                top: -30,
                child: Icon(
                  Icons.diamond_outlined,
                  size: 150,
                  color: colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unlock Your Full Potential',
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Upgrade to Premium to unlock all features and reach your goals faster.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildCurrentPlan(BuildContext context, PremiumState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPremium = state.isPremium;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPremium
            ? LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPremium ? null : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium
              ? Colors.transparent
              : colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPremium
                  ? colorScheme.onPrimary.withValues(alpha: 0.2)
                  : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPremium ? Icons.diamond_rounded : Icons.lock_outline_rounded,
              size: 28,
              color: isPremium
                  ? colorScheme.onPrimary
                  : colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'Premium Active' : 'Free Plan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isPremium
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPremium
                      ? 'Enjoying all premium features'
                      : 'Upgrade to unlock all features',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isPremium
                            ? colorScheme.onPrimary.withValues(alpha: 0.8)
                            : colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (!isPremium)
            FilledButton(
              onPressed: () => _showUpgradeDialog(context),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Upgrade'),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, _PremiumFeature feature, PremiumState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPremium = feature.isFree || state.isPremium;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium
              ? Colors.transparent
              : colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPremium
                  ? feature.color.withValues(alpha: 0.2)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature.icon,
              size: 24,
              color: isPremium ? feature.color : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        feature.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                    if (!isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PREMIUM',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (!isPremium)
            Icon(
              Icons.lock_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: const Text(
          'Unlock all premium features:\n\n'
          '• Unlimited habits\n'
          '• Advanced analytics & insights\n'
          '• Custom focus sessions\n'
          '• Data export & backup\n'
          '• Cloud sync across devices\n'
          '• Priority support\n\n'
          '\$4.99/month or \$39.99/year',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _handleUpgrade(context);
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  void _handleUpgrade(BuildContext context) {
    // In a real app, this would trigger the purchase flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase flow would be triggered here')),
    );
    // For demo purposes, we'll simulate a successful upgrade
    ref.read(premiumProvider.notifier).upgradeToPremium();
  }
}

enum _PremiumFeature {
  unlimitedHabits(
    title: 'Unlimited Habits',
    description: 'Create as many habits as you need without limits',
    icon: Icons.track_changes_rounded,
    color: Color(0xFF6366F1),
    isFree: true,
  ),
  advancedAnalytics(
    title: 'Advanced Analytics',
    description: 'Detailed insights, trends, and progress reports',
    icon: Icons.analytics_rounded,
    color: Color(0xFF10B981),
    isFree: false,
  ),
  customFocus(
    title: 'Custom Focus Sessions',
    description: 'Create custom durations, intervals, and break patterns',
    icon: Icons.timer_outlined,
    color: Color(0xFFF59E0B),
    isFree: false,
  ),
  dataExport(
    title: 'Data Export & Backup',
    description: 'Export your data as CSV/JSON or backup to cloud',
    icon: Icons.download_rounded,
    color: Color(0xFFEF4444),
    isFree: false,
  ),
  cloudSync(
    title: 'Cloud Sync',
    description: 'Sync across all your devices seamlessly',
    icon: Icons.cloud_sync_rounded,
    color: Color(0xFF8B5CF6),
    isFree: false,
  ),
  prioritySupport(
    title: 'Priority Support',
    description: 'Get help faster with dedicated support',
    icon: Icons.support_agent_rounded,
    color: Color(0xFF06B6D4),
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
