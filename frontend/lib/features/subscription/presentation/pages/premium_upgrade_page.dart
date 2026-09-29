import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/platform_detection_service.dart';
import 'package:disciplefy_bible_study/core/services/platform_payment_provider_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/utils/platform_utils.dart';
import 'package:disciplefy_bible_study/features/subscription/data/datasources/subscription_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/subscription/data/models/subscription_v2_models.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/utils/plan_features_extractor.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/plan_detail_view.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/promo_code_input.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/subscription_legal_links.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

class PremiumUpgradePage extends StatefulWidget {
  const PremiumUpgradePage({super.key});

  @override
  State<PremiumUpgradePage> createState() => _PremiumUpgradePageState();
}

class _PremiumUpgradePageState extends State<PremiumUpgradePage>
    with WidgetsBindingObserver {
  bool _hasOpenedPayment = false;
  bool _hasShownSuccess =
      false; // prevents double-pop when SubscriptionLoaded fires multiple times
  bool _isLoadingPlan = true;
  bool _isSubmitting = false;
  Timer? _checkoutPollTimer;
  int _pollCount = 0;
  static const int _maxPollCount = 120; // 10 minutes at 5s intervals

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
          '[PremiumUpgrade] Page became visible after payment - refreshing subscription status');
      context.read<SubscriptionBloc>().add(const RefreshSubscription());
    }
  }

  @override
  void dispose() {
    _checkoutPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _hasOpenedPayment) {
      Logger.debug(
          '[PremiumUpgrade] App resumed after payment - refreshing subscription status');
      context.read<SubscriptionBloc>().add(const RefreshSubscription());
    }
  }

  void _startCheckoutPolling() {
    _checkoutPollTimer?.cancel();
    _pollCount = 0;
    _checkoutPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) {
        _checkoutPollTimer?.cancel();
        return;
      }
      _pollCount++;
      if (_pollCount > _maxPollCount) {
        _checkoutPollTimer?.cancel();
        return;
      }
      context.read<SubscriptionBloc>().add(const RefreshSubscription());
    });
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
    return BlocConsumer<SubscriptionBloc, SubscriptionState>(
      listener: (context, state) {
        if (state is SubscriptionCreated) {
          setState(() => _isSubmitting = false);
          if (state.authorizationUrl.isNotEmpty &&
              !_hasOpenedPayment &&
              ModalRoute.of(context)?.isCurrent == true) {
            // Razorpay flow — redirect user to payment page in browser.
            // Guarded: the UserSubscriptionStatusLoaded branch below can also
            // carry an authorizationUrl, and without this check both fire and
            // the user gets two identical Razorpay tabs.
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
            // Google Play IAP flow — purchase already processed, mark as complete
            // so the SubscriptionLoaded listener below can navigate away.
            _hasOpenedPayment = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    const Text('Purchase received! Activating subscription...'),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else if (state is SubscriptionInitial) {
          setState(() => _isSubmitting = false);
          if (state.isPendingPayment) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Payment is awaiting approval. You\'ll be notified when it\'s ready.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else if (state is SubscriptionLoaded) {
          setState(() => _isSubmitting = false);
          if (state.activeSubscription?.isActivatedPlan('premium') == true) {
            _checkoutPollTimer?.cancel();
          }
          // Must be the newly purchased plan in a genuinely activated state.
          // isActive() would also match the old plan parked as
          // pending_cancellation during checkout, announcing a success for a
          // payment the user never completed.
          if (_hasOpenedPayment &&
              !_hasShownSuccess &&
              state.activeSubscription?.isActivatedPlan('premium') == true) {
            _hasShownSuccess = true;
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
              if (mounted) context.go(AppRoutes.myPlan);
            });
          }
        } else if (state is SubscriptionError) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      },
      builder: (context, state) {
        final plan = _premiumPlan;
        return PlanDetailView(
          title: _premiumPlan?.planName ?? 'Premium',
          subtitle: context.tr(TranslationKeys.pricingBestValue),
          refreshTooltip: context.tr(TranslationKeys.premiumCheckStatus),
          onRefresh: () => context
              .read<SubscriptionBloc>()
              .add(const GetActiveSubscription()),
          loading: state is SubscriptionLoading || _isLoadingPlan,
          price: _displayPrice,
          originalPrice: plan?.hasDiscount == true
              ? plan!.pricing.basePriceFormatted.toStringAsFixed(0)
              : null,
          offerText: plan?.hasDiscount == true
              ? context.tr(TranslationKeys.pricingLimitedTimeOffer)
              : null,
          description: _premiumPlan?.description ??
              context.tr(TranslationKeys.premiumUnlockAccess),
          previousPlanName: _plusPlan?.planName ?? 'Plus',
          currentPlanName: _premiumPlan?.planName ?? 'Premium',
          comparisonRows: _comparisonRows,
          featuresTitle: context.tr(TranslationKeys.premiumWhatYouGet),
          features: _features,
          // Promo codes are hidden on iOS: App Store guideline 3.1.1
          // forbids unlocking paid content outside In-App Purchase.
          promo: PlatformUtils.isIOS
              ? null
              : PromoCodeInput(
                  planCode: 'premium',
                  initialPromo: _appliedPromo,
                  onValidate: _validatePromoCode,
                  onPromoApplied: _handlePromoApplied,
                  onPromoRemoved: _handlePromoRemoved,
                ),
          notices: [
            if (_hasOpenedPayment)
              PlanInfoNotice(
                  context.tr(TranslationKeys.premiumPaymentCompletedHint)),
          ],
          action: _buildActionButton(state),
          onRestore: PlatformPaymentProviderService.supportsRestorePurchases()
              ? () =>
                  context.read<SubscriptionBloc>().add(const RestorePurchases())
              : null,
          termsText: context.tr(TranslationKeys.premiumTermsAgree),
          securePaymentText: context.tr(TranslationKeys.premiumSecurePayment),
        );
      },
    );
  }

  Widget _buildActionButton(SubscriptionState state) {
    // Kill switch: new subscriptions disabled by admin
    if (!sl<SystemConfigService>().isNewSubscriptionsEnabled) {
      return PlanInfoNotice(
        context.tr(TranslationKeys.ledgerSubscriptionsPaused),
        tone: LedgerTone.warning,
      );
    }

    if (state is SubscriptionEligibilityChecked && !state.canSubscribe) {
      return PlanInfoNotice(state.eligibilityMessage);
    }

    final isLoading = _isSubmitting ||
        (state is SubscriptionLoading && state.operation == 'creating');

    return LedgerPrimaryButton(
      key: const Key('plan_detail_cta'),
      icon: Icons.workspace_premium_outlined,
      loading: isLoading,
      label: context.tr(TranslationKeys.ledgerCtaWithPrice, {
        'label': context.tr(TranslationKeys.premiumUpgradeButton),
        'price': '₹$_displayPrice',
      }),
      onPressed: _handleUpgrade,
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
    setState(() => _isSubmitting = true);
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

  Future<void> _openAuthorizationUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // On web, app-resume events are unreliable — poll for status changes
      if (kIsWeb) {
        _startCheckoutPolling();
      }
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
