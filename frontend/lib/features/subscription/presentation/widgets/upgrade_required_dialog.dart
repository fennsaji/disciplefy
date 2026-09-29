import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/pricing_service.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/v2_popup.dart';

/// Reusable dialog for features that require a plan upgrade.
///
/// Shows when free plan users try to access Standard+ features like
/// Voice Buddy or Memory Verses.
class UpgradeRequiredDialog extends StatelessWidget {
  /// The name of the feature being accessed (e.g., "Voice Buddy", "Memory Verses")
  final String featureName;

  /// Icon representing the feature
  final IconData featureIcon;

  /// Description of what the feature does
  final String featureDescription;

  /// Callback when user chooses to upgrade
  final VoidCallback? onUpgrade;

  /// Callback when dialog is dismissed
  final VoidCallback? onDismiss;

  const UpgradeRequiredDialog({
    super.key,
    required this.featureName,
    required this.featureIcon,
    required this.featureDescription,
    this.onUpgrade,
    this.onDismiss,
  });

  /// Shows the upgrade required dialog as a modal
  static Future<bool?> show(
    BuildContext context, {
    required String featureName,
    required IconData featureIcon,
    required String featureDescription,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => UpgradeRequiredDialog(
        featureName: featureName,
        featureIcon: featureIcon,
        featureDescription: featureDescription,
        onUpgrade: () {
          Navigator.of(dialogContext).pop(true);
          // Navigate to subscription page
          context.push(AppRoutes.myPlan);
        },
        onDismiss: () {
          Navigator.of(dialogContext).pop(false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return PopupDialog(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopupHeader(
          icon: PopupIconCircle(icon: featureIcon),
          eyebrow: context.tr(TranslationKeys.upgradeDialogStandardPlan),
          title: context.tr(
            TranslationKeys.upgradeDialogTitle,
            {'feature': featureName},
          ),
          body: featureDescription,
        ),
        const SizedBox(height: 18),
        PopupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // The copy is "Just {price}" — the price was never passed, so
                // the placeholder used to show literally.
                context.tr(TranslationKeys.upgradeDialogPrice, {
                  'price': sl<PricingService>()
                      .getFormattedPricePerMonth('standard'),
                }),
                style: AppFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: palette.gold,
                ),
              ),
              const SizedBox(height: 10),
              _buildBenefitRow(
                context,
                Icons.mic_none_rounded,
                context.tr(TranslationKeys.upgradeDialogBenefitVoice),
              ),
              const SizedBox(height: 8),
              _buildBenefitRow(
                context,
                Icons.psychology_outlined,
                context.tr(TranslationKeys.upgradeDialogBenefitMemory),
              ),
              const SizedBox(height: 8),
              _buildBenefitRow(
                context,
                Icons.toll_outlined,
                context.tr(TranslationKeys.upgradeDialogBenefitTokens),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PopupPrimaryButton(
          key: const Key('upgrade_required_upgrade'),
          label: context.tr(TranslationKeys.upgradeDialogUpgradeButton),
          onPressed: onUpgrade,
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          key: const Key('upgrade_required_later'),
          label: context.tr(TranslationKeys.upgradeDialogMaybeLater),
          onPressed: onDismiss,
        ),
      ],
    );
  }

  Widget _buildBenefitRow(BuildContext context, IconData icon, String text) {
    final palette = ReaderPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: palette.accentIcon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppFonts.inter(
              fontSize: 13.5,
              color: palette.text,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
