import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_state.dart';
import '../../../../core/i18n/translation_service.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/platform_detection_service.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../data/datasources/subscription_remote_data_source.dart';
import '../../data/models/subscription_v2_models.dart';
import '../bloc/subscription_event.dart';
import '../utils/plan_features_extractor.dart';
import '../widgets/pricing_card.dart';
import '../widgets/promo_code_input.dart';

/// Public Pricing Page
///
/// Displays subscription tiers and pricing dynamically fetched from database.
/// Supports multi-provider pricing (Razorpay, Google Play, Apple App Store)
/// and promotional code integration.
/// This page is accessible without authentication.
class PricingPage extends StatefulWidget {
  final PlatformDetectionService platformService;
  final SubscriptionRemoteDataSource dataSource;

  const PricingPage({
    super.key,
    required this.platformService,
    required this.dataSource,
  });

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SubscriptionPlanModel> _plans = [];
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
      body: _buildBody(context, isWideScreen),
    );
  }

  Widget _buildBody(BuildContext context, bool isWideScreen) {
    // IMPORTANT: SingleChildScrollView is kept PERMANENTLY in the widget tree.
    // Swapping the root widget between Center/SingleChildScrollView when
    // _isLoading changes causes ScrollableState._gestureDetectorKey
    // (LabeledGlobalKey<RawGestureDetectorState>) to be deactivated and
    // re-created during the same frame, triggering a
    // "_elements.contains(element)" assertion in _InactiveElements.remove.
    // Keeping the scroll view constant eliminates the conflict entirely.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading pricing plans...',
              style: AppFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContent(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: AppFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchPlans,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: Text(
                  'Retry',
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isWideScreen) {
    return Column(
      children: [
        // Header
        _buildHeader(context),
        const SizedBox(height: 32),

        // Promo Code Input
        PromoCodeInput(
          onPromoApplied: _handlePromoApplied,
          onPromoRemoved: _handlePromoRemoved,
          onValidate: _validatePromoCode,
          initialPromo: _appliedPromo,
        ),
        const SizedBox(height: 32),

        // Pricing Cards — disable button for the current active plan.
        // _activePlanCode is populated from SubscriptionBloc via a stream
        // subscription in initState (see _initSubscriptionListener). Using a
        // stream subscription rather than BlocBuilder keeps the widget tree
        // structure stable across rebuilds and avoids element-lifecycle errors.
        isWideScreen
            ? _buildWideLayoutCards(context, activePlanCode: _activePlanCode)
            : _buildMobileLayoutCards(context, activePlanCode: _activePlanCode),

        const SizedBox(height: 32),

        // Footer info
        _buildFooterInfo(context),
      ],
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

  Widget _buildWideLayoutCards(BuildContext context, {String? activePlanCode}) {
    if (_plans.isEmpty) {
      return Center(
        child: Text(
          'No pricing plans available',
          style: AppFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
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
              child: _buildDynamicPlanCard(context, plan,
                  activePlanCode: activePlanCode),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileLayoutCards(BuildContext context,
      {String? activePlanCode}) {
    if (_plans.isEmpty) {
      return Center(
        child: Text(
          'No pricing plans available',
          style: AppFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      );
    }

    return Column(
      children: _plans.map((plan) {
        final isLast = plan == _plans.last;
        return Padding(
          key: ValueKey('mobile_${plan.planCode}'),
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
          child: _buildDynamicPlanCard(context, plan,
              isMobile: true, activePlanCode: activePlanCode),
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
        badge = 'Recommended';
        badgeColor = AppColors.tierPlus; // Violet — matches plus-upgrade page
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

    return PricingCard(
      planName: plan.planName,
      price: price,
      originalPrice: originalPrice,
      priceSubtext: context.tr(TranslationKeys.pricingPerMonth),
      tokenInfo: tokenInfo,
      promotionalText: promotionalText,
      badge: badge,
      badgeColor: badgeColor,
      features: features,
      buttonText: context.tr(TranslationKeys.pricingGetStarted),
      onPressed: isCurrentPlan
          ? null
          : isPremium
              ? () => _handlePremiumPlanPress(context)
              : () => _handlePlanPress(context, plan),
      isHighlighted: isHighlighted,
      isPremium: isPremium,
      isMobile: isMobile,
      accentColor: plan.tier == 2 ? AppColors.tierPlus : null,
      isCurrentPlan: isCurrentPlan,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preference. Please try again.'),
            duration: Duration(seconds: 2),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preference. Please try again.'),
            duration: Duration(seconds: 2),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preference. Please try again.'),
            duration: Duration(seconds: 2),
          ),
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

  Widget _buildPlusPlanCard(BuildContext context, {bool isMobile = false}) {
    return PricingCard(
      planName: 'Plus',
      price: '149',
      priceSubtext: context.tr(TranslationKeys.pricingPerMonth),
      tokenInfo: '50 ${context.tr(TranslationKeys.pricingTokensDaily)}',
      badge: 'Recommended',
      badgeColor: const Color(0xFFFF9800), // Orange
      features: [
        '50 daily tokens (all study modes)',
        '10 follow-ups per study guide',
        '10 AI Discipler conversations/month',
        '10 active memory verses',
        'All 8 practice modes',
        '3 practice sessions per verse per day',
      ],
      buttonText: context.tr(TranslationKeys.pricingGetStarted),
      onPressed: () => context.go(AppRoutes.login),
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
          // Show error and navigate to login
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save preference. Please try again.'),
                duration: Duration(seconds: 2),
              ),
            );
            context.go(AppRoutes.login);
          }
        } catch (e) {
          Logger.error(
            'Unexpected error saving premium upgrade flag',
            tag: 'PRICING',
            error: e,
          );
          // Show error and navigate to login
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save preference. Please try again.'),
                duration: Duration(seconds: 2),
              ),
            );
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
            Flexible(
              child: Text(
                context.tr(TranslationKeys.pricingSecurePayments),
                style: AppFonts.inter(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
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
