import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../../shared/widgets/popup.dart';
import '../../../tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';

/// Daily credit allowance per plan, mirroring `subscription_plans.daily_tokens`
/// in the database.
///
/// These were previously written inline as literals and went stale: migration
/// 20260319000004 raised standard 20→40 and plus 50→60, but this dialog kept
/// advertising the old numbers, understating both paid tiers on the screen
/// users see when deciding whether to upgrade. `plan_daily_credits_test.dart`
/// pins this map to that migration.
const Map<String, int> kPlanDailyCredits = {
  'free': 15,
  'standard': 40,
  'plus': 60,
};

/// Dialog shown when user has insufficient tokens to generate a study guide.
///
/// Displays current token balance vs required cost, plan upgrade options,
/// and navigation to the pricing or token purchase page.
class InsufficientTokensDialog extends StatelessWidget {
  final TokenStatus tokenStatus;

  /// The number of tokens required for this operation (if known).
  final int? requiredTokens;

  const InsufficientTokensDialog({
    super.key,
    required this.tokenStatus,
    this.requiredTokens,
  });

  /// Show the insufficient tokens dialog as a modal.
  static Future<void> show(
    BuildContext context, {
    required TokenStatus tokenStatus,
    int? requiredTokens,
  }) {
    ActivationAnalytics.maybeTrack(NuxEvent.creditWarningShown, {
      if (requiredTokens != null) 'needed': requiredTokens,
      'have': tokenStatus.totalTokens,
    });
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => InsufficientTokensDialog(
        tokenStatus: tokenStatus,
        requiredTokens: requiredTokens,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupDialog(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopupHeader(
          icon: const PopupIconCircle(icon: Icons.toll_outlined),
          eyebrow: context.tr(TranslationKeys.popupCreditsEyebrow),
          title: context.tr(TranslationKeys.tokenDialogTitle),
          body: context.tr(TranslationKeys.tokenDialogSubtitle),
        ),
        const SizedBox(height: 20),
        _buildTokenBalance(context),
        const SizedBox(height: 16),
        _buildUpgradePlans(context),
        const SizedBox(height: 14),
        _buildInfo(context),
        const SizedBox(height: 20),
        PopupPrimaryButton(
          key: const Key('insufficient_tokens_view_plans'),
          label: context.tr(TranslationKeys.tokenDialogViewPlans),
          onPressed: () {
            Navigator.of(context).pop();
            // Land on the cheapest plan that lifts this limit, not the top of
            // the page where Free — the plan they already have — sits.
            GoRouter.of(context).push(AppRoutes.pricing,
                extra: const {'preselectedPlan': 'standard'});
          },
        ),
        if (tokenStatus.canPurchaseTokens) ...[
          const SizedBox(height: 8),
          _buildPurchaseTokensButton(context),
        ],
        const SizedBox(height: 4),
        PopupTextButton(
          key: const Key('insufficient_tokens_later'),
          label: context.tr(TranslationKeys.tokenDialogMaybeLater),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTokenBalance(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final unit = context.tr(TranslationKeys.tokenDialogCreditsUnit);
    Widget row(String label, String value, Color valueColor) => Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppFonts.inter(fontSize: 13.5, color: palette.muted),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: AppFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        );

    return PopupPanel(
      child: Column(
        children: [
          row(
            context.tr(TranslationKeys.tokenDialogYourCredits),
            '${tokenStatus.totalTokens} $unit',
            AppColors.error,
          ),
          if (requiredTokens != null) ...[
            const SizedBox(height: 8),
            row(
              context.tr(TranslationKeys.tokenDialogNeeded),
              '$requiredTokens $unit',
              palette.text,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpgradePlans(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.tokenDialogGetMore),
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 10),
        _buildPlanRow(
          context,
          label: 'Standard',
          detail: context.tr(TranslationKeys.tokenDialogPlanCreditsPerDay, {
            'credits': kPlanDailyCredits['standard'],
            'price': 79,
          }),
        ),
        const SizedBox(height: 8),
        _buildPlanRow(
          context,
          label: 'Plus',
          detail: context.tr(TranslationKeys.tokenDialogPlanCreditsPerDay, {
            'credits': kPlanDailyCredits['plus'],
            'price': 149,
          }),
        ),
        const SizedBox(height: 8),
        _buildPlanRow(
          context,
          label: 'Premium',
          detail: context
              .tr(TranslationKeys.tokenDialogPlanUnlimited, {'price': 499}),
        ),
      ],
    );
  }

  Widget _buildPlanRow(
    BuildContext context, {
    required String label,
    required String detail,
  }) {
    final palette = ReaderPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: palette.accentIcon,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Expanded so the plan line wraps instead of running past the dialog.
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
                TextSpan(
                  text: detail,
                  style: AppFonts.inter(fontSize: 13, color: palette.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: palette.dim),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(TranslationKeys.tokenDialogInfoBox),
            style: AppFonts.inter(
              fontSize: 12.5,
              color: palette.muted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseTokensButton(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: const Key('insufficient_tokens_purchase'),
        onPressed: () {
          Navigator.of(context).pop();
          GoRouter.of(context)
              .push(AppRoutes.tokenPurchase, extra: tokenStatus);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          side: BorderSide(color: palette.outline),
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
        ),
        child: Text(
          context.tr(TranslationKeys.tokenDialogPurchase),
          textAlign: TextAlign.center,
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.text,
          ),
        ),
      ),
    );
  }
}
