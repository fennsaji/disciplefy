import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/shared/widgets/v2_popup.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/plan_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

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
    final palette = ReaderPalette.of(context);
    final featureInfo = _getFeatureInfo(featureKey);

    return PopupSheet(
      children: [
        PopupHeader(
          icon: PopupIconCircle(icon: featureInfo.icon),
          eyebrow: context.tr(TranslationKeys.popupUpgradeEyebrow),
          title: featureInfo.name,
          body: featureInfo.description,
        ),
        const SizedBox(height: 20),
        PopupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: palette.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr(TranslationKeys.popupYourPlan,
                          {'plan': _formatPlanName(currentPlan)}),
                      style: AppFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: palette.text,
                      ),
                    ),
                  ),
                ],
              ),
              if (requiredPlans.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: palette.hairline),
                const SizedBox(height: 12),
                Text(
                  context.tr(TranslationKeys.popupAvailableOn),
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: requiredPlans.map((plan) {
                    final planColor = planAccentFromName(context, plan);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: planColor.withValues(
                            alpha: palette.isDark ? 0.16 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatPlanName(plan),
                        style: AppFonts.inter(
                          color: planColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        PopupPrimaryButton(
          key: const Key('upgrade_dialog_upgrade'),
          label: context.tr(TranslationKeys.popupUpgradeNow),
          icon: Icons.arrow_forward_rounded,
          onPressed: () {
            Navigator.pop(context);
            // Fall back to the cheapest qualifying plan when the caller
            // didn't name one, so the pricing page always has something to
            // scroll to.
            _navigateToSubscription(
              context,
              upgradePlan ??
                  (requiredPlans.isNotEmpty ? requiredPlans.first : null),
            );
          },
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          key: const Key('upgrade_dialog_later'),
          label: context.tr(TranslationKeys.popupMaybeLater),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _navigateToSubscription(BuildContext context, String? targetPlan) {
    // Navigate to pricing page with target plan pre-selected
    context.push(AppRoutes.pricing, extra: {'preselectedPlan': targetPlan});
  }

  String _formatPlanName(String plan) {
    if (plan.isEmpty) return plan;
    return plan[0].toUpperCase() + plan.substring(1);
  }

  _FeatureInfo _getFeatureInfo(String featureKey) {
    switch (featureKey) {
      case 'ai_discipler':
        return _FeatureInfo(
          name: 'Discipler',
          description:
              'Have natural voice conversations about Bible topics with your Bible companion.',
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
          // Matches the control's own label and the feature flag's name.
          name: 'Listen',
          description:
              'Listen to your study guides with natural text-to-speech narration.',
          icon: Icons.volume_up_rounded,
        );
      case 'create_fellowship':
        return _FeatureInfo(
          name: 'Create Fellowship',
          description:
              'Start your own group, invite members, and lead them through a study path.',
          icon: Icons.groups_2_rounded,
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
