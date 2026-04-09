import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/services/pricing_service.dart';
import '../../models/memory_verse_config.dart';

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
    final theme = Theme.of(context);
    final currentTierName = _getTierDisplayName(currentTier);
    final currentReviewLimit = _getDailyReviewLimitText(context, currentTier);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule,
              color: theme.colorScheme.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr(TranslationKeys.dailyReviewLimitTitle),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(TranslationKeys.dailyReviewLimitMessage, {
                'plan': currentTierName,
              }),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),

            // Current plan info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr(TranslationKeys.dailyReviewLimitCurrentPlan, {
                        'plan': currentTierName,
                        'limit': currentReviewLimit,
                      }),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              context.tr(TranslationKeys.dailyReviewLimitGetMore),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildUpgradePlanOptions(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.tr(TranslationKeys.dailyReviewLimitMaybeLater),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push(AppRoutes.pricing);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: context.appInteractive,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(context.tr(TranslationKeys.dailyReviewLimitUpgradeNow)),
        ),
      ],
    );
  }

  String _getDailyReviewLimitText(BuildContext context, String tier) {
    try {
      final systemConfig = sl<SystemConfigService>();
      final memoryConfig = systemConfig.config?.memoryVerseConfig;
      if (memoryConfig != null) {
        return memoryConfig.getVerseLimitText(tier);
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
          tier.verseLimitText,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.upgrade,
              color: theme.colorScheme.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '$verseLimitText '),
                  if (price.isNotEmpty)
                    TextSpan(
                      text: '($price)',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
