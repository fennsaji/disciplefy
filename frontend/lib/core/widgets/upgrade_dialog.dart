import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';

/// Upgrade dialog shown when users tap locked features
///
/// Shows feature information and encourages upgrade to required plan
class UpgradeDialog extends StatelessWidget {
  final String featureKey;
  final String currentPlan;
  final List<String> requiredPlans;
  final String? upgradePlan;

  const UpgradeDialog({
    super.key,
    required this.featureKey,
    required this.currentPlan,
    required this.requiredPlans,
    this.upgradePlan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featureInfo = _getFeatureInfo(featureKey);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Feature icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    featureInfo.icon,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Feature name
              Text(
                featureInfo.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Feature description
              Text(
                featureInfo.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Lock status message
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Locked on your plan',
                        style: TextStyle(
                          color: AppColors.warningDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Current plan badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_circle_outlined,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Your Plan: ',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatPlanName(currentPlan),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Required plan info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: theme.brightness == Brightness.dark
                        ? [
                            theme.colorScheme.primary.withOpacity(0.15),
                            theme.colorScheme.primary.withOpacity(0.08),
                          ]
                        : [
                            theme.colorScheme.primary.withOpacity(0.1),
                            theme.colorScheme.primary.withOpacity(0.05),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.primary.withOpacity(0.4)
                        : theme.colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Available on:',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: requiredPlans.map((plan) {
                        final planColor = _getPlanColor(plan);
                        final isDark = theme.brightness == Brightness.dark;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? planColor.withOpacity(0.15)
                                : planColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? planColor.withOpacity(0.6)
                                  : planColor.withOpacity(0.8),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _formatPlanName(plan),
                            style: TextStyle(
                              color: isDark
                                  ? planColor.withOpacity(0.9)
                                  : planColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  // Maybe Later button
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Upgrade Now button
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToSubscription(context, upgradePlan);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandSecondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Upgrade Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSubscription(BuildContext context, String? targetPlan) {
    // Navigate to pricing page with target plan pre-selected
    context.push(AppRoutes.pricing, extra: {'preselectedPlan': targetPlan});
  }

  String _formatPlanName(String plan) {
    return plan[0].toUpperCase() + plan.substring(1);
  }

  Color _getPlanColor(String plan) {
    switch (plan.toLowerCase()) {
      case 'free':
        return Colors.grey;
      case 'standard':
        return Colors.blue;
      case 'plus':
        return Colors.indigo;
      case 'premium':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  _FeatureInfo _getFeatureInfo(String featureKey) {
    switch (featureKey) {
      case 'ai_discipler':
        return _FeatureInfo(
          name: 'AI Discipler',
          description:
              'Have natural voice conversations about Bible topics with your AI study companion.',
          icon: Icons.mic_rounded,
        );
      case 'learning_paths':
        return _FeatureInfo(
          name: 'Learning Paths',
          description:
              'Follow structured Bible study journeys designed for spiritual growth.',
          icon: Icons.route_rounded,
        );
      case 'memory_verses':
        return _FeatureInfo(
          name: 'Memory Verses',
          description:
              'Learn and memorize Scripture with spaced repetition and audio practice.',
          icon: Icons.psychology_rounded,
        );
      case 'advanced_study_modes':
        return _FeatureInfo(
          name: 'Advanced Study Modes',
          description:
              'Access Lectio Divina, Deep Study, and Sermon Outline modes for in-depth Bible study.',
          icon: Icons.auto_stories_rounded,
        );
      case 'reflections':
        return _FeatureInfo(
          name: 'Personal Reflections',
          description:
              'Record and review your spiritual insights and personal study notes.',
          icon: Icons.edit_note_rounded,
        );
      case 'achievements':
        return _FeatureInfo(
          name: 'Achievements',
          description:
              'Earn badges and track your spiritual growth milestones.',
          icon: Icons.emoji_events_rounded,
        );
      case 'leaderboard':
        return _FeatureInfo(
          name: 'Leaderboard',
          description: 'Compare your study progress with the community.',
          icon: Icons.leaderboard_rounded,
        );
      case 'offline_mode':
        return _FeatureInfo(
          name: 'Offline Mode',
          description:
              'Download study guides and access them without internet connection.',
          icon: Icons.cloud_off_rounded,
        );
      case 'custom_topics':
        return _FeatureInfo(
          name: 'Custom Topics',
          description:
              'Create personalized study guides on any Bible topic you choose.',
          icon: Icons.create_rounded,
        );
      case 'advanced_search':
        return _FeatureInfo(
          name: 'Advanced Search',
          description:
              'Search Scripture with powerful filters and advanced query options.',
          icon: Icons.search_rounded,
        );
      case 'export_share':
        return _FeatureInfo(
          name: 'Export & Share',
          description:
              'Export study guides as PDF and share with your study group.',
          icon: Icons.share_rounded,
        );
      case 'daily_verse_plus':
        return _FeatureInfo(
          name: 'Daily Verse Plus',
          description:
              'Get enhanced daily verses with deeper insights and commentary.',
          icon: Icons.today_rounded,
        );
      case 'deep_dive_mode':
        return _FeatureInfo(
          name: 'Deep Dive Mode',
          description:
              'Comprehensive 30-40 minute study with in-depth theological analysis and practical application.',
          icon: Icons.scuba_diving_rounded,
        );
      case 'lectio_divina_mode':
        return _FeatureInfo(
          name: 'Lectio Divina Mode',
          description:
              'Ancient contemplative practice of Scripture reading, meditation, prayer, and contemplation.',
          icon: Icons.spa_rounded,
        );
      case 'sermon_outline_mode':
        return _FeatureInfo(
          name: 'Sermon Outline Mode',
          description:
              'Structured sermon preparation with exposition, illustrations, and applications.',
          icon: Icons.forum_rounded,
        );
      case 'quick_read_mode':
        return _FeatureInfo(
          name: 'Quick Read Mode',
          description:
              'Brief 5-10 minute overview with key insights and takeaways.',
          icon: Icons.flash_on_rounded,
        );
      case 'standard_study_mode':
        return _FeatureInfo(
          name: 'Standard Study Mode',
          description:
              'Balanced 15-20 minute study with context, explanation, and reflection.',
          icon: Icons.book_rounded,
        );
      case 'voice_buddy':
        return _FeatureInfo(
          name: 'Voice Buddy',
          description:
              'Listen to your study guides with natural text-to-speech narration.',
          icon: Icons.volume_up_rounded,
        );
      case 'study_chat':
        return _FeatureInfo(
          name: 'Study Chat',
          description:
              'Ask follow-up questions and dive deeper into your study topics.',
          icon: Icons.chat_bubble_rounded,
        );
      case 'daily_verse':
        return _FeatureInfo(
          name: 'Daily Verse',
          description:
              'Start each day with an inspiring Bible verse and reflection.',
          icon: Icons.today_rounded,
        );
      default:
        return _FeatureInfo(
          name: 'Premium Feature',
          description: 'Unlock this feature by upgrading your plan.',
          icon: Icons.lock_rounded,
        );
    }
  }
}

class _FeatureInfo {
  final String name;
  final String description;
  final IconData icon;

  _FeatureInfo({
    required this.name,
    required this.description,
    required this.icon,
  });
}
