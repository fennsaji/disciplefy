import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/pricing_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Dialog shown when user exceeds their monthly voice conversation limit.
/// Displays current usage, upgrade options, and navigation to pricing page.
class MonthlyLimitExceededDialog extends StatelessWidget {
  final int conversationsUsed;
  final int limit;
  final String tier;
  final String month;

  const MonthlyLimitExceededDialog({
    super.key,
    required this.conversationsUsed,
    required this.limit,
    required this.tier,
    required this.month,
  });

  /// Show the monthly limit exceeded dialog.
  static void show(
    BuildContext context, {
    required int conversationsUsed,
    required int limit,
    required String tier,
    required String month,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MonthlyLimitExceededDialog(
        conversationsUsed: conversationsUsed,
        limit: limit,
        tier: tier,
        month: month,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final pricingService = sl<PricingService>();
    final progress =
        limit <= 0 ? 1.0 : (conversationsUsed / limit).clamp(0.0, 1.0);

    return PopupDialog(
      children: [
        PopupHeader(
          icon: const PopupIconCircle(
            icon: Icons.forum_outlined,
            tone: PopupTone.gold,
          ),
          title: context.tr('voice_buddy.quota_exceeded.title'),
          body: context.tr(
            limit == 1
                ? TranslationKeys.voiceLimitMessageOne
                : TranslationKeys.voiceLimitMessageOther,
            {'limit': limit},
          ),
        ),
        const SizedBox(height: 18),

        // Usage this month
        PopupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    context.tr(TranslationKeys.voiceLimitThisMonth),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  Text(
                    context.tr(TranslationKeys.voiceLimitUsed, {
                      'used': conversationsUsed,
                      'limit': limit,
                    }),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: palette.gold,
                  backgroundColor: palette.hairline,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Plans that include more conversations
        PopupPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(TranslationKeys.voiceLimitUpgradeHeading),
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              _PlanOption(
                name: 'Standard',
                conversations: pricingService.getVoiceQuotaLabel('standard'),
                price: pricingService.getFormattedPricePerMonth('standard'),
              ),
              _PlanOption(
                name: 'Plus',
                conversations: pricingService.getVoiceQuotaLabel('plus'),
                price: pricingService.getFormattedPricePerMonth('plus'),
              ),
              _PlanOption(
                name: 'Premium',
                conversations: pricingService.getVoiceQuotaLabel('premium'),
                price: pricingService.getFormattedPricePerMonth('premium'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        PopupPrimaryButton(
          label: context.tr(TranslationKeys.voiceLimitViewPlans),
          icon: Icons.workspace_premium_outlined,
          onPressed: () {
            Navigator.of(context).pop();
            // go_router owns navigation here; Navigator.pushNamed has no
            // named-route table to resolve against, so this CTA did nothing.
            // Targets the next tier up from the exhausted one.
            context.push(
              AppRoutes.pricing,
              extra: {'preselectedPlan': tier == 'plus' ? 'premium' : 'plus'},
            );
          },
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          label: context.tr(TranslationKeys.voiceLimitMaybeLater),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// One plan line: check, bold plan name, its voice allowance and price.
class _PlanOption extends StatelessWidget {
  final String name;
  final String conversations;
  final String price;

  const _PlanOption({
    required this.name,
    required this.conversations,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final green = SettingsToneColors.of(context, SettingsTone.green);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle, color: green.foreground, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppFonts.inter(
                  fontSize: 13,
                  color: palette.text,
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '$conversations '),
                  TextSpan(
                    text: '($price)',
                    style: TextStyle(color: palette.muted),
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
