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
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
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
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

class PlusUpgradePage extends StatefulWidget {
  const PlusUpgradePage({super.key});

  @override
  State<PlusUpgradePage> createState() => _PlusUpgradePageState();
}

class _PlusUpgradePageState extends State<PlusUpgradePage>
    with WidgetsBindingObserver {
  bool _hasOpenedPayment = false;
  bool _isLoadingPlan = true;
  bool _isDowngrade = false; // true when current plan tier > Plus
  bool _downgradeChecked = false; // true once _isDowngrade has been resolved
  bool _isSubmitting = false; // prevents double-tap on upgrade button
  bool _hasShownSuccess = false; // prevents repeated success snackbar
  Timer? _checkoutPollTimer;
  int _pollCount = 0;
  static const int _maxPollCount = 120; // 10 minutes at 5s intervals

  PromotionalCampaignModel? _appliedPromo;
  SubscriptionPlanModel? _plusPlan;
  SubscriptionPlanModel?
      _comparisonPlan; // Standard (upgrade) or Premium (downgrade)
  List<String> _features = [];
  List<PlanComparisonRow> _comparisonRows = [];

  static const Color _plusColor = AppColors.tierPlus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Detect downgrade: if current active subscription is at a higher tier than Plus.
    // Check both state types to handle cases where the bloc hasn't emitted SubscriptionLoaded yet.
    final subState = context.read<SubscriptionBloc>().state;
    if (subState is SubscriptionLoaded) {
      final planType = subState.activeSubscription?.planType ?? '';
      _isDowngrade = planType.contains('premium');
      _downgradeChecked = true;
    } else if (subState is UserSubscriptionStatusLoaded) {
      _isDowngrade = subState.subscriptionStatus.currentPlan == 'premium';
      _downgradeChecked = true;
    } else {
      // Bloc state not yet loaded (cold navigation). Load subscription status so
      // the BlocConsumer listener below can update _isDowngrade when it arrives,
      // then trigger the eligibility check with the correct value.
      context.read<SubscriptionBloc>().add(const LoadSubscriptionStatus());
    }

    if (_downgradeChecked && !_isDowngrade) {
      // Only check eligibility for upgrades — downgrades bypass this check
      context
          .read<SubscriptionBloc>()
          .add(const CheckSubscriptionEligibility(targetPlanCode: 'plus'));
    }
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

      SubscriptionPlanModel? plus;
      SubscriptionPlanModel? standard;
      SubscriptionPlanModel? premium;

      for (final plan in response.plans) {
        if (plan.planCode.toLowerCase() == 'plus') plus = plan;
        if (plan.planCode.toLowerCase() == 'standard') standard = plan;
        if (plan.planCode.toLowerCase() == 'premium') premium = plan;
      }

      // For downgrades, compare Premium vs Plus; for upgrades, compare Standard vs Plus
      final comparisonPlan = _isDowngrade ? premium : standard;

      if (mounted && plus != null) {
        setState(() {
          _plusPlan = plus;
          _comparisonPlan = comparisonPlan;
          _features = PlanFeaturesExtractor.extractFeaturesFromPlan(plus!);
          _comparisonRows =
              PlanFeaturesExtractor.buildComparisonRows(comparisonPlan, plus);
          _isLoadingPlan = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingPlan = false);
      }
    } catch (e) {
      Logger.error('[PlusUpgrade] Failed to load plan data', error: e);
      if (mounted) setState(() => _isLoadingPlan = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == true && _hasOpenedPayment) {
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
    if (_plusPlan != null) {
      return _plusPlan!.displayPrice.toStringAsFixed(0);
    }
    return '149';
  }

  String get _planName => _plusPlan?.planName ?? 'Disciplefy Plus';

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
            showAppSnackBar(
              context,
              context.tr(TranslationKeys.payFeedbackSubscriptionCreated),
              tone: AppSnackTone.success,
            );
            _hasOpenedPayment = true;
            _openAuthorizationUrl(state.authorizationUrl);
          } else {
            // Google Play IAP flow — purchase already processed, mark as complete
            // so the SubscriptionLoaded listener below can navigate away.
            _hasOpenedPayment = true;
            showAppSnackBar(
              context,
              context.tr(TranslationKeys.payFeedbackPurchaseReceived),
              tone: AppSnackTone.success,
            );
          }
        } else if (state is SubscriptionInitial) {
          setState(() => _isSubmitting = false);
          if (state.isPendingPayment) {
            showAppSnackBar(
              context,
              context.tr(TranslationKeys.payFeedbackAwaitingApproval),
            );
          }
        } else if (state is SubscriptionLoaded) {
          setState(() => _isSubmitting = false);
          if (state.activeSubscription?.isActivatedPlan('plus') == true) {
            _checkoutPollTimer?.cancel();
          }
          // Only navigate if the user actually went through the payment flow on
          // this page — prevents auto-pop when a background GetActiveSubscription
          // fires and the user already has a trial/other active subscription.
          // Must be the newly purchased plan in a genuinely activated state.
          // isActive() would also match the old plan parked as
          // pending_cancellation during checkout, announcing a success for a
          // payment the user never completed.
          if (_hasOpenedPayment &&
              !_hasShownSuccess &&
              state.activeSubscription?.isActivatedPlan('plus') == true) {
            _hasShownSuccess = true;
            showAppSnackBar(
              context,
              context.tr(
                  TranslationKeys.payFeedbackPlanActivated, {'plan': 'Plus'}),
              tone: AppSnackTone.success,
            );
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) context.go(AppRoutes.myPlan);
            });
          }
        } else if (state is UserSubscriptionStatusLoaded &&
            !_downgradeChecked) {
          // Cold navigation: subscription status just loaded — resolve downgrade.
          final isNowDowngrade =
              state.subscriptionStatus.currentPlan == 'premium';
          setState(() {
            _isDowngrade = isNowDowngrade;
            _downgradeChecked = true;
          });
          if (!isNowDowngrade) {
            context.read<SubscriptionBloc>().add(
                const CheckSubscriptionEligibility(targetPlanCode: 'plus'));
          }
        } else if (state is UserSubscriptionStatusLoaded &&
            state.authorizationUrl != null &&
            state.authorizationUrl!.isNotEmpty &&
            !_hasOpenedPayment) {
          _hasOpenedPayment = true;
          _openAuthorizationUrl(state.authorizationUrl!);
        } else if (state is UserSubscriptionStatusLoaded &&
            state.errorMessage != null &&
            state.errorMessage!.isNotEmpty) {
          // F28: Web Razorpay failure emitted as UserSubscriptionStatusLoaded
          // with errorMessage — reset button and surface the error.
          setState(() => _isSubmitting = false);
          showAppSnackBar(
            context,
            state.errorMessage!,
            tone: AppSnackTone.error,
          );
        } else if (state is SubscriptionError) {
          setState(() => _isSubmitting = false);
          showAppSnackBar(
            context,
            ErrorMessageSanitizer.sanitize(state.failure),
            tone: AppSnackTone.error,
          );
        }
      },
      builder: (context, state) {
        final plan = _plusPlan;
        return PlanDetailView(
          title: _plusPlan?.planName ?? 'Plus',
          subtitle: context.tr(TranslationKeys.ledgerRecommended),
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
          description: _plusPlan?.description ??
              context.tr(TranslationKeys.ledgerPlusTagline),
          previousPlanName: _comparisonPlan?.planName ??
              (_isDowngrade ? 'Premium' : 'Standard'),
          currentPlanName: _plusPlan?.planName ?? 'Plus',
          comparisonRows: _comparisonRows,
          featuresTitle: context.tr(TranslationKeys.whatYouGetPlus),
          features: _features,
          accentColor: plusTierColor(context),
          // Promo codes are hidden on iOS: App Store guideline 3.1.1
          // forbids unlocking paid content outside In-App Purchase.
          promo: PlatformUtils.isIOS
              ? null
              : PromoCodeInput(
                  planCode: 'plus',
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

    if (!_isDowngrade &&
        state is SubscriptionEligibilityChecked &&
        !state.canSubscribe) {
      return PlanInfoNotice(state.eligibilityMessage);
    }

    final isLoading = _isSubmitting ||
        (state is SubscriptionLoading &&
            state.operation?.contains('creating') == true);

    return LedgerPrimaryButton(
      key: const Key('plan_detail_cta'),
      icon: Icons.diamond_outlined,
      loading: isLoading,
      label: context.tr(TranslationKeys.ledgerCtaWithPrice, {
        'label': context.tr(_isDowngrade
            ? TranslationKeys.downgradeToPlus
            : TranslationKeys.upgradeToPlus),
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
      Logger.error('[PlusUpgrade] Failed to validate promo code', error: e);
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
      Logger.debug('[PlusUpgrade] Failed to save promo to Hive: $e');
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
      Logger.debug('[PlusUpgrade] Failed to clear promo from Hive: $e');
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
      if (promoCode != null) await box.delete('pending_promo_code');
    } catch (e) {
      Logger.debug('[PlusUpgrade] Failed to read Hive: $e');
    }

    if (!mounted) return;

    if (planPrice != null && planPrice == 0) {
      context.read<SubscriptionBloc>().add(
            ActivateFreeSubscription(planCode: 'plus', promoCode: promoCode),
          );
    } else {
      context
          .read<SubscriptionBloc>()
          .add(CreatePlusSubscription(promoCode: promoCode));
    }
  }

  Future<void> _openAuthorizationUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (kIsWeb) {
        _startCheckoutPolling();
      }
    } else if (mounted) {
      showAppSnackBar(
        context,
        context
            .tr(TranslationKeys.payFeedbackOpenPaymentUrlFailed, {'url': url}),
        tone: AppSnackTone.error,
      );
    }
  }
}
