import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/services/pricing_service.dart';

/// Dialog shown when user exceeds their daily practice mode unlock limit for a verse.
/// Displays unlocked modes, remaining slots, and upgrade options.
/// Uses dynamic config from database instead of hardcoded values.
class UnlockLimitExceededDialog extends StatelessWidget {
  final List<String> unlockedModes;
  final int unlockedCount;
  final int limit;
  final String tier;
  final String verseReference;

  const UnlockLimitExceededDialog({
    super.key,
    required this.unlockedModes,
    required this.unlockedCount,
    required this.limit,
    required this.tier,
    required this.verseReference,
  });

  /// Show the unlock limit exceeded dialog.
  static void show(
    BuildContext context, {
    required List<String> unlockedModes,
    required int unlockedCount,
    required int limit,
    required String tier,
    required String verseReference,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnlockLimitExceededDialog(
        unlockedModes: unlockedModes,
        unlockedCount: unlockedCount,
        limit: limit,
        tier: tier,
        verseReference: verseReference,
      ),
    );
  }

  /// Get user-friendly mode names
  String _getModeName(String modeSlug) {
    const modeNames = {
      'flip_card': 'Flip Card',
      'type_it_out': 'Type It Out',
      'cloze': 'Cloze Practice',
      'first_letter': 'First Letter',
      'progressive': 'Progressive Reveal',
      'word_scramble': 'Word Scramble',
      'word_bank': 'Word Bank',
      'audio': 'Audio Practice',
    };
    return modeNames[modeSlug] ?? modeSlug;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlockedModeNames =
        unlockedModes.map((m) => _getModeName(m)).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: theme.colorScheme.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_clock,
              color: theme.colorScheme.tertiary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Daily Unlock Limit Reached',
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
              'You\'ve unlocked $unlockedCount practice mode${unlockedCount > 1 ? 's' : ''} for "$verseReference" today.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Unlocked modes box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modes Unlocked Today:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$unlockedCount / $limit',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...unlockedModeNames.map((name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.tertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(name, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Upgrade to unlock more modes per verse per day:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildDynamicPlanOptions(context),
            const SizedBox(height: 8),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
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
                      'You can still practice unlimited times with your unlocked modes today!',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
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
            Navigator.of(context).pop();
            context.push(AppRoutes.pricing);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('View Plans'),
        ),
      ],
    );
  }

  /// Build plan options dynamically from system config (DB-driven)
  List<Widget> _buildDynamicPlanOptions(BuildContext context) {
    try {
      final systemConfig = sl<SystemConfigService>();
      final memoryConfig = systemConfig.config?.memoryVerseConfig;
      final pricingService = sl<PricingService>();

      if (memoryConfig == null) {
        return [
          _buildPlanOption(
              context,
              'Standard',
              '2 modes per verse per day',
              pricingService.getFormattedPricePerMonth('standard'),
              tier == 'free'),
          _buildPlanOption(
              context,
              'Plus',
              '3 modes per verse per day',
              pricingService.getFormattedPricePerMonth('plus'),
              tier == 'free' || tier == 'standard'),
          _buildPlanOption(context, 'Premium', 'All modes unlocked',
              pricingService.getFormattedPricePerMonth('premium'), true),
        ];
      }

      final tierComparison = memoryConfig.getTierComparison();
      final currentTierLower = tier.toLowerCase();

      return tierComparison.where((t) => t.tier != 'free').map((tierInfo) {
        final isUpgrade = _shouldShowAsUpgrade(currentTierLower, tierInfo.tier);
        return _buildPlanOption(
          context,
          tierInfo.tierName,
          tierInfo.unlockLimitText,
          pricingService.getFormattedPricePerMonth(tierInfo.tier),
          isUpgrade,
        );
      }).toList();
    } catch (e) {
      final pricingService = sl<PricingService>();
      return [
        _buildPlanOption(
          context,
          'Standard',
          '2 modes per verse per day',
          pricingService.getFormattedPricePerMonth('standard'),
          true,
        ),
      ];
    }
  }

  bool _shouldShowAsUpgrade(String currentTier, String targetTier) {
    const tierOrder = ['free', 'standard', 'plus', 'premium'];
    return tierOrder.indexOf(targetTier) > tierOrder.indexOf(currentTier);
  }

  Widget _buildPlanOption(
    BuildContext context,
    String name,
    String modes,
    String price,
    bool isUpgrade,
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
              isUpgrade ? Icons.upgrade : Icons.circle_outlined,
              color: isUpgrade
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
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
                  TextSpan(text: '$modes '),
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
