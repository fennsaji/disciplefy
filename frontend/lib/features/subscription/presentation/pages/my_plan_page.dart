import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'package:disciplefy_bible_study/features/subscription/data/datasources/subscription_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/subscription.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/user_subscription_status.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/utils/plan_code.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/utils/plan_actions_policy.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/utils/plan_features_extractor.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/cancel_subscription_sheet.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Unified "My Plan" Page
///
/// Shows current plan details, subscription status, billing info,
/// payment history, and contextual actions for all users regardless
/// of their plan or subscription status.
class MyPlanPage extends StatefulWidget {
  const MyPlanPage({super.key});

  @override
  State<MyPlanPage> createState() => _MyPlanPageState();
}

class _MyPlanPageState extends State<MyPlanPage> with WidgetsBindingObserver {
  List<String> _planFeatures = [];
  bool _featuresLoading = true;
  // Plan display price fetched from the pricing API (provider-aware).
  double? _planDisplayPrice;
  // True while the pricing API call is in flight (shows spinner in amount row).
  bool _isPriceLoading = true;

  // Last-known values from each of the three requests this page fires.
  //
  // The bloc exposes one state at a time, but the page needs data from several
  // independent loads (active subscription, invoices, subscription status).
  // Reading them straight off the current state means whichever request settles
  // last wins and the others read as null — which made the Premium-trial banner
  // and the billing card appear or vanish depending purely on response order.
  // Caching each as it arrives keeps the screen stable.
  // Guards against opening the Razorpay tab more than once. Both the
  // UserSubscriptionStatusLoaded and SubscriptionCreated branches can carry an
  // authorizationUrl, and the state is re-emitted on every refresh/resume — so
  // without this the user gets a duplicate checkout tab each time.
  bool _hasOpenedPayment = false;

  Subscription? _subscription;
  List<SubscriptionInvoice> _invoices = [];
  UserSubscriptionStatus? _subscriptionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSubscriptionState();
    _loadPlanFeatures();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Checkout opens in an external tab/browser, so the app is never told how it
    // ended — Razorpay fires no event when the user simply closes the window.
    // Re-fetching on resume is what makes an abandoned, failed, or just-completed
    // payment show up without the user having to pull-to-refresh.
    if (state == AppLifecycleState.resumed) {
      _refreshSubscriptionState();
    }
  }

  /// Pull subscription, invoices and token status fresh from the backend.
  void _refreshSubscriptionState() {
    context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    context.read<SubscriptionBloc>().add(const GetSubscriptionInvoices());
    context.read<SubscriptionBloc>().add(const LoadSubscriptionStatus());
    // Force-refresh token status to avoid showing stale plan data from cache
    // (race condition can occur during subscription switches)
    context.read<TokenBloc>().add(const RefreshTokenStatus());
  }

  // The plan code used for the most recent _loadPlanFeatures call — used to
  // detect when the subscription plan changes (e.g. upgrade) and re-fetch.
  String? _loadedForPlanCode;

  /// Fetch plan features and display price from the get-plans Edge Function.
  ///
  /// [planCode] overrides the token-state plan code. Pass the subscription's
  /// planType when available so the price is always correct after upgrades/
  /// downgrades (token state can be stale at page-open time).
  Future<void> _loadPlanFeatures({String? planCode}) async {
    try {
      // A trial is stored as 'standard_trial' and a paid plan as
      // 'standard_monthly'; plans are keyed by the bare code ('standard').
      final resolvedPlanCode = normalizePlanCode(
        planCode != null && planCode.isNotEmpty
            ? planCode
            : currentPlanCode(sl<TokenBloc>().state),
      );

      // Use the platform's preferred provider so the price matches what the
      // user was actually charged (e.g. Google Play price on Android, not
      // the Razorpay price which is never used on that platform).
      final platformService = PlatformDetectionService();
      final providerString = platformService
          .providerToString(platformService.getPreferredProvider());

      final locale = sl<TranslationService>().currentLanguage.code;
      final response = await sl<SubscriptionRemoteDataSource>()
          .getPlans(provider: providerString, locale: locale);

      final matchingPlans =
          response.plans.where((p) => p.planCode == resolvedPlanCode).toList();
      // Never borrow another plan's features: falling back to the first
      // (Free) plan made a Standard trial list Free's limits.
      final plan = matchingPlans.isNotEmpty ? matchingPlans.first : null;
      if (plan == null) {
        Logger.warning(
          'No plan matches "$resolvedPlanCode"; showing no features',
          tag: 'MY_PLAN',
        );
      }

      if (mounted) {
        setState(() {
          _loadedForPlanCode = resolvedPlanCode;
          _planFeatures = plan == null
              ? []
              : PlanFeaturesExtractor.extractFeaturesFromPlan(plan);
          _planDisplayPrice = plan?.displayPrice;
          _featuresLoading = false;
          _isPriceLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _featuresLoading = false;
          _isPriceLoading = false;
        });
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.tokenManagement);
    }
  }

  void _refreshAll() {
    context.read<SubscriptionBloc>().add(const RefreshSubscription());
    context.read<SubscriptionBloc>().add(const RefreshSubscriptionInvoices());
    context.read<TokenBloc>().add(const RefreshTokenStatus());
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go(AppRoutes.tokenManagement);
        }
      },
      child: BlocBuilder<TokenBloc, TokenState>(
        builder: (context, tokenState) {
          TokenStatus? tokenStatus;
          if (tokenState is TokenLoaded) {
            tokenStatus = tokenState.tokenStatus;
          }

          return BlocConsumer<SubscriptionBloc, SubscriptionState>(
            listener: (context, state) {
              // Latch each load as it arrives so one settling doesn't blank
              // out the others (see the field declarations above).
              if (state is SubscriptionLoaded) {
                setState(() {
                  _subscription = state.activeSubscription;
                  _invoices = state.invoices ?? [];
                });
              } else if (state is UserSubscriptionStatusLoaded) {
                setState(() => _subscriptionStatus = state.subscriptionStatus);
              } else if (state is SubscriptionError &&
                  state.previousSubscription != null) {
                setState(() => _subscription = state.previousSubscription);
              }

              if (state is SubscriptionLoaded &&
                  state.activeSubscription != null) {
                // Re-fetch plan price if the loaded plan differs from what
                // was used at initState (e.g. after an upgrade/downgrade).
                final subPlanCode =
                    normalizePlanCode(state.activeSubscription!.planType);
                if (subPlanCode != _loadedForPlanCode) {
                  setState(() => _isPriceLoading = true);
                  _loadPlanFeatures(planCode: subPlanCode);
                }
              } else if (state is SubscriptionCancelled) {
                showAppSnackBar(
                  context,
                  state.message,
                  tone: AppSnackTone.warning,
                );
              } else if (state is SubscriptionResumed) {
                showAppSnackBar(
                  context,
                  state.message,
                  tone: AppSnackTone.success,
                );
              } else if (state is PremiumTrialStarted) {
                showAppSnackBar(
                  context,
                  state.message,
                  tone: AppSnackTone.success,
                );
                // Refresh token status to reflect new Premium access
                context.read<TokenBloc>().add(const RefreshTokenStatus());
              } else if (state is SubscriptionError) {
                showAppSnackBar(
                  context,
                  context.tr(TranslationKeys.commonErrorTryAgain),
                  tone: AppSnackTone.error,
                );
              } else if (state is UserSubscriptionStatusLoaded &&
                  state.authorizationUrl != null &&
                  !_hasOpenedPayment &&
                  ModalRoute.of(context)?.isCurrent == true) {
                // Open Razorpay payment URL
                _hasOpenedPayment = true;
                _openPaymentUrl(state.authorizationUrl!);
              } else if (state is SubscriptionCreated) {
                // Open Razorpay payment URL from create result (skip for IAP where URL is empty).
                //
                // SubscriptionBloc is an app-wide singleton, so this page keeps
                // listening while an upgrade page is pushed on top of it. Both
                // listeners would then open the same checkout URL — one tab each.
                // Only the visible route may open the browser.
                if (state.authorizationUrl.isNotEmpty &&
                    !_hasOpenedPayment &&
                    ModalRoute.of(context)?.isCurrent == true) {
                  _hasOpenedPayment = true;
                  _openPaymentUrl(state.authorizationUrl);
                }
              }
            },
            builder: (context, state) {
              // Read the latched values, not the current state — see the field
              // declarations. Using the state directly made these flip to null
              // whenever a different request happened to settle last.
              final subscription = _subscription;
              final invoices = _invoices;
              final subscriptionStatus = _subscriptionStatus;

              // Only treat the trial as active once the backend has actually
              // told us when it ends. The previous hardcoded 2027 fallback
              // meant an unloaded status silently read as "trial active".
              final trialEndDate = subscriptionStatus?.trialEndDate;
              final isTrialActive =
                  trialEndDate != null && DateTime.now().isBefore(trialEndDate);

              final onTrialSubscription = _isTrialSubscription(subscription);
              // The row's own end date first; the status call's as backup.
              final trialUntil = onTrialSubscription
                  ? (subscription!.currentPeriodEnd ?? trialEndDate)
                  : null;
              final status = _planStatus(
                tokenStatus,
                subscription,
                isTrialActive,
                subscriptionStatus,
                trialUntil,
              );

              final isFetching =
                  state is SubscriptionLoading && state.operation == 'fetching';

              return Scaffold(
                backgroundColor: palette.page,
                appBar: LedgerTopBar(
                  title: context.tr(TranslationKeys.myPlanTitle),
                  subtitle: isFetching ? null : status.label,
                  onBack: _goBack,
                  actions: [
                    LedgerBarAction(
                      icon: Icons.refresh_rounded,
                      tooltip: context.tr(TranslationKeys.myPlanRefresh),
                      onPressed: _refreshAll,
                    ),
                  ],
                ),
                body: isFetching
                    ? const LedgerLoading()
                    : RefreshIndicator(
                        onRefresh: () async {
                          context
                              .read<SubscriptionBloc>()
                              .add(const RefreshSubscription());
                          context
                              .read<SubscriptionBloc>()
                              .add(const RefreshSubscriptionInvoices());
                          await Future.delayed(const Duration(seconds: 1));
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          children: [
                            _buildPlanStatusCard(
                                tokenStatus, status, trialUntil),
                            ..._buildNotices(
                              tokenStatus,
                              subscription,
                              isTrialActive,
                              trialEndDate,
                              subscriptionStatus,
                            ),
                            // A trial bills nothing: no amount, store or
                            // billing date to show.
                            if (subscription != null && !onTrialSubscription)
                              _buildSubscriptionDetails(subscription),
                            _buildPlanFeatures(),
                            if (onTrialSubscription) _buildTrialNote(),
                            if (invoices.isNotEmpty)
                              _buildRecentPayments(tokenStatus, invoices),
                            const LedgerHairline(verticalMargin: 18),
                            _buildActionsSection(
                              tokenStatus,
                              subscription,
                              isTrialActive,
                              state,
                              subscriptionStatus,
                            ),
                          ],
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }

  /// Headline status shown under the title and as the card's pill.
  _PlanStatus _planStatus(
    TokenStatus? tokenStatus,
    Subscription? subscription,
    bool isTrialActive,
    UserSubscriptionStatus? subscriptionStatus,
    DateTime? trialUntil,
  ) {
    final userPlan = tokenStatus?.userPlan ?? UserPlan.free;

    // Check Premium trial first
    if (subscriptionStatus?.isInPremiumTrial == true) {
      final daysLeft = subscriptionStatus!.premiumTrialDaysRemaining;
      if (daysLeft <= 2) {
        return _PlanStatus(context.tr(TranslationKeys.myPlanTrialEndingSoon),
            LedgerTone.warning);
      }
      return _PlanStatus(context.tr(TranslationKeys.myPlanPremiumTrialActive),
          LedgerTone.accent);
    } else if (_isTrialSubscription(subscription)) {
      // Checked before isActive: a trial row counts as active, and calling it
      // an "Active Subscription" told trial users they were paying. Only the
      // row itself decides this — the status call's trial end date is one
      // global date returned to every user, paying subscribers included.
      // The pill only appears with its "Free trial until" line.
      return _PlanStatus(
          context.tr(TranslationKeys.myPlanTrialActive), LedgerTone.accent,
          pill: trialUntil == null
              ? null
              : context.tr(TranslationKeys.myPlanTrialPill));
    } else if (subscription != null && subscription.isActive) {
      if (subscription.isPendingUserCancellation) {
        return _PlanStatus(
            context.tr(TranslationKeys.myPlanCancellationPending),
            LedgerTone.warning);
      }
      return _PlanStatus(context.tr(TranslationKeys.myPlanActiveSubscription),
          LedgerTone.success,
          pill: context.tr(TranslationKeys.ledgerStatusActive));
    } else if (subscriptionStatus?.isInGracePeriod == true) {
      return _PlanStatus(
          context.tr(TranslationKeys.myPlanGracePeriod), LedgerTone.warning);
    } else if (subscriptionStatus?.hasTrialExpired == true) {
      return _PlanStatus(
          context.tr(TranslationKeys.myPlanTrialExpired), LedgerTone.error);
    } else if (subscriptionStatus?.isNewUserWithoutTrial == true) {
      return _PlanStatus(
          context.tr(TranslationKeys.myPlanFreePlan), LedgerTone.neutral);
    } else if (userPlan == UserPlan.standard && isTrialActive) {
      return _PlanStatus(
          context.tr(TranslationKeys.myPlanTrialActive), LedgerTone.accent);
    } else if (userPlan == UserPlan.free) {
      return _PlanStatus(
          context.tr(TranslationKeys.myPlanFreePlan), LedgerTone.neutral);
    }
    return _PlanStatus(
        context.tr(TranslationKeys.myPlanSubscriptionNeeded), LedgerTone.error);
  }

  /// True for the row the backend writes for a free trial. It has no store
  /// and nothing to cancel, whatever platform the user is on.
  bool _isTrialSubscription(Subscription? sub) =>
      sub != null &&
      (sub.status == SubscriptionStatus.trial || sub.provider == 'trial');

  /// The one raised block of the page: crown, plan name, status pill and,
  /// on a trial, when it ends. The features are listed once, below.
  Widget _buildPlanStatusCard(
    TokenStatus? tokenStatus,
    _PlanStatus status,
    DateTime? trialUntil,
  ) {
    final palette = ReaderPalette.of(context);
    final userPlan = tokenStatus?.userPlan ?? UserPlan.free;
    final summary = trialUntil == null
        ? ''
        : context.tr(TranslationKeys.myPlanFreeTrialUntil,
            {'date': _formatDate(trialUntil)});

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: palette.gold.withValues(alpha: palette.isDark ? 0.32 : 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 26, color: palette.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  userPlan.displayName,
                  style: AppFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              if (status.pill != null) ...[
                const SizedBox(width: 8),
                LedgerStatusPill(label: status.pill!, tone: status.tone),
              ],
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: AppFonts.inter(
                fontSize: 13.5,
                color: palette.gold,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Trial, grace-period, promo and cancellation notices under the card —
  /// the same conditions and copy as the old banners.
  List<Widget> _buildNotices(
    TokenStatus? tokenStatus,
    Subscription? subscription,
    bool isTrialActive,
    DateTime? trialEndDate,
    UserSubscriptionStatus? subscriptionStatus,
  ) {
    final userPlan = tokenStatus?.userPlan ?? UserPlan.free;
    final notices = <Widget>[];

    if (subscriptionStatus?.isInPremiumTrial == true) {
      final isUrgent = subscriptionStatus!.premiumTrialDaysRemaining <= 2;
      notices.add(LedgerNotice(
        icon:
            isUrgent ? Icons.timer_outlined : Icons.workspace_premium_outlined,
        tone: isUrgent ? LedgerTone.warning : LedgerTone.accent,
        text: isUrgent
            ? context.tr(TranslationKeys.myPlanPremiumTrialEndsSoon)
            : context.tr(TranslationKeys.myPlanEnjoyingPremium),
        detail: context
            .tr(TranslationKeys.myPlanDaysRemainingInTrial)
            .replaceAll('{days}',
                subscriptionStatus.premiumTrialDaysRemaining.toString()),
      ));
    } else if (subscriptionStatus?.canStartPremiumTrial == true) {
      notices.add(LedgerNotice(
        icon: Icons.auto_awesome_outlined,
        text: context.tr(TranslationKeys.myPlanTryPremiumFree),
        detail: context.tr(TranslationKeys.myPlanGet7DaysTrial),
      ));
    } else if (subscriptionStatus?.isInGracePeriod == true &&
        subscription == null) {
      final isUrgent = subscriptionStatus!.graceDaysRemaining <= 3;
      notices.add(LedgerNotice(
        icon: Icons.access_time_rounded,
        tone: isUrgent ? LedgerTone.warning : LedgerTone.accent,
        text: isUrgent
            ? context.tr(TranslationKeys.myPlanGracePeriodEndsSoon)
            : context.tr(TranslationKeys.myPlanGracePeriodActive),
        detail: context
            .tr(TranslationKeys.myPlanSubscribeWithinDays)
            .replaceAll(
                '{days}', subscriptionStatus.graceDaysRemaining.toString()),
      ));
    } else if (userPlan == UserPlan.standard &&
        isTrialActive &&
        trialEndDate != null &&
        subscription == null) {
      final daysRemaining = trialEndDate.difference(DateTime.now()).inDays;
      notices.add(LedgerNotice(
        icon: Icons.calendar_today_outlined,
        text:
            '${context.tr(TranslationKeys.myPlanFreeUntil)} ${_formatDate(trialEndDate)}',
        detail:
            '$daysRemaining ${context.tr(TranslationKeys.myPlanDaysRemaining)}',
      ));
    } else if (subscriptionStatus?.hasTrialExpired == true) {
      notices.add(LedgerNotice(
        icon: Icons.warning_amber_rounded,
        tone: LedgerTone.error,
        text: context.tr(TranslationKeys.myPlanTrialEnded),
        detail: context.tr(TranslationKeys.myPlanSubscribeToContinue),
      ));
    } else if (subscriptionStatus?.isNewUserWithoutTrial == true) {
      notices.add(LedgerNotice(
        icon: Icons.auto_awesome_outlined,
        tone: LedgerTone.success,
        text: context.tr(TranslationKeys.myPlanUnlockStandardFeatures),
        detail: context.tr(TranslationKeys.myPlanGetTokensDaily),
      ));
    }

    if (subscription?.isPendingUserCancellation == true) {
      notices.add(LedgerNotice(
        icon: Icons.info_outline_rounded,
        tone: LedgerTone.warning,
        text: context.tr(TranslationKeys.plansCancelledNotice),
        detail: subscription!.currentPeriodEnd != null
            ? '${context.tr(TranslationKeys.myPlanAccessUntil)} ${_formatDate(subscription.currentPeriodEnd!)}'
            : null,
      ));
    }

    return [
      for (final n in notices) ...[const SizedBox(height: 10), n],
    ];
  }

  Widget _buildSubscriptionDetails(Subscription subscription) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerSectionLabel(context.tr(TranslationKeys.ledgerBilling)),
        _buildAmountRow(subscription),
        _buildBillingDateRow(subscription),
        if (providerLabelOrNull(subscription.provider) case final store?)
          LedgerRow(
            label: context.tr(TranslationKeys.ledgerPaidWith),
            value: store,
          ),
        LedgerRow(
          label: context.tr(TranslationKeys.myPlanStatus),
          // A sub parked for an in-flight upgrade is still the user's live
          // plan — showing the raw 'Pending Cancellation' here contradicts
          // the "Active Subscription" header and alarms the user.
          value: subscription.isParkedForUpgrade
              ? SubscriptionStatus.active.displayName
              : subscription.status.displayName,
          valueColor:
              subscription.isActive ? context.appSuccess : context.appWarning,
        ),
      ],
    );
  }

  /// Builds the Amount billing row.
  /// For IAP subscriptions: shows a spinner while the pricing API is in
  /// flight, then the correct plan price (never the stale stored amount).
  /// For Razorpay: the stored amount is always accurate — no loading needed.
  Widget _buildAmountRow(Subscription subscription) {
    final label = context.tr(TranslationKeys.myPlanAmount);
    final perMonth = context.tr(TranslationKeys.ledgerPerMonth);
    // Razorpay: stored amount is accurate at all times.
    if (!subscription.isIAPSubscription) {
      final amount = subscription.amountPaise > 0
          ? '₹${subscription.amountRupees.toStringAsFixed(0)}$perMonth'
          : (_planDisplayPrice != null && _planDisplayPrice! > 0
              ? '₹${_planDisplayPrice!.toStringAsFixed(0)}$perMonth'
              : '—');
      return LedgerRow(label: label, value: amount);
    }

    // IAP: show spinner until the pricing API responds.
    if (_isPriceLoading) {
      return LedgerRow(
        label: label,
        valueWidget: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final amount = (_planDisplayPrice != null && _planDisplayPrice! > 0)
        ? '₹${_planDisplayPrice!.toStringAsFixed(0)}$perMonth'
        : '—';
    return LedgerRow(label: label, value: amount);
  }

  /// Billing date row — shows next billing / access-until date.
  /// Tries currentPeriodEnd first, then nextBillingAt as a fallback.
  /// For IAP subscriptions where neither date is stored locally, shows
  /// "Via Google Play" / "Via App Store" so the row is never blank.
  Widget _buildBillingDateRow(Subscription subscription) {
    final billingDate =
        subscription.currentPeriodEnd ?? subscription.nextBillingAt;
    final label = subscription.isActive
        ? context.tr(TranslationKeys.myPlanNextBilling)
        : context.tr(TranslationKeys.myPlanAccessUntil);

    if (billingDate != null) {
      return LedgerRow(label: label, value: _formatDate(billingDate));
    }

    final store = providerLabelOrNull(subscription.provider);
    if (subscription.isIAPSubscription && store != null) {
      return LedgerRow(label: label, value: 'Via $store');
    }

    return const SizedBox.shrink();
  }

  Widget _buildPlanFeatures() {
    final palette = ReaderPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerSectionLabel(context.tr(TranslationKeys.myPlanPlanFeatures)),
        if (_featuresLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LedgerLoading(),
          )
        else if (_planFeatures.isEmpty)
          Text(
            context.tr(TranslationKeys.myPlanNoFeatures),
            style: AppFonts.inter(fontSize: 14, color: palette.muted),
          )
        else
          for (final f in _planFeatures) LedgerCheckRow(f),
      ],
    );
  }

  /// Under the features on a trial: nothing is billed yet.
  Widget _buildTrialNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        context.tr(TranslationKeys.myPlanTrialNoPayment),
        style: AppFonts.inter(
          fontSize: 12.5,
          color: ReaderPalette.of(context).muted,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildRecentPayments(
      TokenStatus? tokenStatus, List<SubscriptionInvoice> invoices) {
    // Show only recent 3 invoices
    final recentInvoices = invoices.take(3).toList();
    final planName = (tokenStatus?.userPlan ?? UserPlan.free).displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerSectionLabel(
          context.tr(TranslationKeys.myPlanRecentPayments),
          trailing: LedgerLink(
            key: const Key('my_plan_view_all_payments'),
            label: context.tr(TranslationKeys.myPlanViewAll),
            onTap: () => context.push(AppRoutes.subscriptionPaymentHistory),
          ),
        ),
        for (final invoice in recentInvoices)
          LedgerRow(
            label:
                '${DateFormat('MMM d, y').format(invoice.createdAt)} · ${invoice.isPaid ? planName : invoice.status.toUpperCase()}',
            labelColor: invoice.isPaid ? null : context.appWarning,
            value: '₹${invoice.amountRupees.toStringAsFixed(0)}',
          ),
      ],
    );
  }

  Widget _buildActionsSection(
    TokenStatus? tokenStatus,
    Subscription? subscription,
    bool isTrialActive,
    SubscriptionState state,
    UserSubscriptionStatus? subscriptionStatus,
  ) {
    final isLoading = state is SubscriptionLoading &&
        (state.operation == 'cancelling' || state.operation == 'resuming');

    // Show spinner while cancel/resume API call is in progress (subscription becomes
    // null during SubscriptionLoading state, so buttons would disappear otherwise)
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LedgerLoading(),
      );
    }

    final subscriptionsEnabled =
        sl<SystemConfigService>().isNewSubscriptionsEnabled;
    final upgradeLabel = context.tr(TranslationKeys.ledgerUpgrade);

    // A trial has nothing to cancel: the only step is choosing a plan.
    if (_isTrialSubscription(subscription)) {
      if (!subscriptionsEnabled) return const SizedBox.shrink();
      return LedgerPrimaryButton(
        key: const Key('my_plan_view_plans'),
        label: context.tr(TranslationKeys.myPlanViewPlans),
        onPressed: () => context.push(AppRoutes.pricing),
      );
    }

    // Pending cancellation: resume button + upgrade (downgrade blocked until cycle ends)
    if (subscription?.isPendingUserCancellation == true) {
      final userPlan = tokenStatus?.userPlan ?? UserPlan.free;
      // Premium is the top tier — there is nothing to upgrade to.
      final canUpgrade = PlanActionsPolicy.canUpgrade(userPlan);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LedgerPrimaryButton(
            key: const Key('my_plan_resume'),
            label: context.tr(TranslationKeys.myPlanContinueSubscription),
            icon: Icons.restart_alt_rounded,
            onPressed: () => context
                .read<SubscriptionBloc>()
                .add(const ResumeSubscription()),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(TranslationKeys.myPlanResumeSubscription),
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 12.5,
              color: ReaderPalette.of(context).muted,
            ),
          ),
          if (canUpgrade && subscriptionsEnabled) ...[
            const SizedBox(height: 12),
            LedgerSecondaryButton(
              key: const Key('my_plan_upgrade'),
              label: upgradeLabel,
              icon: Icons.auto_awesome_outlined,
              onPressed: () => context.push(AppRoutes.pricing),
            ),
          ],
        ],
      );
    }

    // Active subscription: contextual plan-change buttons + cancel.
    // Tiers rank by enum order: free < standard < plus < premium.
    if (subscription != null && subscription.isActive) {
      final userPlan = tokenStatus?.userPlan ?? UserPlan.free;
      // Kill switch is folded in here so a hidden upgrade button doesn't
      // leave a stray gap.
      final canUpgrade = PlanActionsPolicy.canUpgrade(
        userPlan,
        newSubscriptionsEnabled: subscriptionsEnabled,
      );
      final canDowngrade = PlanActionsPolicy.canDowngrade(userPlan);
      final canCancel = PlanActionsPolicy.canCancel(userPlan);

      final upgrade = LedgerPrimaryButton(
        key: const Key('my_plan_upgrade'),
        label: upgradeLabel,
        icon: Icons.auto_awesome_outlined,
        onPressed: () => context.push(AppRoutes.pricing),
      );
      final cancel = LedgerSecondaryButton(
        key: const Key('my_plan_cancel'),
        label: context.tr(TranslationKeys.ledgerCancelPlan),
        onPressed: () => _showCancelConfirmationDialog(subscription, userPlan),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canUpgrade && canCancel)
            LedgerButtonPair(
              first: upgrade,
              second: cancel,
              labels: [
                upgradeLabel,
                context.tr(TranslationKeys.ledgerCancelPlan),
              ],
            )
          else if (canUpgrade)
            upgrade
          else if (canCancel)
            cancel,
          if (canCancel) ...[
            const SizedBox(height: 6),
            Text(
              context.tr(TranslationKeys.myPlanCancelAtPeriodEnd),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 12.5,
                color: ReaderPalette.of(context).muted,
              ),
            ),
          ],
          if (canDowngrade) ...[
            const SizedBox(height: 6),
            Center(
              child: LedgerLink(
                key: const Key('my_plan_downgrade'),
                label: context.tr(TranslationKeys.ledgerDowngrade),
                leadingIcon: Icons.south_rounded,
                onTap: () => context.push(AppRoutes.pricing),
              ),
            ),
          ],
        ],
      );
    }

    // All other states (trial, expired, free, grace period): Upgrade button
    // (hidden when new subscriptions are switched off).
    if (!subscriptionsEnabled) return const SizedBox.shrink();
    return LedgerPrimaryButton(
      key: const Key('my_plan_upgrade'),
      label: upgradeLabel,
      icon: Icons.auto_awesome_outlined,
      onPressed: () => context.push(AppRoutes.pricing),
    );
  }

  Future<void> _openPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.payFeedbackOpenPaymentPageFailed),
          tone: AppSnackTone.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          context.tr(TranslationKeys.commonErrorTryAgain),
          tone: AppSnackTone.error,
        );
      }
    }
  }

  Future<void> _showCancelConfirmationDialog(
      Subscription subscription, UserPlan userPlan) async {
    final bloc = context.read<SubscriptionBloc>();
    final choice = await CancelSubscriptionSheet.show(
      context,
      planName: userPlan.displayName,
      accessUntil: DateFormat('MMM d').format(
        subscription.currentPeriodEnd ??
            subscription.nextBillingAt ??
            DateTime.now().add(const Duration(days: 30)),
      ),
    );
    if (choice == null) return;
    bloc.add(
      const CancelSubscription(
        cancelAtCycleEnd: true,
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('MMMM d, y').format(date);
}

/// Resolved headline status of the plan.
class _PlanStatus {
  final String label;
  final LedgerTone tone;

  /// Short pill text on the plan card (an active subscription or a trial).
  final String? pill;

  const _PlanStatus(this.label, this.tone, {this.pill});
}
