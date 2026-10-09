import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/plan_detail_view.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// One plan on the "Choose your plan" page, in the ledger style.
///
/// Name, badge and price on one line, daily credits in gold, the features as a
/// muted run of text. The whole card is the action: tapping it (or its
/// "Get started" link) calls [onPressed]. The current plan gets a gold
/// ring and a "Your current plan" line and is not tappable; the highlighted
/// tier (Plus) gets a violet ring on a soft wash.
class PricingCard extends StatelessWidget {
  final String planName;
  final String price;
  final String? originalPrice;
  final String priceSubtext;
  final String? tokenInfo;
  final String? promotionalText;
  final String? badge;
  final Color? badgeColor;
  final List<String> features;

  /// Accessible hint for the card's action ("Get started").
  final String buttonText;
  final VoidCallback? onPressed;
  final bool isHighlighted;
  final bool isPremium;
  final bool isMobile;

  /// Tier colour; when set the card is outlined in it (Plus).
  final Color? accentColor;
  final bool isCurrentPlan;

  /// "Your current plan" line.
  final String? currentPlanLabel;

  const PricingCard({
    super.key,
    required this.planName,
    required this.price,
    this.originalPrice,
    required this.priceSubtext,
    this.tokenInfo,
    this.promotionalText,
    this.badge,
    this.badgeColor,
    required this.features,
    required this.buttonText,
    required this.onPressed,
    this.isHighlighted = false,
    this.isPremium = false,
    this.isMobile = false,
    this.accentColor,
    this.isCurrentPlan = false,
    this.currentPlanLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final accent = accentColor != null ? plusTierColor(context) : null;
    final Color border;
    final double borderWidth;
    Color fill = palette.card;
    if (isCurrentPlan) {
      border = palette.gold;
      borderWidth = 1.5;
    } else if (accent != null) {
      border = accent;
      borderWidth = 1.5;
      fill = Color.alphaBlend(
        AppColors.tierPlus.withValues(alpha: palette.isDark ? 0.10 : 0.05),
        palette.card,
      );
    } else {
      border = palette.hairline;
      borderWidth = 1;
    }
    final tappable = !isCurrentPlan && onPressed != null;

    return Semantics(
      button: tappable,
      hint: tappable ? buttonText : null,
      child: Material(
        color: fill,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border, width: borderWidth),
        ),
        child: InkWell(
          onTap: tappable ? onPressed : null,
          child: Opacity(
            // Dimmed when purchases are switched off (no action).
            opacity: !isCurrentPlan && onPressed == null ? 0.6 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(context, palette),
                  if (tokenInfo != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tokenInfo!,
                      style: AppFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: palette.gold,
                      ),
                    ),
                  ],
                  if (features.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final feature in features)
                      _FeatureLine(feature: feature, palette: palette),
                  ],
                  if (promotionalText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      promotionalText!,
                      style: AppFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: context.appWarning,
                      ),
                    ),
                  ],
                  // The card is tappable; the action is also spelled out
                  // so it reads as a button, not just a description.
                  if (tappable) ...[
                    const SizedBox(height: 6),
                    LedgerLink(
                      key: Key('pricing_card_action_$planName'),
                      label: buttonText,
                      trailingIcon: Icons.arrow_forward_rounded,
                      onTap: onPressed,
                    ),
                  ],
                  if (isCurrentPlan) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_rounded,
                            size: 16, color: palette.gold),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            currentPlanLabel ?? 'Current Plan',
                            style: AppFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: palette.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ReaderPalette palette) {
    final LedgerTone tone = isPremium
        ? LedgerTone.success
        : accentColor != null
            ? LedgerTone.accent
            : LedgerTone.gold;
    final badgeColors = LedgerToneColors.of(context, tone);
    final badgeInk =
        accentColor != null ? plusTierColor(context) : badgeColors.foreground;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                planName,
                style: AppFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor != null
                        ? AppColors.tierPlus
                            .withValues(alpha: palette.isDark ? 0.22 : 0.10)
                        : badgeColors.fill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: AppFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badgeInk,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹$price',
                  style: AppFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    height: 1.1,
                    fontFeatures: kLedgerTabular,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 3, bottom: 2),
                  child: Text(
                    priceSubtext,
                    style: AppFonts.inter(fontSize: 12, color: palette.muted),
                  ),
                ),
              ],
            ),
            if (originalPrice != null)
              Text(
                '₹$originalPrice',
                style: AppFonts.inter(
                  fontSize: 12.5,
                  color: palette.dim,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: palette.dim,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One feature per line: a check, or a dimmed cross for "— Not Included".
class _FeatureLine extends StatelessWidget {
  static const _excludedSuffix = ' — Not Included';

  final String feature;
  final ReaderPalette palette;

  const _FeatureLine({required this.feature, required this.palette});

  @override
  Widget build(BuildContext context) {
    final excluded = feature.endsWith(_excludedSuffix);
    final label = excluded
        ? feature.substring(0, feature.length - _excludedSuffix.length)
        : feature;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              excluded ? Icons.close_rounded : Icons.check_rounded,
              size: 15,
              color: excluded ? palette.dim : palette.accentIcon,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 13,
                color: excluded ? palette.dim : palette.muted,
                height: 1.4,
                decoration: excluded ? TextDecoration.lineThrough : null,
                decorationColor: palette.dim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
