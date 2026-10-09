import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/platform_detection_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/utils/platform_utils.dart';
import 'package:disciplefy_bible_study/features/subscription/data/datasources/subscription_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/subscription/data/models/subscription_v2_models.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/utils/plan_features_extractor.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/pricing_card.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/promo_code_input.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Public Pricing Page
///
/// Displays subscription tiers and pricing dynamically fetched from database.
/// Supports multi-provider pricing (Razorpay, Google Play, Apple App Store)
/// and promotional code integration.
/// This page is accessible without authentication.
class PricingPage extends StatefulWidget {
  final PlatformDetectionService platformService;
  final SubscriptionRemoteDataSource dataSource;

  /// Plan to scroll into view once the plans have loaded.
  ///
  /// Arriving from an upgrade sheet, the page used to open at the top showing
  /// the Free card — the one plan the user already has — leaving them to hunt
  /// for the plan they were just told to buy.
  final String? preselectedPlan;

  const PricingPage({
    super.key,
    required this.platformService,
    required this.dataSource,
    this.preselectedPlan,
  });

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SubscriptionPlanModel> _plans = [];

  /// One key per rendered plan card, used to scroll [PricingPage.preselectedPlan]
  /// into view once the list exists.
  final Map<String, GlobalKey> _planCardKeys = {};
  bool _hasScrolledToPreselected = false;
  PromotionalCampaignModel? _appliedPromo;

  // Active plan code for current-plan highlighting — read from SubscriptionBloc
  // if available (authenticated routes). Null for unauthenticated/public routes.
  String? _activePlanCode;
  StreamSubscription<SubscriptionState>? _subscriptionStateSub;

  @override
  void initState() {
    super.initState();
    // setLoadingState: false — _isLoading is already true from the field initializer.
    // Calling setState from within initState (before _firstBuild completes) marks
    // the element dirty and can cause a double-build in the same frame.
    _fetchPlans(setLoadingState: false);
    // Subscribe to SubscriptionBloc after the first frame so the context is fully mounted.
    // Using a stream subscription (not BlocBuilder) keeps the widget tree structure stable
    // and avoids element-lifecycle / duplicate-GlobalKey errors from dynamically switching
    // between Builder and BlocBuilder widget types.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSubscriptionListener();
    });
  }

  void _initSubscriptionListener() {
    try {
      final bloc = context.read<SubscriptionBloc>();

      // Sync current state immediately
      final currentState = bloc.state;
      if (currentState is SubscriptionLoaded && mounted) {
        final sub = currentState.activeSubscription;
        final planCode = (sub != null && sub.isActive) ? sub.planType : null;
        if (planCode != null && planCode.isNotEmpty) {
          setState(() {
            _activePlanCode = planCode;
          });
        } else {
          // No active paid subscription — load status to surface trial/free plan
          bloc.add(const LoadSubscriptionStatus());
        }
      } else if (currentState is UserSubscriptionStatusLoaded && mounted) {
        final plan = currentState.subscriptionStatus.currentPlan;
        if (plan != 'free') {
          setState(() {
            _activePlanCode = plan;
          });
        }
      } else {
        // Trigger a fetch so the state arrives shortly
        bloc.add(const GetActiveSubscription());
      }

      // Reactively update when state changes.
      // Defer setState via addPostFrameCallback so it never fires mid-frame
      // (which causes Duplicate GlobalKey / element-lifecycle assertion errors
      // when the parent SubscriptionBloc consumer rebuilds in the same frame).
      _subscriptionStateSub = bloc.stream.listen((state) {
        if (state is SubscriptionLoaded && mounted) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Only use planType from a genuinely active subscription.
              // Stale cached cancelled/expired subs must not override the RPC result.
              final sub = state.activeSubscription;
              final planCode =
                  (sub != null && sub.isActive) ? sub.planType : null;
              if (planCode != null && planCode.isNotEmpty) {
                setState(() {
                  _activePlanCode = planCode;
                });
              } else {
                // No active paid subscription — load status to surface trial/free plan
                bloc.add(const LoadSubscriptionStatus());
              }
            }
          });
        } else if (state is UserSubscriptionStatusLoaded && mounted) {
          // UserSubscriptionStatus (RPC) is the authoritative source of truth.
          // Always apply it so a stale cached plan code never persists.
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final plan = state.subscriptionStatus.currentPlan;
              setState(() {
                _activePlanCode = plan != 'free' ? plan : null;
              });
            }
          });
        }
      });
    } catch (_) {
      // SubscriptionBloc not in tree (unauthenticated / public route) — no highlighting
    }
  }

  Future<void> _fetchPlans(
      {String? promoCode, bool setLoadingState = true}) async {
    // Only call setState to show loading if we're already mounted and it's a
    // reload/retry (not the initial fetch, where _isLoading is already true
    // from the field initializer). Calling setState from initState via the
    // initial _fetchPlans() call would mark the element dirty before _firstBuild
    // completes, causing a spurious double-build in the same frame.
    if (setLoadingState) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final provider = widget.platformService.getPreferredProvider();
      final providerString = widget.platformService.providerToString(provider);

      final locale = sl<TranslationService>().currentLanguage.code;
      final response = await widget.dataSource.getPlans(
        provider: providerString,
        region: 'IN',
        promoCode: promoCode,
        locale: locale,
      );

      if (!mounted) return;
      setState(() {
        _plans = response.plans;
        if (response.promotionalCampaign != null) {
          _appliedPromo = response.promotionalCampaign;
        }
        _isLoading = false;
      });
      _scrollToPreselectedPlan();
    } catch (e) {
      Logger.error(
        'Failed to fetch pricing plans',
        tag: 'PRICING',
        error: e,
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load pricing plans. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<PromotionalCampaignModel?> _validatePromoCode(String code) async {
    try {
      final provider = widget.platformService.getPreferredProvider();
      final providerString = widget.platformService.providerToString(provider);

      final response = await widget.dataSource.validatePromoCode(
        promoCode: code,
        provider: providerString,
      );

      if (response.valid && response.campaign != null) {
        return response.campaign!.toPromotionalCampaignModel();
      }
      return null;
    } catch (e) {
      Logger.error(
        'Failed to validate promo code',
        tag: 'PRICING',
        error: e,
      );
      return null;
    }
  }

  void _handlePromoApplied(PromotionalCampaignModel campaign) {
    // Refetch plans with the promo code applied
    _fetchPlans(promoCode: campaign.code);
  }

  void _handlePromoRemoved() {
    // Refetch plans without promo code
    setState(() {
      _appliedPromo = null;
    });
    _fetchPlans();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;
    final palette = ReaderPalette.of(context);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: LedgerTopBar(
        title: context.tr(TranslationKeys.ledgerPlansTitle),
        subtitle: context.tr(TranslationKeys.ledgerPlansSubtitle),
        useCloseIcon: true,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        },
      ),
      body: _buildBody(context, isWideScreen),
    );
  }

  /// Brings [PricingPage.preselectedPlan] into view after the cards render.
  ///
  /// Runs once: re-scrolling on every rebuild would fight the user the moment
  /// they scroll away.
  void _scrollToPreselectedPlan() {
    final target = widget.preselectedPlan;
    if (target == null || target.isEmpty || _hasScrolledToPreselected) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _planCardKeys[target];
      final targetContext = key?.currentContext;
      if (targetContext == null) return;

      _hasScrolledToPreselected = true;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        // Leave a little headroom so the card is not flush with the app bar.
        alignment: 0.1,
      );
    });
  }

  /// Stable key for a plan's card, created on first use.
  GlobalKey _planCardKey(String planCode) =>
      _planCardKeys.putIfAbsent(planCode, GlobalKey.new);

  Widget _buildBody(BuildContext context, bool isWideScreen) {
    // IMPORTANT: SingleChildScrollView is kept PERMANENTLY in the widget tree.
    // Swapping the root widget between Center/SingleChildScrollView when
    // _isLoading changes causes ScrollableState._gestureDetectorKey
    // (LabeledGlobalKey<RawGestureDetectorState>) to be deactivated and
    // re-created during the same frame, triggering a
    // "_elements.contains(element)" assertion in _InactiveElements.remove.
    // Keeping the scroll view constant eliminates the conflict entirely.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: _isLoading
          ? _buildLoadingContent(context)
          : _errorMessage != null
              ? _buildErrorContent(context)
              : _buildMainContent(context, isWideScreen),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: LedgerLoading(
        label: context.tr(TranslationKeys.ledgerLoadingPlans),
      ),
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: LedgerMessage(
        icon: Icons.cloud_off_rounded,
        isError: true,
        title: context.tr(TranslationKeys.ledgerPlansError),
        actionLabel: context.tr(TranslationKeys.commonRetry),
        onAction: _fetchPlans,
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isWideScreen) {
    final newSubscriptionsEnabled =
        sl<SystemConfigService>().isNewSubscriptionsEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kill switch banner: new subscriptions temporarily disabled
        if (!newSubscriptionsEnabled) ...[
          LedgerNotice(
            icon: Icons.info_outline_rounded,
            tone: LedgerTone.warning,
            text: context.tr(TranslationKeys.ledgerSubscriptionsPaused),
          ),
          const SizedBox(height: 12),
        ],

        // Promo codes are hidden on iOS: App Store guideline 3.1.1
        // forbids unlocking paid content outside In-App Purchase.
        if (!PlatformUtils.isIOS) ...[
          PromoCodeInput(
            onPromoApplied: _handlePromoApplied,
            onPromoRemoved: _handlePromoRemoved,
            onValidate: _validatePromoCode,
            initialPromo: _appliedPromo,
          ),
          const SizedBox(height: 12),
        ],

        // Pricing Cards — disable the action for the current active plan.
        // _activePlanCode is populated from SubscriptionBloc via a stream
        // subscription in initState (see _initSubscriptionListener). Using a
        // stream subscription rather than BlocBuilder keeps the widget tree
        // structure stable across rebuilds and avoids element-lifecycle errors.
        isWideScreen
            ? _buildWideLayoutCards(context, activePlanCode: _activePlanCode)
            : _buildMobileLayoutCards(context, activePlanCode: _activePlanCode),

        const SizedBox(height: 16),

        // Footer info
        _buildFooterInfo(context),
      ],
    );
  }

  Widget _buildWideLayoutCards(BuildContext context, {String? activePlanCode}) {
    if (_plans.isEmpty) {
      return LedgerMessage(
        icon: Icons.inventory_2_outlined,
        title: context.tr(TranslationKeys.ledgerNoPlans),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _plans.map((plan) {
          final isLast = plan == _plans.last;
          return Expanded(
            key: ValueKey('wide_${plan.planCode}'),
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 12),
              child: KeyedSubtree(
                key: _planCardKey(plan.planCode),
                child: _buildDynamicPlanCard(context, plan,
                    activePlanCode: activePlanCode),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileLayoutCards(BuildContext context,
      {String? activePlanCode}) {
    if (_plans.isEmpty) {
      return LedgerMessage(
        icon: Icons.inventory_2_outlined,
        title: context.tr(TranslationKeys.ledgerNoPlans),
      );
    }

    return Column(
      children: _plans.map((plan) {
        final isLast = plan == _plans.last;
        return Padding(
          key: ValueKey('mobile_${plan.planCode}'),
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: KeyedSubtree(
            key: _planCardKey(plan.planCode),
            child: _buildDynamicPlanCard(context, plan,
                isMobile: true, activePlanCode: activePlanCode),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDynamicPlanCard(
    BuildContext context,
    SubscriptionPlanModel plan, {
    bool isMobile = false,
    String? activePlanCode,
  }) {
    // activePlanCode (from subscriptions.plan_type) may include billing period suffix
    // e.g. "plus_monthly" while plan.planCode (from subscription_plans) is "plus".
    // Match if equal OR if activePlanCode starts with "<planCode>_".
    final normalizedActive = activePlanCode?.toLowerCase() ?? '';
    final normalizedPlan = plan.planCode.toLowerCase();
    final isCurrentPlan = activePlanCode != null &&
        (normalizedActive == normalizedPlan ||
            normalizedActive.startsWith('${normalizedPlan}_'));
    // Extract features — uses DB marketing_features when populated, computed fallback otherwise
    final features = _extractFeatures(plan);

    // Determine badge and styling based on tier
    String? badge;
    Color? badgeColor;
    bool isHighlighted = false;
    bool isPremium = false;

    switch (plan.tier) {
      case 1: // Standard
        badge = context.tr(TranslationKeys.pricingMostPopular);
        isHighlighted = true;
        break;
      case 2: // Plus
        badge = context.tr(TranslationKeys.ledgerRecommended);
        badgeColor = AppColors.tierPlus;
        isHighlighted = true;
        break;
      case 3: // Premium
        badge = context.tr(TranslationKeys.pricingBestValue);
        badgeColor = AppTheme.successColor;
        isPremium = true;
        break;
    }

    // Format pricing
    final price = plan.displayPrice.toStringAsFixed(0);
    final originalPrice = plan.hasDiscount
        ? plan.pricing.basePriceFormatted.toStringAsFixed(0)
        : null;

    // Get token info from features
    final dailyTokens = plan.features['daily_tokens'] as int?;
    final tokenInfo = dailyTokens != null
        ? dailyTokens == -1
            ? context.tr(TranslationKeys.pricingUnlimitedTokens)
            : '$dailyTokens ${context.tr(TranslationKeys.pricingTokensDaily)}'
        : null;

    // Promotional text if discount is applied
    final promotionalText = plan.hasDiscount
        ? context.tr(TranslationKeys.pricingLimitedTimeOffer)
        : null;

    final newSubscriptionsEnabled =
        sl<SystemConfigService>().isNewSubscriptionsEnabled;

    return PricingCard(
      planName: plan.planName,
      price: price,
      originalPrice: originalPrice,
      priceSubtext: context.tr(TranslationKeys.ledgerPerMo),
      tokenInfo: tokenInfo,
      promotionalText: promotionalText,
      badge: badge,
      badgeColor: badgeColor,
      features: features,
      buttonText: context.tr(TranslationKeys.pricingGetStarted),
      // Free has nothing to buy, so its card isn't tappable.
      onPressed: (isCurrentPlan ||
              !newSubscriptionsEnabled ||
              normalizedPlan == 'free')
          ? null
          : isPremium
              ? () => _handlePremiumPlanPress(context)
              : () => _handlePlanPress(context, plan),
      isHighlighted: isHighlighted,
      isPremium: isPremium,
      isMobile: isMobile,
      accentColor: plan.tier == 2 ? AppColors.tierPlus : null,
      isCurrentPlan: isCurrentPlan,
      currentPlanLabel: context.tr(TranslationKeys.ledgerYourCurrentPlan),
    );
  }

  List<String> _extractFeatures(SubscriptionPlanModel plan) =>
      PlanFeaturesExtractor.extractFeaturesFromPlan(plan);

  Future<void> _handlePremiumPlanPress(BuildContext context) async {
    // If user is already authenticated, go directly to the upgrade page.
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    if (isAuthenticated) {
      if (context.mounted) context.push(AppRoutes.premiumUpgrade);
      return;
    }

    // Not authenticated — save pending flag and go to login for post-login redirect
    try {
      Box box;
      if (Hive.isBoxOpen('app_settings')) {
        box = Hive.box('app_settings');
      } else {
        box = await Hive.openBox('app_settings');
      }
      await box.put('pending_premium_upgrade', true);

      // Save promo code if one is applied
      if (_appliedPromo != null) {
        await box.put('pending_promo_code', _appliedPromo!.code);
        Logger.debug('💰 [PRICING] Saved promo code: ${_appliedPromo!.code}');
      }

      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    } on HiveError catch (e) {
      Logger.error(
        'Hive error saving premium upgrade flag',
        tag: 'PRICING',
        error: e,
      );
      if (context.mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.payFeedbackSavePreferenceFailed),
          tone: AppSnackTone.error,
        );
        context.go(AppRoutes.login);
      }
    } catch (e) {
      Logger.error(
        'Unexpected error saving premium upgrade flag',
        tag: 'PRICING',
        error: e,
      );
      if (context.mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.payFeedbackSavePreferenceFailed),
          tone: AppSnackTone.error,
        );
        context.go(AppRoutes.login);
      }
    }
  }

  Future<void> _handlePlanPress(
    BuildContext context,
    SubscriptionPlanModel plan,
  ) async {
    // If user is already authenticated, go directly to the upgrade page.
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    if (isAuthenticated) {
      if (context.mounted) {
        context.push(_upgradeRouteForPlanCode(plan.planCode));
      }
      return;
    }

    // Not authenticated — save pending flag and go to login for post-login redirect
    try {
      Box box;
      if (Hive.isBoxOpen('app_settings')) {
        box = Hive.box('app_settings');
      } else {
        box = await Hive.openBox('app_settings');
      }

      // Store selected plan details
      await box.put('pending_plan_upgrade', true);
      await box.put('selected_plan_code', plan.planCode);
      await box.put('selected_plan_price', plan.displayPriceMinor);

      // Save promo code if applied
      if (_appliedPromo != null) {
        await box.put('pending_promo_code', _appliedPromo!.code);
        Logger.debug('💰 [PRICING] Saved promo code: ${_appliedPromo!.code}');
      }

      Logger.debug(
          '📦 [PRICING] Saved plan selection: ${plan.planCode} (₹${plan.displayPriceMinor / 100})');

      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      Logger.error('Failed to save plan selection', tag: 'PRICING', error: e);
      if (context.mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.payFeedbackSavePreferenceFailed),
          tone: AppSnackTone.error,
        );
        context.go(AppRoutes.login);
      }
    }
  }

  String _upgradeRouteForPlanCode(String planCode) {
    switch (planCode.toLowerCase()) {
      case 'premium':
        return AppRoutes.premiumUpgrade;
      case 'plus':
        return AppRoutes.plusUpgrade;
      case 'standard':
        return AppRoutes.standardUpgrade;
      default:
        return AppRoutes.premiumUpgrade;
    }
  }

  @override
  void dispose() {
    _subscriptionStateSub?.cancel();
    // Clear promo code if user navigates away without subscribing
    _clearPromoCodeFromHive();
    super.dispose();
  }

  Future<void> _clearPromoCodeFromHive() async {
    try {
      Box box;
      if (Hive.isBoxOpen('app_settings')) {
        box = Hive.box('app_settings');
      } else {
        box = await Hive.openBox('app_settings');
      }

      // Clear all pending flags
      await box.delete('pending_promo_code');
      await box.delete('pending_plan_upgrade');
      await box.delete('selected_plan_code');
      await box.delete('selected_plan_price');
      await box.delete('pending_premium_upgrade'); // Legacy flag
    } catch (e) {
      Logger.error('Failed to clear plan selection', tag: 'PRICING', error: e);
    }
  }

  Widget _buildFooterInfo(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Text(
      '${context.tr(TranslationKeys.pricingSecurePayments)} · ${context.tr(TranslationKeys.pricingPricesInInr)}',
      textAlign: TextAlign.center,
      style: AppFonts.inter(
        fontSize: 12,
        color: palette.muted,
        height: 1.45,
      ),
    );
  }
}
