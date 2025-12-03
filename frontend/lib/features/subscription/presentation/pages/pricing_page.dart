import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/logger.dart';
import '../widgets/pricing_card.dart';

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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildFreePlanCard(context)),
          const SizedBox(width: 16),
          Expanded(child: _buildStandardPlanCard(context)),
          const SizedBox(width: 16),
          Expanded(child: _buildPremiumPlanCard(context)),
        ],
      ),
    );
  }

  Widget _buildMobileLayoutCards(BuildContext context) {
    return Column(
      children: [
        _buildFreePlanCard(context, isMobile: true),
        const SizedBox(height: 16),
        _buildStandardPlanCard(context, isMobile: true),
        const SizedBox(height: 16),
        _buildPremiumPlanCard(context, isMobile: true),
      ],
    );
  }

  Widget _buildFreePlanCard(BuildContext context, {bool isMobile = false}) {
    return PricingCard(
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
      isMobile: isMobile,
    );
  }

  Widget _buildStandardPlanCard(BuildContext context, {bool isMobile = false}) {
    return PricingCard(
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
        context.tr(TranslationKeys.pricingStandardFeature5),
      ],
      buttonText: context.tr(TranslationKeys.pricingGetStarted),
      onPressed: () => context.go(AppRoutes.login),
      isHighlighted: true,
      isMobile: isMobile,
    );
  }

  Widget _buildPremiumPlanCard(BuildContext context, {bool isMobile = false}) {
    return PricingCard(
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
        context.tr(TranslationKeys.pricingPremiumFeature6),
      ],
      buttonText: context.tr(TranslationKeys.pricingGetStarted),
      onPressed: () async {
        // Save pending premium upgrade flag for post-login redirect
        try {
          Box box;
          if (Hive.isBoxOpen('app_settings')) {
            box = Hive.box('app_settings');
          } else {
            box = await Hive.openBox('app_settings');
          }
          await box.put('pending_premium_upgrade', true);

          if (context.mounted) {
            context.go(AppRoutes.login);
          }
        } on HiveError catch (e) {
          Logger.error(
            'Hive error saving premium upgrade flag',
            tag: 'PRICING',
            error: e,
          );
          // Still navigate to login even if Hive fails
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save preference. Please try again.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          Logger.error(
            'Unexpected error saving premium upgrade flag',
            tag: 'PRICING',
            error: e,
          );
          // Still navigate to login even if saving fails
          if (context.mounted) {
            context.go(AppRoutes.login);
          }
        }
      },
      isPremium: true,
      isMobile: isMobile,
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
              context.tr(TranslationKeys.pricingSecurePayments),
              style: AppFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(TranslationKeys.pricingPricesInInr),
          style: AppFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
