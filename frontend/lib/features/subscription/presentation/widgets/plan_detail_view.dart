import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/utils/plan_features_extractor.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/subscription_legal_links.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// Shared layout of the Standard / Plus / Premium upgrade pages: big price,
/// a comparison table against the neighbouring plan, the feature list, the
/// promo code, legal links, and the CTA pinned at the bottom.
///
/// The pages keep all purchase logic; this widget only lays it out.
class PlanDetailView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onRefresh;
  final String refreshTooltip;

  /// Shows a spinner instead of the content.
  final bool loading;

  final String price;
  final String? originalPrice;

  /// Short gold line under the price (e.g. "Limited time offer").
  final String? offerText;
  final String? description;

  final String? previousPlanName;
  final String currentPlanName;
  final List<PlanComparisonRow> comparisonRows;

  final String featuresTitle;
  final List<String> features;

  /// Promo code input, or null where promo codes are not offered (iOS).
  final Widget? promo;

  /// Notices above the legal footer (e.g. "Completed payment? Tap refresh").
  final List<Widget> notices;

  /// Bottom action: the CTA, or a notice when the plan can't be bought.
  final Widget action;

  /// Restore purchases (stores that support it).
  final VoidCallback? onRestore;

  /// Tier colour for the compared plan's column (violet for Plus).
  final Color? accentColor;

  /// "By subscribing you agree…" line above the legal links.
  final String termsText;
  final String securePaymentText;

  const PlanDetailView({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.refreshTooltip,
    required this.loading,
    required this.price,
    required this.currentPlanName,
    required this.comparisonRows,
    required this.featuresTitle,
    required this.features,
    required this.action,
    required this.termsText,
    required this.securePaymentText,
    this.subtitle,
    this.originalPrice,
    this.offerText,
    this.description,
    this.previousPlanName,
    this.promo,
    this.notices = const [],
    this.onRestore,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: LedgerTopBar(
        title: title,
        subtitle: subtitle,
        actions: [
          LedgerBarAction(
            icon: Icons.refresh_rounded,
            tooltip: refreshTooltip,
            onPressed: onRefresh,
          ),
        ],
      ),
      body: loading
          ? const LedgerLoading()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _PriceHeader(
                        price: price,
                        originalPrice: originalPrice,
                        offerText: offerText,
                        description: description,
                      ),
                      const LedgerHairline(verticalMargin: 14),
                      if (comparisonRows.isNotEmpty) ...[
                        PlanComparisonTable(
                          previousPlanName: previousPlanName ?? '',
                          currentPlanName: currentPlanName,
                          rows: comparisonRows,
                          highlightColor: accentColor,
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (features.isNotEmpty) ...[
                        LedgerSectionLabel(featuresTitle),
                        for (final feature in features)
                          LedgerCheckRow(
                            feature,
                            included:
                                !feature.toLowerCase().contains('not included'),
                          ),
                      ],
                      if (promo != null) ...[
                        const SizedBox(height: 20),
                        promo!,
                      ],
                      for (final notice in notices) ...[
                        const SizedBox(height: 14),
                        notice,
                      ],
                      const SizedBox(height: 22),
                      Text(
                        termsText,
                        textAlign: TextAlign.center,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: palette.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SubscriptionLegalLinks(),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 14, color: palette.dim),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              securePaymentText,
                              textAlign: TextAlign.center,
                              style: AppFonts.inter(
                                  fontSize: 12, color: palette.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        action,
                        if (onRestore != null)
                          TextButton(
                            onPressed: onRestore,
                            style: TextButton.styleFrom(
                              foregroundColor: palette.muted,
                            ),
                            child: Text(
                              context
                                  .tr(TranslationKeys.ledgerRestorePurchases),
                              style: AppFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: palette.muted,
                              ),
                            ),
                          )
                        else ...[
                          const SizedBox(height: 8),
                          Text(
                            context.tr(TranslationKeys.ledgerRenewsNote),
                            textAlign: TextAlign.center,
                            style: AppFonts.inter(
                              fontSize: 12,
                              color: palette.dim,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  final String price;
  final String? originalPrice;
  final String? offerText;
  final String? description;

  const _PriceHeader({
    required this.price,
    this.originalPrice,
    this.offerText,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 6,
          children: [
            Text(
              '₹$price',
              style: AppFonts.poppins(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: palette.text,
                height: 1.1,
                fontFeatures: kLedgerTabular,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                context.tr(TranslationKeys.ledgerPerMonth),
                style: AppFonts.inter(fontSize: 14, color: palette.muted),
              ),
            ),
            if (originalPrice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '₹$originalPrice',
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: palette.dim,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: palette.dim,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(TranslationKeys.ledgerCancelAnytimeMonthly),
          style: AppFonts.inter(fontSize: 13, color: palette.muted),
        ),
        if (offerText != null) ...[
          const SizedBox(height: 4),
          Text(
            offerText!,
            style: AppFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: palette.gold,
            ),
          ),
        ],
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            description!,
            style: AppFonts.inter(
              fontSize: 14,
              color: palette.muted,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

/// Two-column comparison: feature, previous plan (muted), this plan (bold),
/// rows split by hairlines. The plan being bought is highlighted in violet.
class PlanComparisonTable extends StatelessWidget {
  final String previousPlanName;
  final String currentPlanName;
  final List<PlanComparisonRow> rows;

  /// Colour of the plan-being-bought column header.
  final Color? highlightColor;

  const PlanComparisonTable({
    super.key,
    required this.previousPlanName,
    required this.currentPlanName,
    required this.rows,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final highlight = highlightColor ?? palette.accentIcon;

    Widget cell(String text, {bool strong = false, Color? color}) => Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
            color: color ?? (strong ? palette.text : palette.muted),
            fontFeatures: kLedgerTabular,
          ),
        );

    Widget row(Widget a, Widget b, Widget c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(flex: 5, child: a),
              Expanded(flex: 3, child: b),
              Expanded(flex: 3, child: c),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          const SizedBox.shrink(),
          cell(previousPlanName, strong: true, color: palette.muted),
          cell(currentPlanName, strong: true, color: highlight),
        ),
        for (final r in rows) ...[
          const LedgerHairline(),
          row(
            Text(
              r.label,
              style: AppFonts.inter(
                fontSize: 13.5,
                color: palette.text,
                height: 1.3,
              ),
            ),
            cell(r.previousValue == '✗' ? '—' : r.previousValue),
            cell(r.currentValue == '✓' ? '✓' : r.currentValue, strong: true),
          ),
        ],
        const LedgerHairline(),
      ],
    );
  }
}

/// Info notice in the plan pages (eligibility, kill switch, payment hint).
class PlanInfoNotice extends StatelessWidget {
  final String text;
  final LedgerTone tone;

  const PlanInfoNotice(this.text, {super.key, this.tone = LedgerTone.accent});

  @override
  Widget build(BuildContext context) => LedgerNotice(
        icon: Icons.info_outline_rounded,
        text: text,
        tone: tone,
      );
}

/// Violet of the Plus tier, lifted on dark so it reads as text.
Color plusTierColor(BuildContext context) => ReaderPalette.of(context).isDark
    ? const Color(0xFFA78BFA)
    : const Color(0xFF7C3AED);
