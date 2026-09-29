import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/pricing_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/models/memory_verse_config.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/practice_limit_popup_parts.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Dialog shown when user has reached their daily verse review limit for their plan.
///
/// Displays:
/// - Current plan's daily review limit
/// - Upgrade options with daily review limits and pricing
/// - "Maybe Later" and "Upgrade Now" actions
class DailyReviewLimitDialog extends StatelessWidget {
  final String currentTier;

  const DailyReviewLimitDialog({
    super.key,
    required this.currentTier,
  });

  static void show(
    BuildContext context, {
    required String currentTier,
  }) {
    showDialog(
      context: context,
      builder: (context) => DailyReviewLimitDialog(
        currentTier: currentTier,
      ),
    );
  }

  String _getTierDisplayName(String tier) {
    return tier.substring(0, 1).toUpperCase() + tier.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final currentTierName = _getTierDisplayName(currentTier);
    final currentReviewLimit = _getDailyReviewLimitText(context, currentTier);

    return PopupDialog(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopupHeader(
          icon: const PopupIconCircle(icon: Icons.schedule_rounded),
          title: context.tr(TranslationKeys.dailyReviewLimitTitle),
          body: context.tr(TranslationKeys.dailyReviewLimitMessage, {
            'plan': currentTierName,
          }),
        ),
        const SizedBox(height: 18),
        PopupPanel(
          child: PracticePopupNote(
            context.tr(TranslationKeys.dailyReviewLimitCurrentPlan, {
              'plan': currentTierName,
              'limit': currentReviewLimit,
            }),
          ),
        ),
        const SizedBox(height: 16),
        PracticePopupSubheading(
          context.tr(TranslationKeys.dailyReviewLimitGetMore),
        ),
        const SizedBox(height: 10),
        PopupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: practicePopupSpaced(_buildUpgradePlanOptions(context)),
          ),
        ),
        const SizedBox(height: 20),
        PopupPrimaryButton(
          key: const Key('daily_review_limit_upgrade'),
          label: context.tr(TranslationKeys.dailyReviewLimitUpgradeNow),
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            // Land on the cheapest plan that lifts this limit, not the top of the
            // page where Free — the plan they already have — sits.
            router.push(AppRoutes.pricing,
                extra: const {'preselectedPlan': 'standard'});
          },
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          key: const Key('daily_review_limit_later'),
          label: context.tr(TranslationKeys.dailyReviewLimitMaybeLater),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  String _getDailyReviewLimitText(BuildContext context, String tier) {
    try {
      final systemConfig = sl<SystemConfigService>();
      final memoryConfig = systemConfig.config?.memoryVerseConfig;
      if (memoryConfig != null) {
        return dailyReviewLimitLabel(
            context, memoryConfig.getVerseLimitForTier(tier));
      }
    } catch (_) {}
    // Fallback defaults
    final tierLower = tier.toLowerCase();
    final Map<String, int> fallbackLimits = {
      'free': 3,
      'standard': 5,
      'plus': 10,
    };
    if (tierLower == 'premium') {
      return context.tr(TranslationKeys.dailyReviewLimitUnlimited);
    }
    final count = fallbackLimits[tierLower];
    if (count != null) {
      return context.tr(TranslationKeys.dailyReviewLimitCount, {
        'count': count.toString(),
      });
    }
    return context.tr(TranslationKeys.dailyReviewLimitLimited);
  }

  List<Widget> _buildUpgradePlanOptions(BuildContext context) {
    try {
      final systemConfig = sl<SystemConfigService>();
      final memoryConfig = systemConfig.config?.memoryVerseConfig;
      final pricingService = sl<PricingService>();

      if (memoryConfig == null) {
        return _buildFallbackOptions(context);
      }

      final tierComparison = memoryConfig.getTierComparison();
      final upgradeTiers = tierComparison
          .where((t) => t.tier != 'free' && t.tier != currentTier.toLowerCase())
          .toList();

      return upgradeTiers.map((tier) {
        return _buildPlanOption(
          context,
          tier.tierName,
          dailyReviewLimitLabel(context, tier.verseLimit),
          pricingService.getFormattedPricePerMonth(tier.tier),
        );
      }).toList();
    } catch (_) {
      return _buildFallbackOptions(context);
    }
  }

  List<Widget> _buildFallbackOptions(BuildContext context) {
    final plusLimit = context.tr(TranslationKeys.dailyReviewLimitCount, {
      'count': '10',
    });
    final premiumLimit = context.tr(TranslationKeys.dailyReviewLimitUnlimited);
    try {
      final pricingService = sl<PricingService>();
      return [
        _buildPlanOption(context, 'Plus', plusLimit,
            pricingService.getFormattedPricePerMonth('plus')),
        _buildPlanOption(context, 'Premium', premiumLimit,
            pricingService.getFormattedPricePerMonth('premium')),
      ];
    } catch (_) {
      return [
        _buildPlanOption(context, 'Plus', plusLimit, ''),
        _buildPlanOption(context, 'Premium', premiumLimit, ''),
      ];
    }
  }

  Widget _buildPlanOption(
    BuildContext context,
    String name,
    String verseLimitText,
    String price,
  ) {
    return PracticePlanRow(
      name: name,
      description: verseLimitText,
      price: price,
    );
  }
}
