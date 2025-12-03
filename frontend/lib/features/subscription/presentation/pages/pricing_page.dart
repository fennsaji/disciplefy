import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';

/// Public Pricing Page
///
/// Displays subscription tiers and pricing for Razorpay verification.
/// This page is accessible without authentication.
class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(TranslationKeys.pricingTitle),
          style: AppFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            const SizedBox(height: 32),

            // Pricing Cards
            if (isWideScreen)
              _buildWideLayoutCards(context)
            else
              _buildMobileLayoutCards(context),

            const SizedBox(height: 32),

            // Footer info
            _buildFooterInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.workspace_premium_rounded,
          size: 56,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          context.tr(TranslationKeys.pricingSubtitle),
          style: AppFonts.inter(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWideLayoutCards(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildFreePlanCard(context)),
        const SizedBox(width: 16),
        Expanded(child: _buildStandardPlanCard(context)),
        const SizedBox(width: 16),
        Expanded(child: _buildPremiumPlanCard(context)),
      ],
    );
  }

  Widget _buildMobileLayoutCards(BuildContext context) {
    return Column(
      children: [
        _buildFreePlanCard(context),
        const SizedBox(height: 16),
        _buildStandardPlanCard(context),
        const SizedBox(height: 16),
        _buildPremiumPlanCard(context),
      ],
    );
  }

  Widget _buildFreePlanCard(BuildContext context) {
    return _PricingCard(
      planName: context.tr(TranslationKeys.pricingFreePlan),
      price: '0',
      priceSubtext: context.tr(TranslationKeys.pricingPerMonth),
      tokenInfo: '20 ${context.tr(TranslationKeys.pricingTokensDaily)}',
      features: [
        context.tr(TranslationKeys.pricingFreeFeature1),
        context.tr(TranslationKeys.pricingFreeFeature2),
        context.tr(TranslationKeys.pricingFreeFeature3),
        context.tr(TranslationKeys.pricingFreeFeature4),
      ],
      buttonText: context.tr(TranslationKeys.pricingGetStarted),
      onPressed: () => context.go(AppRoutes.login),
    );
  }

  Widget _buildStandardPlanCard(BuildContext context) {
    return _PricingCard(
      planName: context.tr(TranslationKeys.pricingStandardPlan),
      price: '0',
      originalPrice: '50',
      priceSubtext: context.tr(TranslationKeys.pricingPerMonth),
      tokenInfo: '100 ${context.tr(TranslationKeys.pricingTokensDaily)}',
      promotionalText: context.tr(TranslationKeys.pricingLimitedTimeOffer),
      badge: context.tr(TranslationKeys.pricingMostPopular),
      features: [
        context.tr(TranslationKeys.pricingStandardFeature1),
        context.tr(TranslationKeys.pricingStandardFeature2),
        context.tr(TranslationKeys.pricingStandardFeature3),
        context.tr(TranslationKeys.pricingStandardFeature4),
      ],
      buttonText: context.tr(TranslationKeys.pricingGetStarted),
      onPressed: () => context.go(AppRoutes.login),
      isHighlighted: true,
    );
  }

  Widget _buildPremiumPlanCard(BuildContext context) {
    return _PricingCard(
      planName: context.tr(TranslationKeys.pricingPremiumPlan),
      price: '100',
      originalPrice: '200',
      priceSubtext: context.tr(TranslationKeys.pricingPerMonth),
      tokenInfo: context.tr(TranslationKeys.pricingUnlimitedTokens),
      promotionalText: context.tr(TranslationKeys.pricingLimitedTimeOffer),
      badge: context.tr(TranslationKeys.pricingBestValue),
      badgeColor: AppTheme.successColor,
      features: [
        context.tr(TranslationKeys.pricingPremiumFeature1),
        context.tr(TranslationKeys.pricingPremiumFeature2),
        context.tr(TranslationKeys.pricingPremiumFeature3),
        context.tr(TranslationKeys.pricingPremiumFeature4),
        context.tr(TranslationKeys.pricingPremiumFeature5),
      ],
      buttonText: context.tr(TranslationKeys.pricingGetStarted),
      onPressed: () async {
        // Save pending premium upgrade flag for post-login redirect
        final box = Hive.box('app_settings');
        await box.put('pending_premium_upgrade', true);

        if (context.mounted) {
          context.go(AppRoutes.login);
        }
      },
      isPremium: true,
    );
  }

  Widget _buildFooterInfo(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              'Secure payments powered by Razorpay',
              style: AppFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Prices are in Indian Rupees (INR)',
          style: AppFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

/// Individual pricing card widget
class _PricingCard extends StatelessWidget {
  final String planName;
  final String price;
  final String? originalPrice;
  final String priceSubtext;
  final String tokenInfo;
  final String? promotionalText;
  final String? badge;
  final Color? badgeColor;
  final List<String> features;
  final String buttonText;
  final VoidCallback onPressed;
  final bool isHighlighted;
  final bool isPremium;

  const _PricingCard({
    required this.planName,
    required this.price,
    this.originalPrice,
    required this.priceSubtext,
    required this.tokenInfo,
    this.promotionalText,
    this.badge,
    this.badgeColor,
    required this.features,
    required this.buttonText,
    required this.onPressed,
    this.isHighlighted = false,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? AppTheme.primaryColor
              : isPremium
                  ? AppTheme.successColor.withOpacity(0.5)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: isHighlighted || isPremium ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? AppTheme.primaryColor.withOpacity(0.15)
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

          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              badge != null ? 12 : 24,
              20,
              24,
            ),
            child: Column(
              children: [
                // Plan name
                Text(
                  planName,
                  style: AppFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isPremium
                        ? AppTheme.successColor
                        : isHighlighted
                            ? AppTheme.primaryColor
                            : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                // Price
                _buildPriceSection(context),
                const SizedBox(height: 8),

                // Token info
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPremium
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.secondaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tokenInfo,
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isPremium
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),

                // Promotional text
                if (promotionalText != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      promotionalText!,
                      style: AppFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Features
                ...features
                    .map((feature) => _buildFeatureItem(context, feature)),

                const SizedBox(height: 24),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPremium
                          ? AppTheme.successColor
                          : isHighlighted
                              ? AppTheme.primaryColor
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                      foregroundColor: isPremium || isHighlighted
                          ? Colors.white
                          : AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: isPremium || isHighlighted ? 2 : 0,
                    ),
                    child: Text(
                      buttonText,
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildFeatureItem(BuildContext context, String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: isPremium ? AppTheme.successColor : AppTheme.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature,
              style: AppFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
