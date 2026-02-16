import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/services/pricing_service.dart';
import '../../models/memory_verse_config.dart';

/// Dialog shown when user attempts to use a practice mode not available in their tier.
/// Displays tier restriction info and upgrade options.
/// Now uses dynamic config from database instead of hardcoded values.
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
  String _getModeName(String mode) {
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
    return modeNames[mode] ?? mode;
  }

  String _getTierDisplayName(String tier) {
    return tier.substring(0, 1).toUpperCase() + tier.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modeName = _getModeName(mode);
    final currentTierName = _getTierDisplayName(currentTier);

    // Convert available mode slugs to readable names
    final availableModeNames =
        availableModes.map((m) => _getModeName(m)).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Upgrade Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Your $currentTierName Plan Includes:',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...availableModeNames.map((modeName) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              modeName,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unlock advanced practice modes with:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._buildDynamicPlanOptions(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.pushNamed(context, AppRoutes.pricing);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Upgrade Now'),
        ),
      ],
    );
  }

  /// Build plan options dynamically from system config
  List<Widget> _buildDynamicPlanOptions(BuildContext context) {
    try {
      final systemConfig = sl<SystemConfigService>();
      final memoryConfig = systemConfig.config?.memoryVerseConfig;

      if (memoryConfig == null) {
        // Fallback to database pricing if config not available
        final pricingService = sl<PricingService>();
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
            'All modes unlocked automatically + unlimited practice',
            pricingService.getFormattedPricePerMonth('premium'),
          ),
        ];
      }

      final tierComparison = memoryConfig.getTierComparison();

      // Filter out free tier and current tier
      final upgradeTiers = tierComparison
          .where((t) => t.tier != 'free' && t.tier != currentTier.toLowerCase())
          .toList();

      final pricingService = sl<PricingService>();

      return upgradeTiers.map((tier) {
        final modeCount = tier.modeCount;
        final unlockText = tier.unlockLimitText;
        final price = pricingService.getFormattedPricePerMonth(tier.tier);

        return _buildPlanOption(
          context,
          tier.tierName,
          'All $modeCount practice modes + $unlockText',
          price,
        );
      }).toList();
    } catch (e) {
      // Fallback on error
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.upgrade, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '$description '),
                  TextSpan(
                    text: '($price)',
                    style: TextStyle(color: Colors.grey[600]),
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
