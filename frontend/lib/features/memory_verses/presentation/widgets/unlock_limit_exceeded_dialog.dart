import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/pricing_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/practice_limit_popup_parts.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

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

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final unlockedModeNames =
        unlockedModes.map((m) => practiceModeLabel(context, m)).toList();

    return PopupDialog(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopupHeader(
          icon: const PopupIconCircle(icon: Icons.lock_clock_outlined),
          title: context.tr(TranslationKeys.practiceUnlockLimitTitle),
          body: context.tr(
            unlockedCount == 1
                ? TranslationKeys.practiceUnlockLimitMessageOne
                : TranslationKeys.practiceUnlockLimitMessageOther,
            {'count': '$unlockedCount', 'verse': verseReference},
          ),
        ),
        const SizedBox(height: 18),
        PopupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PracticePopupSubheading(
                context.tr(TranslationKeys.practiceUnlockLimitUnlockedToday),
                trailing: Text(
                  '$unlockedCount / $limit',
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.accentIcon,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (unlockedModeNames.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...practicePopupSpaced(
                  [
                    for (final name in unlockedModeNames) PracticeCheckRow(name)
                  ],
                  gap: 6,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PracticePopupSubheading(
          context.tr(TranslationKeys.practiceUnlockLimitUpgradePrompt),
        ),
        const SizedBox(height: 10),
        PopupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: practicePopupSpaced(_buildDynamicPlanOptions(context)),
          ),
        ),
        const SizedBox(height: 14),
        PracticePopupNote(
          context.tr(TranslationKeys.practiceUnlockLimitStillPractice),
        ),
        const SizedBox(height: 20),
        PopupPrimaryButton(
          key: const Key('unlock_limit_view_plans'),
          label: context.tr(TranslationKeys.practiceUnlockLimitViewPlans),
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
          key: const Key('unlock_limit_later'),
          label: context.tr(TranslationKeys.practiceUnlockLimitMaybeLater),
          onPressed: () => Navigator.of(context).pop(),
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
              unlockLimitLabel(context, 2),
              pricingService.getFormattedPricePerMonth('standard'),
              tier == 'free'),
          _buildPlanOption(
              context,
              'Plus',
              unlockLimitLabel(context, 3),
              pricingService.getFormattedPricePerMonth('plus'),
              tier == 'free' || tier == 'standard'),
          _buildPlanOption(context, 'Premium', unlockLimitLabel(context, -1),
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
          unlockLimitLabel(context, tierInfo.unlockLimit),
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
          unlockLimitLabel(context, 2),
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
    return PracticePlanRow(
      name: name,
      description: modes,
      price: price,
      highlighted: isUpgrade,
    );
  }
}
