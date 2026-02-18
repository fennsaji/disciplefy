import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/services/pricing_service.dart';
import '../../models/memory_verse_config.dart';

/// Dialog shown when user attempts to use a practice mode not available in their tier.
/// Displays tier restriction info and upgrade options.
/// Uses dynamic config from database instead of hardcoded values.
class TierLockedModeDialog extends StatelessWidget {
  final String mode;
  final String currentTier;
  final List<String> availableModes;
  final String requiredTier;
  final String message;

  const TierLockedModeDialog({
    super.key,
    required this.mode,
    required this.currentTier,
    required this.availableModes,
    required this.requiredTier,
    required this.message,
  });

  /// Show the tier-locked mode dialog.
  static void show(
    BuildContext context, {
    required String mode,
    required String currentTier,
    required List<String> availableModes,
    required String requiredTier,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => TierLockedModeDialog(
        mode: mode,
        currentTier: currentTier,
        availableModes: availableModes,
        requiredTier: requiredTier,
        message: message,
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

  String _getTierDisplayName(String tier) {
    return tier.substring(0, 1).toUpperCase() + tier.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modeName = _getModeName(mode);
    final currentTierName = _getTierDisplayName(currentTier);
    final availableModeNames =
        availableModes.map((m) => _getModeName(m)).toList();

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
              message,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),

            // Current plan includes box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your $currentTierName Plan Includes:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...availableModeNames.map((name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.tertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              name,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Unlock advanced practice modes with:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildDynamicPlanOptions(context),
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
            Navigator.pushNamed(context, AppRoutes.pricing);
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
            'All 8 practice modes + 2 unlocks per verse per day',
            pricingService.getFormattedPricePerMonth('standard'),
          ),
          _buildPlanOption(
            context,
            'Plus',
            'All 8 practice modes + 3 unlocks per verse per day',
            pricingService.getFormattedPricePerMonth('plus'),
          ),
          _buildPlanOption(
            context,
            'Premium',
            'All 8 practice modes + unlimited practice',
            pricingService.getFormattedPricePerMonth('premium'),
          ),
        ];
      }

      final tierComparison = memoryConfig.getTierComparison();

      final upgradeTiers = tierComparison
          .where((t) => t.tier != 'free' && t.tier != currentTier.toLowerCase())
          .toList();

      return upgradeTiers.map((tier) {
        return _buildPlanOption(
          context,
          tier.tierName,
          'All ${tier.modeCount} practice modes + ${tier.unlockLimitText}',
          pricingService.getFormattedPricePerMonth(tier.tier),
        );
      }).toList();
    } catch (e) {
      final pricingService = sl<PricingService>();
      return [
        _buildPlanOption(
          context,
          'Standard',
          'All 8 practice modes + 2 unlocks per verse per day',
          pricingService.getFormattedPricePerMonth('standard'),
        ),
      ];
    }
  }

  Widget _buildPlanOption(
    BuildContext context,
    String name,
    String description,
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
                  TextSpan(text: '$description '),
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
