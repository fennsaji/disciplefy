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

  String _getTierDisplayName(String tier) {
    if (tier.isEmpty) return tier;
    return tier.substring(0, 1).toUpperCase() + tier.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final currentTierName = _getTierDisplayName(currentTier);
    final availableModeNames =
        availableModes.map((m) => practiceModeLabel(context, m)).toList();

    return PopupDialog(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopupHeader(
          icon: const PopupIconCircle(icon: Icons.lock_outline_rounded),
          eyebrow: practiceModeLabel(context, mode),
          title: context.tr(TranslationKeys.practiceTierLockedTitle),
          body: message,
        ),
        const SizedBox(height: 18),
        PopupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PracticePopupSubheading(
                context.tr(TranslationKeys.practiceTierLockedPlanIncludes,
                    {'plan': currentTierName}),
              ),
              if (availableModeNames.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...practicePopupSpaced(
                  [
                    for (final name in availableModeNames)
                      PracticeCheckRow(name)
                  ],
                  gap: 6,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PracticePopupSubheading(
          context.tr(TranslationKeys.practiceTierLockedUnlockWith),
        ),
        const SizedBox(height: 10),
        PopupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: practicePopupSpaced(_buildDynamicPlanOptions(context)),
          ),
        ),
        const SizedBox(height: 20),
        PopupPrimaryButton(
          key: const Key('tier_locked_upgrade'),
          label: context.tr(TranslationKeys.practiceTierLockedUpgradeNow),
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            // Standard is the cheapest tier that unlocks the locked modes.
            router.push(
              AppRoutes.pricing,
              extra: {'preselectedPlan': 'standard'},
            );
          },
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          key: const Key('tier_locked_later'),
          label: context.tr(TranslationKeys.practiceTierLockedMaybeLater),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// "All 8 practice modes + 2 modes per verse per day", or "+ unlimited
  /// practice" when [unlockLimit] is -1.
  String _plansLine(BuildContext context, int modeCount, int unlockLimit) {
    if (unlockLimit < 0) {
      return context.tr(TranslationKeys.practiceTierLockedAllModesUnlimited,
          {'count': '$modeCount'});
    }
    return context.tr(TranslationKeys.practiceTierLockedAllModesPlus, {
      'count': '$modeCount',
      'limit': unlockLimitLabel(context, unlockLimit),
    });
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
            _plansLine(context, 8, 2),
            pricingService.getFormattedPricePerMonth('standard'),
          ),
          _buildPlanOption(
            context,
            'Plus',
            _plansLine(context, 8, 3),
            pricingService.getFormattedPricePerMonth('plus'),
          ),
          _buildPlanOption(
            context,
            'Premium',
            _plansLine(context, 8, -1),
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
          _plansLine(context, tier.modeCount, tier.unlockLimit),
          pricingService.getFormattedPricePerMonth(tier.tier),
        );
      }).toList();
    } catch (e) {
      final pricingService = sl<PricingService>();
      return [
        _buildPlanOption(
          context,
          'Standard',
          _plansLine(context, 8, 2),
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
    return PracticePlanRow(name: name, description: description, price: price);
  }
}
