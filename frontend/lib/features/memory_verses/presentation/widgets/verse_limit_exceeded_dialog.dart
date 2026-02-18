import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/services/pricing_service.dart';
import '../../models/memory_verse_config.dart';

/// Dialog shown when user has reached their memory verse limit for their plan.
///
/// Displays:
/// - Current plan's verse limit
/// - Upgrade options with verse limits and pricing
/// - "Maybe Later" and "Upgrade Now" actions
class VerseLimitExceededDialog extends StatelessWidget {
  final String currentTier;

  const VerseLimitExceededDialog({
    super.key,
    required this.currentTier,
  });

  static void show(
    BuildContext context, {
    required String currentTier,
  }) {
    showDialog(
      context: context,
      builder: (context) => VerseLimitExceededDialog(
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
    final currentVerseLimit = _getVerseLimitText(currentTier);

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
              Icons.lock,
              color: theme.colorScheme.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upgrade Required',
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
              'You\'ve reached your memory verse limit on the $currentTierName plan. Upgrade to memorize more Scripture.',
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
                      'Your $currentTierName Plan: $currentVerseLimit',
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
              'Get more verses with:',
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
            'Maybe Later',
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
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Upgrade Now'),
        ),
      ],
    );
  }

  String _getVerseLimitText(String tier) {
    try {
      final systemConfig = sl<SystemConfigService>();
      final memoryConfig = systemConfig.config?.memoryVerseConfig;
      if (memoryConfig != null) {
        return memoryConfig.getVerseLimitText(tier);
      }
    } catch (_) {}
    // Fallback defaults
    switch (tier.toLowerCase()) {
      case 'free':
        return '3 active verses';
      case 'standard':
        return '5 active verses';
      case 'plus':
        return '10 active verses';
      case 'premium':
        return 'Unlimited verses';
      default:
        return 'Limited verses';
    }
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
    try {
      final pricingService = sl<PricingService>();
      return [
        _buildPlanOption(context, 'Plus', '10 active verses',
            pricingService.getFormattedPricePerMonth('plus')),
        _buildPlanOption(context, 'Premium', 'Unlimited verses',
            pricingService.getFormattedPricePerMonth('premium')),
      ];
    } catch (_) {
      return [
        _buildPlanOption(context, 'Plus', '10 active verses', ''),
        _buildPlanOption(context, 'Premium', 'Unlimited verses', ''),
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
