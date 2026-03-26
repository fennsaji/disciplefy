import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/i18n/translation_service.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/services/platform_detection_service.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/logger.dart';
import '../../data/datasources/subscription_remote_data_source.dart';
import '../../data/models/subscription_v2_models.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../utils/plan_features_extractor.dart';
import '../widgets/promo_code_input.dart';

class PremiumUpgradePage extends StatefulWidget {
  const PremiumUpgradePage({super.key});

  @override
  State<PremiumUpgradePage> createState() => _PremiumUpgradePageState();
}

class _PremiumUpgradePageState extends State<PremiumUpgradePage>
    with WidgetsBindingObserver {
  bool _hasOpenedPayment = false;
  bool _isLoadingPlan = true;

  PromotionalCampaignModel? _appliedPromo;
  SubscriptionPlanModel? _premiumPlan;
  SubscriptionPlanModel? _plusPlan; // for comparison
  List<String> _features = [];
  List<PlanComparisonRow> _comparisonRows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context
        .read<SubscriptionBloc>()
        .add(const CheckSubscriptionEligibility(targetPlanCode: 'premium'));
    _loadPlanData();
  }

  Future<void> _loadPlanData() async {
    try {
      final dataSource = sl<SubscriptionRemoteDataSource>();
      final platformService = PlatformDetectionService();
      final provider = platformService
          .providerToString(platformService.getPreferredProvider());

      final locale = sl<TranslationService>().currentLanguage.code;
      final response = await dataSource.getPlans(
          provider: provider, region: 'IN', locale: locale);

      SubscriptionPlanModel? premium;
      SubscriptionPlanModel? plus;

      for (final plan in response.plans) {
        final code = plan.planCode.toLowerCase();
        if (code == 'premium') premium = plan;
        if (code == 'plus') plus = plan;
      }

      if (mounted && premium != null) {
        setState(() {
          _premiumPlan = premium;
          _plusPlan = plus;
          _features = PlanFeaturesExtractor.extractFeaturesFromPlan(premium!);
          _comparisonRows =
              PlanFeaturesExtractor.buildComparisonRows(plus, premium);
          _isLoadingPlan = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingPlan = false);
      }
    } catch (e) {
      Logger.error('[PremiumUpgrade] Failed to load plan data', error: e);
      if (mounted) setState(() => _isLoadingPlan = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == true && _hasOpenedPayment) {
      Logger.debug(
          '[PremiumUpgrade] Page became visible after payment - checking subscription status');
      context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _hasOpenedPayment) {
      Logger.debug(
          '[PremiumUpgrade] App resumed after payment - checking subscription status');
      context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    }
  }

  String get _displayPrice {
    if (_premiumPlan != null) {
      return _premiumPlan!.displayPrice.toStringAsFixed(0);
    }
    return '499';
  }

  String get _planName => _premiumPlan?.planName ?? 'Disciplefy Premium';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(TranslationKeys.premiumUpgradeTitle),
          style: AppFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              Logger.debug(
                  '[PremiumUpgrade] Manual refresh - checking subscription status');
              context
                  .read<SubscriptionBloc>()
                  .add(const GetActiveSubscription());
            },
            tooltip: context.tr(TranslationKeys.premiumCheckStatus),
          ),
        ],
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is SubscriptionCreated) {
            if (state.authorizationUrl.isNotEmpty) {
              // Razorpay flow — redirect user to payment page in browser
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      context.tr(TranslationKeys.premiumSubscriptionCreated)),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 2),
                ),
              );
              _hasOpenedPayment = true;
              _openAuthorizationUrl(state.authorizationUrl);
            } else {
              // Google Play flow — purchase already processed, no redirect needed
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                      'Purchase received! Activating subscription...'),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else if (state is SubscriptionLoaded) {
            if (_hasOpenedPayment &&
                state.activeSubscription?.isActive == true) {
              Logger.debug(
                  '[PremiumUpgrade] Subscription is now active - navigating back');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      context.tr(TranslationKeys.premiumSubscriptionActivated)),
                  backgroundColor: AppTheme.successColor,
                  duration: const Duration(seconds: 3),
                ),
              );
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) Navigator.of(context).pop();
              });
            }
          } else if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Something went wrong. Please try again.'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is SubscriptionLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_isLoadingPlan) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPremiumBadge(),
                const SizedBox(height: 24),
                _buildPricingCard(),
                const SizedBox(height: 32),
                _buildFeaturesList(),
                const SizedBox(height: 32),
                if (_comparisonRows.isNotEmpty) ...[
                  _buildComparison(),
                  const SizedBox(height: 32),
                ],
                PromoCodeInput(
                  planCode: 'premium',
                  initialPromo: _appliedPromo,
                  onValidate: _validatePromoCode,
                  onPromoApplied: _handlePromoApplied,
                  onPromoRemoved: _handlePromoRemoved,
                ),
                const SizedBox(height: 24),
                _buildActionButton(state),
                const SizedBox(height: 16),
                _buildTermsInfo(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumBadge() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.secondaryColor.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 64,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            _planName,
            style: AppFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _premiumPlan?.description ??
                context.tr(TranslationKeys.premiumUnlockAccess),
            style: AppFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                context.tr(TranslationKeys.pricingLimitedTimeOffer),
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_premiumPlan?.hasDiscount == true) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, right: 8),
                    child: Text(
                      '₹${_premiumPlan!.pricing.basePriceFormatted.toStringAsFixed(0)}',
                      style: AppFonts.inter(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.7),
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
                Text(
                  '₹',
                  style: AppFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _displayPrice,
                  style: AppFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '/month',
                    style: AppFonts.inter(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                context.tr(TranslationKeys.premiumCancelAnytime),
                style: AppFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.premiumWhatYouGet),
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        ..._features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildFeatureRow(feature),
            )),
      ],
    );
  }

  Widget _buildFeatureRow(String feature) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(Icons.check_rounded, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              feature,
              style: AppFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparison() {
    final prevName = _plusPlan?.planName ?? 'Plus';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(TranslationKeys.premiumPlanComparison),
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$prevName vs ${_premiumPlan?.planName ?? 'Premium'}',
              style: AppFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ..._comparisonRows.map((row) => _buildComparisonRow(
                  row.label,
                  row.previousValue,
                  row.currentValue,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
      String feature, String previousValue, String currentValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: AppFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              previousValue,
              style: AppFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              currentValue,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsDisabledCard() {
    return Card(
      color: AppTheme.secondaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'New subscriptions are temporarily unavailable. Please check back later.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(SubscriptionState state) {
    // Kill switch: new subscriptions disabled by admin
    if (!sl<SystemConfigService>().isNewSubscriptionsEnabled) {
      return _buildSubscriptionsDisabledCard();
    }

    if (state is SubscriptionEligibilityChecked) {
      if (!state.canSubscribe) {
        return Card(
          color: AppTheme.secondaryColor.withOpacity(0.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.eligibilityMessage,
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    final isLoading =
        state is SubscriptionLoading && state.operation == 'creating';

    return ElevatedButton(
      onPressed: isLoading ? null : _handleUpgrade,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium_rounded),
                const SizedBox(width: 8),
                Text(
                  context.tr(TranslationKeys.premiumUpgradeButton),
                  style:
                      AppFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }

  Future<PromotionalCampaignModel?> _validatePromoCode(String code) async {
    try {
      final dataSource = sl<SubscriptionRemoteDataSource>();
      final platformService = PlatformDetectionService();
      final provider = platformService
          .providerToString(platformService.getPreferredProvider());
      final response = await dataSource.validatePromoCode(
        promoCode: code,
        provider: provider,
      );
      if (response.valid && response.campaign != null) {
        return response.campaign!.toPromotionalCampaignModel();
      }
      return null;
    } catch (e) {
      Logger.error('[PremiumUpgrade] Failed to validate promo code', error: e);
      return null;
    }
  }

  Future<void> _handlePromoApplied(PromotionalCampaignModel campaign) async {
    setState(() => _appliedPromo = campaign);
    try {
      final box = Hive.isBoxOpen('app_settings')
          ? Hive.box('app_settings')
          : await Hive.openBox('app_settings');
      await box.put('pending_promo_code', campaign.code);
    } catch (e) {
      Logger.debug('[PremiumUpgrade] Failed to save promo to Hive: $e');
    }
  }

  Future<void> _handlePromoRemoved() async {
    setState(() => _appliedPromo = null);
    try {
      final box = Hive.isBoxOpen('app_settings')
          ? Hive.box('app_settings')
          : await Hive.openBox('app_settings');
      await box.delete('pending_promo_code');
    } catch (e) {
      Logger.debug('[PremiumUpgrade] Failed to clear promo from Hive: $e');
    }
  }

  Future<void> _handleUpgrade() async {
    String? promoCode;
    int? planPrice;
    try {
      final box = Hive.isBoxOpen('app_settings')
          ? Hive.box('app_settings')
          : await Hive.openBox('app_settings');
      promoCode = box.get('pending_promo_code') as String?;
      planPrice = box.get('selected_plan_price') as int?;

      if (promoCode != null) {
        Logger.debug('💰 [UPGRADE] Retrieved promo code: $promoCode');
        await box.delete('pending_promo_code');
      }
      if (planPrice != null) {
        Logger.warning('💵 [UPGRADE] Plan price: ₹${planPrice / 100}');
      }
    } catch (e) {
      Logger.debug('⚠️ [UPGRADE] Failed to retrieve promo/price: $e');
    }

    if (!mounted) return;

    if (planPrice != null && planPrice == 0) {
      Logger.debug('🎁 [UPGRADE] Free plan detected, activating directly');
      context.read<SubscriptionBloc>().add(
            ActivateFreeSubscription(planCode: 'premium', promoCode: promoCode),
          );
    } else {
      context
          .read<SubscriptionBloc>()
          .add(CreateSubscription(promoCode: promoCode));
    }
  }

  Widget _buildTermsInfo() {
    return Column(
      children: [
        if (_hasOpenedPayment) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(TranslationKeys.premiumPaymentCompletedHint),
                    style: AppFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          context.tr(TranslationKeys.premiumTermsAgree),
          style: AppFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
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
              context.tr(TranslationKeys.premiumSecurePayment),
              style: AppFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openAuthorizationUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open payment URL: $url'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
