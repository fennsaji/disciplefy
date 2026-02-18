import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// Individual pricing card widget for subscription plans
///
/// Displays a single pricing tier with:
/// - Plan name and pricing
/// - Token allocation info
/// - Feature list
/// - CTA button
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
  final String buttonText;
  final VoidCallback onPressed;
  final bool isHighlighted;
  final bool isPremium;
  final bool isMobile;
  final Color? accentColor;

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? (accentColor ?? AppTheme.primaryColor)
              : isPremium
                  ? AppTheme.successColor.withOpacity(0.5)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: isHighlighted || isPremium ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? (accentColor ?? AppTheme.primaryColor).withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: isHighlighted ? 20 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Badge
          if (badge != null) _buildBadge(context),

          // Use Expanded only for desktop (when in IntrinsicHeight context)
          if (!isMobile)
            Expanded(
              child: _buildCardContent(context),
            )
          else
            _buildCardContent(context),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor ?? AppTheme.primaryColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(14),
        ),
      ),
      child: Text(
        badge!,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPriceSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Original price with strikethrough
        if (originalPrice != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 4),
            child: Text(
              '₹$originalPrice',
              style: AppFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
        Text(
          '₹',
          style: AppFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isPremium
                ? AppTheme.successColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          price,
          style: AppFonts.inter(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: isPremium
                ? AppTheme.successColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Text(
            priceSubtext,
            style: AppFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan name
          Text(
            planName,
            style: AppFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Price section
          _buildPriceSection(context),
          const SizedBox(height: 8),

          // Token info (only show if provided)
          if (tokenInfo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPremium
                    ? AppTheme.successColor.withOpacity(0.18)
                    : (accentColor ?? AppTheme.primaryLightColor)
                        .withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tokenInfo!,
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPremium
                      ? AppTheme.successColor
                      : (accentColor ?? AppTheme.primaryLightColor),
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Promotional text
          if (promotionalText != null) ...[
            const SizedBox(height: 8),
            Text(
              promotionalText!,
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.warningColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // Features list
          ...features.map((feature) => _buildFeatureItem(context, feature)),

          // Spacer to push button to bottom (only for desktop)
          if (!isMobile) const Spacer(),

          // CTA button
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium
                  ? AppTheme.successColor
                  : isHighlighted
                      ? (accentColor ?? AppTheme.primaryColor)
                      : Theme.of(context).colorScheme.outline.withOpacity(0.2),
              foregroundColor: isPremium || isHighlighted
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              buttonText,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String feature) {
    final isUnavailable = feature.toLowerCase().contains('not included');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUnavailable ? Icons.cancel_outlined : Icons.check_circle_rounded,
            size: 18,
            color: isUnavailable
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3)
                : isPremium
                    ? AppTheme.successColor
                    : (accentColor ?? AppTheme.primaryLightColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature,
              style: AppFonts.inter(
                fontSize: 14,
                color: isUnavailable
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.35)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
