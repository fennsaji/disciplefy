import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/payment_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/features/subscription/domain/entities/subscription.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/extensions/duration_extensions.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// Credits ("token management") in the quiet-ledger design.
///
/// Shows today's balance as the hero, the purchase / upgrade actions, the
/// current plan, daily credits per plan and links to both histories.
class TokenManagementPage extends StatefulWidget {
  const TokenManagementPage({super.key});

  @override
  State<TokenManagementPage> createState() => _TokenManagementPageState();
}

class _TokenManagementPageState extends State<TokenManagementPage>
    with WidgetsBindingObserver, RouteAware {
  // Payment confirmation guard to prevent duplicate calls
  final Set<String> _processingPayments = <String>{};

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect when app resumes
    WidgetsBinding.instance.addObserver(this);
    // Load token status when page opens
    context.read<TokenBloc>().add(const GetTokenStatus());
    // Load subscription status to check if user has active/cancelled subscription
    context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    context.read<SubscriptionBloc>().add(const LoadSubscriptionStatus());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh subscription data when returning to this page
    // This ensures we always have the latest subscription status
    if (ModalRoute.of(context)?.isCurrent == true) {
      Logger.debug(
          '[TokenManagement] Page became visible - refreshing subscription and token status');
      context.read<SubscriptionBloc>().add(const RefreshSubscription());
      context.read<TokenBloc>().add(const RefreshTokenStatus());
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes, refresh token status and subscription status
    if (state == AppLifecycleState.resumed) {
      Logger.debug(
          '[TokenManagement] App resumed - refreshing token and subscription status');
      context.read<TokenBloc>().add(const RefreshTokenStatus());
      context.read<SubscriptionBloc>().add(const RefreshSubscription());
    }
  }

  /// Get user email from auth state with fallback
  String _getUserEmail() {
    final authState = context.read<AuthBloc>().state;
    if (authState is auth_states.AuthenticatedState) {
      // Try auth email first, then profile email
      final email = authState.email ??
          authState.profile?['email'] as String? ??
          'nil@email.com';
      Logger.debug('[TokenManagement] User email: $email');
      return email;
    }
    Logger.debug('[TokenManagement] No auth state - using fallback email');
    return 'nil@email.com';
  }

  /// Get user phone from auth state with fallback
  String _getUserPhone() {
    final authState = context.read<AuthBloc>().state;
    if (authState is auth_states.AuthenticatedState) {
      // Try to get phone from profile or user metadata
      final phone = authState.profile?['phone'] as String? ??
          authState.user.userMetadata?['phone'] as String? ??
          authState.user.phone ??
          '+1234567890';
      Logger.debug('[TokenManagement] User phone: $phone');
      return phone;
    }
    Logger.debug('[TokenManagement] No auth state - using fallback phone');
    return '+1234567890';
  }

  Future<void> _showPurchaseDialog(TokenStatus tokenStatus) async {
    // Navigate to token purchase page
    Logger.debug('[TokenManagementPage] Navigating to token purchase page');

    final result =
        await context.push(AppRoutes.tokenPurchase, extra: tokenStatus);

    // If purchase was successful (page returned true), refresh token status.
    // The purchase page itself confirms the payment on its success screen.
    if (result == true && mounted) {
      Logger.debug(
          '[TokenManagementPage] Purchase successful, refreshing token status');
      context.read<TokenBloc>().add(const RefreshTokenStatus());
    }
  }

  void _upgradeToStandard() {
    context.push(AppRoutes.pricing);
  }

  /// Opens payment gateway for the given order
  // ignore: unused_element
  Future<void> _openPaymentGateway(
      String orderId, int tokenAmount, double amount, String keyId) async {
    try {
      Logger.debug(
          '[TokenManagementPage] Opening payment gateway for order: $orderId');

      await PaymentService().openCheckout(
        orderId: orderId,
        amount: amount,
        description: '$tokenAmount tokens for Disciplefy Bible Study',
        userEmail: _getUserEmail(),
        userPhone: _getUserPhone(),
        keyId: keyId,
        onSuccess: (response) {
          Logger.debug(
              '[TokenManagementPage] Payment gateway success - triggering confirmation');

          final paymentId = response.paymentId ?? '';
          final orderId = response.orderId ?? '';

          // Prevent duplicate confirmation calls
          if (_processingPayments.contains(paymentId)) {
            Logger.debug(
                '[TokenManagementPage] Payment $paymentId already being processed - ignoring duplicate');
            return;
          }

          // Mark payment as being processed
          _processingPayments.add(paymentId);

          // Get current token amount from BLoC state
          final currentState = context.read<TokenBloc>().state;
          int tokenAmount = 50; // Default minimum

          // Extract token amount from TokenOrderCreated state
          if (currentState is TokenOrderCreated) {
            tokenAmount = currentState.tokensToPurchase;
          }

          // Confirm payment
          context.read<TokenBloc>().add(
                ConfirmPayment(
                  paymentId: paymentId,
                  orderId: orderId,
                  signature: response.signature ?? '',
                  tokenAmount: tokenAmount,
                ),
              );
        },
        onError: (response) {
          Logger.debug(
              '[TokenManagementPage] Payment gateway error: ${response.message}');
          _showError();
        },
      );
    } catch (e) {
      Logger.debug('[TokenManagementPage] Error opening payment gateway: $e');
      _showError();
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(TranslationKeys.commonErrorTryAgain)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _upgradeToPremium() {
    context.push(AppRoutes.pricing);
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/generate-study');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return MultiBlocListener(
      listeners: [
        // Token BLoC listener for purchase success
        BlocListener<TokenBloc, TokenState>(
          listener: (context, state) {
            // Handle purchase success - refresh token status immediately
            if (state is TokenPurchaseSuccess) {
              Logger.debug(
                  '[TokenManagementPage] TokenPurchaseSuccess received - refreshing token status');
              context.read<TokenBloc>().add(const RefreshTokenStatus());
            }
          },
        ),
        // Subscription BLoC listener
        BlocListener<SubscriptionBloc, SubscriptionState>(
          listener: (context, state) {
            if (state is SubscriptionResumed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.result.message),
                  backgroundColor: AppColors.success,
                ),
              );
              // Refresh token status to update UI
              context.read<TokenBloc>().add(const RefreshTokenStatus());
              // Refresh subscription to clear pending_cancellation flag
              context.read<SubscriptionBloc>().add(const RefreshSubscription());
            } else if (state is SubscriptionError &&
                state.operation == 'resuming') {
              _showError();
            }
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          // Handle Android back button - navigate back to generate study page
          _goBack();
        },
        child: Scaffold(
          backgroundColor: palette.page,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(72),
            child: BlocBuilder<TokenBloc, TokenState>(
              builder: (context, state) {
                final status = _statusOf(state);
                return LedgerTopBar(
                  title: context.tr(TranslationKeys.ledgerCreditsTitle),
                  subtitle: status == null
                      ? null
                      : context.tr(TranslationKeys.ledgerPlanName,
                          {'plan': status.userPlan.displayName}),
                  onBack: _goBack,
                  actions: [
                    LedgerBarAction(
                      icon: Icons.history_rounded,
                      tooltip: context.tr('tokens.management.view_history'),
                      onPressed: () => context.push(AppRoutes.purchaseHistory),
                    ),
                    LedgerBarAction(
                      key: const Key('credits_refresh'),
                      icon: Icons.refresh_rounded,
                      tooltip: context.tr('tokens.management.refresh_status'),
                      onPressed: () => context
                          .read<TokenBloc>()
                          .add(const RefreshTokenStatus()),
                    ),
                  ],
                );
              },
            ),
          ),
          body: BlocBuilder<TokenBloc, TokenState>(
            builder: (context, state) {
              // If state is not token-related, trigger token refresh
              // but only if this page is currently visible (not in background)
              if (state is PurchaseHistoryLoaded ||
                  state is PurchaseStatisticsLoaded ||
                  state is PurchaseHistoryError) {
                if (ModalRoute.of(context)?.isCurrent == true) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    context.read<TokenBloc>().add(const GetTokenStatus());
                  });
                }
              }

              if (state is TokenLoading) {
                return const LedgerLoading();
              } else if (state is TokenError) {
                return LedgerMessage(
                  icon: Icons.error_outline_rounded,
                  isError: true,
                  title: context.tr('tokens.management.load_error'),
                  body: context.tr(TranslationKeys.commonErrorTryAgain),
                  actionLabel: context.tr('common.retry'),
                  onAction: () =>
                      context.read<TokenBloc>().add(const RefreshTokenStatus()),
                );
              }
              final status = _statusOf(state);
              if (status != null) return _buildTokenManagement(status);

              return LedgerLoading(
                label: context.tr('tokens.management.loading'),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Balance to show for [state]; while a purchase refresh is in flight the
  /// success state already carries the updated balance.
  TokenStatus? _statusOf(TokenState state) {
    if (state is TokenLoaded) return state.tokenStatus;
    if (state is TokenPurchaseSuccess) return state.updatedTokenStatus;
    return null;
  }

  Widget _buildTokenManagement(TokenStatus tokenStatus) {
    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, subscriptionState) {
        Subscription? subscription;
        bool isCancelledButActive = false;
        bool hasActiveSubscription = false;

        if (subscriptionState is SubscriptionLoaded &&
            subscriptionState.activeSubscription != null) {
          final sub = subscriptionState.activeSubscription!;
          subscription = sub;
          isCancelledButActive =
              sub.status == SubscriptionStatus.pending_cancellation;
          hasActiveSubscription = sub.status == SubscriptionStatus.active ||
              sub.status == SubscriptionStatus.authenticated ||
              sub.status == SubscriptionStatus.created ||
              sub.status == SubscriptionStatus.pending_cancellation;
        }

        // Trial end date for Standard plan — use backend value when available
        final subscriptionStatus =
            subscriptionState is UserSubscriptionStatusLoaded
                ? subscriptionState.subscriptionStatus
                : null;
        final trialEndDate =
            subscriptionStatus?.trialEndDate ?? DateTime(2027, 3, 31);
        final isTrialActive = DateTime.now().isBefore(trialEndDate);

        // Standard user in trial (no subscription yet)
        final isStandardTrialUser = tokenStatus.userPlan == UserPlan.standard &&
            isTrialActive &&
            !hasActiveSubscription;

        final purchaseEnabled =
            sl<SystemConfigService>().isTokenPurchaseEnabled;
        final subscriptionsEnabled =
            sl<SystemConfigService>().isNewSubscriptionsEnabled;
        final canBuy = tokenStatus.canPurchaseTokens && purchaseEnabled;
        final canUpgrade = subscriptionsEnabled &&
            (tokenStatus.userPlan == UserPlan.free ||
                tokenStatus.userPlan == UserPlan.standard ||
                tokenStatus.userPlan == UserPlan.plus);

        final palette = ReaderPalette.of(context);
        return RefreshIndicator(
          onRefresh: () async {
            context.read<TokenBloc>().add(const RefreshTokenStatus());
            context.read<SubscriptionBloc>().add(const RefreshSubscription());
            await Future<void>.delayed(const Duration(milliseconds: 600));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _BalanceHero(tokenStatus: tokenStatus),
              if (!_isUnlimited(tokenStatus)) ...[
                const SizedBox(height: 16),
                _BalanceTiles(tokenStatus: tokenStatus),
              ],
              if (canBuy || canUpgrade) ...[
                const LedgerHairline(verticalMargin: 16),
                _ActionsRow(
                  canBuy: canBuy,
                  canUpgrade: canUpgrade,
                  upgradeLabel: tokenStatus.userPlan == UserPlan.plus
                      ? context.tr('tokens.plans.upgrade_premium')
                      : context.tr(TranslationKeys.ledgerUpgrade),
                  onBuy: () => _showPurchaseDialog(tokenStatus),
                  onUpgrade: tokenStatus.userPlan == UserPlan.free
                      ? _upgradeToStandard
                      : _upgradeToPremium,
                ),
              ] else
                const SizedBox(height: 8),
              const SizedBox(height: 12),
              _PlanRow(
                tokenStatus: tokenStatus,
                subscription: subscription,
                onManage: () => context.push(AppRoutes.myPlan),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                    'tokens.plans.${tokenStatus.userPlan.name}_description'),
                style: AppFonts.inter(
                  fontSize: 13,
                  color: palette.muted,
                  height: 1.45,
                ),
              ),
              if (isCancelledButActive) ...[
                const SizedBox(height: 10),
                LedgerNotice(
                  icon: Icons.info_outline_rounded,
                  tone: LedgerTone.warning,
                  text: context.tr(TranslationKeys.plansCancelledNotice),
                ),
              ] else if (isStandardTrialUser) ...[
                const SizedBox(height: 10),
                LedgerNotice(
                  icon: Icons.auto_awesome_outlined,
                  text:
                      '${context.tr(TranslationKeys.myPlanFreeUntil)} ${DateFormat('MMMM d, y').format(trialEndDate)}',
                ),
              ],
              const LedgerHairline(verticalMargin: 14),
              _PlanAllowances(current: tokenStatus.userPlan),
              const LedgerHairline(verticalMargin: 14),
              LedgerSectionLabel(
                context.tr(TranslationKeys.ledgerActivity),
                padding: const EdgeInsets.only(top: 4, bottom: 4),
              ),
              _NavRow(
                icon: Icons.bar_chart_rounded,
                label: context.tr('tokens.usage.title'),
                onTap: () => context.push(AppRoutes.usageHistory),
              ),
              _NavRow(
                icon: Icons.receipt_long_outlined,
                label: context.tr('tokens.history.title'),
                onTap: () => context.push(AppRoutes.purchaseHistory),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _isUnlimited(TokenStatus s) =>
    s.isPremium || s.unlimitedUsage || s.userPlan == UserPlan.premium;

/// Ring with today's balance, plus the headline and reset time.
class _BalanceHero extends StatelessWidget {
  final TokenStatus tokenStatus;

  const _BalanceHero({required this.tokenStatus});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final unlimited = _isUnlimited(tokenStatus);
    final limit = tokenStatus.dailyLimit;
    final progress = unlimited
        ? 1.0
        : (limit <= 0 ? 0.0 : tokenStatus.availableTokens / limit);
    final resetAt = DateFormat.jm().format(tokenStatus.nextResetTime.toLocal());

    return Row(
      children: [
        LedgerRing(
          progress: progress,
          child: unlimited
              ? Icon(Icons.all_inclusive_rounded, size: 34, color: palette.gold)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${tokenStatus.availableTokens}',
                        style: AppFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          height: 1.1,
                          fontFeatures: kLedgerTabular,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.tr(
                            TranslationKeys.ledgerOfTotal, {'total': limit}),
                        maxLines: 1,
                        style: AppFonts.inter(
                            fontSize: 11.5, color: palette.muted),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LedgerSectionLabel(
                context.tr(TranslationKeys.ledgerDailyCredits),
                padding: const EdgeInsets.only(bottom: 4),
              ),
              _BalanceStatus(tokenStatus: tokenStatus),
              const SizedBox(height: 6),
              Text(
                unlimited
                    ? context.tr(TranslationKeys.ledgerUnlimitedTitle)
                    : context.tr(TranslationKeys.ledgerLeftToday,
                        {'count': tokenStatus.availableTokens}),
                style: AppFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.25,
                  fontFeatures: kLedgerTabular,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                unlimited
                    ? context.tr('tokens.stats.unlimited_description')
                    : context.tr(TranslationKeys.ledgerResetsAt, {
                        'time': resetAt,
                        'left': tokenStatus.timeUntilReset.toShortLabel(),
                      }),
                style: AppFonts.inter(
                  fontSize: 13,
                  color: palette.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Available", "Getting low" or "Running low" by the share of today's
/// allowance left; "Unlimited" on Premium.
class _BalanceStatus extends StatelessWidget {
  final TokenStatus tokenStatus;

  const _BalanceStatus({required this.tokenStatus});

  @override
  Widget build(BuildContext context) {
    if (_isUnlimited(tokenStatus)) {
      return LedgerStatusPill(
        key: const Key('credits_balance_status'),
        label: context.tr('tokens.balance.unlimited'),
        tone: LedgerTone.gold,
      );
    }
    final limit = tokenStatus.dailyLimit;
    final share = limit > 0 ? tokenStatus.totalTokens / limit : 0.0;
    final String key;
    final LedgerTone tone;
    if (share < 0.25) {
      key = 'tokens.balance.running_low';
      tone = LedgerTone.error;
    } else if (share < 0.5) {
      key = 'tokens.balance.getting_low';
      tone = LedgerTone.warning;
    } else {
      key = 'tokens.balance.available';
      tone = LedgerTone.success;
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: LedgerStatusPill(
        key: const Key('credits_balance_status'),
        label: context.tr(key),
        tone: tone,
      ),
    );
  }
}

class _BalanceTiles extends StatelessWidget {
  final TokenStatus tokenStatus;

  const _BalanceTiles({required this.tokenStatus});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return LedgerStatRow(
      tiles: [
        LedgerStatTile(
          value: '${tokenStatus.totalConsumedToday}',
          label: context.tr(TranslationKeys.ledgerUsedToday),
        ),
        LedgerStatTile(
          value: '${tokenStatus.purchasedTokens}',
          label: context.tr(TranslationKeys.ledgerPurchased),
          valueColor: palette.accentIcon,
        ),
        LedgerStatTile(
          value: '${tokenStatus.totalTokens}',
          label: context.tr(TranslationKeys.ledgerTotal),
          valueColor: palette.gold,
        ),
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final bool canBuy;
  final bool canUpgrade;
  final String upgradeLabel;
  final VoidCallback onBuy;
  final VoidCallback onUpgrade;

  const _ActionsRow({
    required this.canBuy,
    required this.canUpgrade,
    required this.upgradeLabel,
    required this.onBuy,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final buy = LedgerPrimaryButton(
      key: const Key('credits_get_credits'),
      label: context.tr(TranslationKeys.ledgerGetCredits),
      icon: Icons.add_rounded,
      onPressed: onBuy,
    );
    // The upgrade is the primary action when credits can't be bought.
    final upgrade = canBuy
        ? LedgerSecondaryButton(
            key: const Key('credits_upgrade'),
            label: upgradeLabel,
            icon: Icons.auto_awesome_outlined,
            onPressed: onUpgrade,
          )
        : LedgerPrimaryButton(
            key: const Key('credits_upgrade'),
            label: upgradeLabel,
            icon: Icons.auto_awesome_outlined,
            onPressed: onUpgrade,
          );
    if (canBuy && canUpgrade) {
      return LedgerButtonPair(
        first: buy,
        second: upgrade,
        labels: [context.tr(TranslationKeys.ledgerGetCredits), upgradeLabel],
      );
    }
    return SizedBox(width: double.infinity, child: canBuy ? buy : upgrade);
  }
}

/// Crown tile, plan name, price/renewal line and a Manage link.
class _PlanRow extends StatelessWidget {
  final TokenStatus tokenStatus;
  final Subscription? subscription;
  final VoidCallback onManage;

  const _PlanRow({
    required this.tokenStatus,
    required this.subscription,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final plan = tokenStatus.userPlan;
    final sub = subscription;
    final renewal = sub?.nextBillingAt ?? sub?.currentPeriodEnd;
    final String detail;
    if (sub != null && sub.amountPaise > 0 && renewal != null) {
      detail = context.tr(TranslationKeys.ledgerPriceRenews, {
        'price': '₹${sub.amountRupees.toStringAsFixed(0)}',
        'date': DateFormat('MMM d').format(renewal),
      });
    } else {
      detail = context.tr('tokens.plans.${plan.name}_subtitle');
    }

    return Row(
      children: [
        const LedgerIconTile(
          icon: Icons.workspace_premium_outlined,
          size: 40,
          tone: LedgerTone.gold,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                    TranslationKeys.ledgerPlanName, {'plan': plan.displayName}),
                style: AppFonts.inter(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: AppFonts.inter(
                  fontSize: 12.5,
                  color: palette.muted,
                  fontFeatures: kLedgerTabular,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        LedgerLink(
          key: const Key('credits_manage_plan'),
          label: context.tr('tokens.plans.manage'),
          onTap: onManage,
        ),
      ],
    );
  }
}

/// Daily credits of every plan, the current one in gold.
class _PlanAllowances extends StatelessWidget {
  final UserPlan current;

  const _PlanAllowances({required this.current});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerSectionLabel(
          context.tr(TranslationKeys.ledgerDailyByPlan),
          padding: const EdgeInsets.only(top: 4, bottom: 6),
        ),
        for (final plan in UserPlan.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LedgerRow(
                  label: plan == current
                      ? '${context.tr('tokens.plans.${plan.name}')} · ${context.tr('tokens.plans.current')}'
                      : context.tr('tokens.plans.${plan.name}'),
                  emphasizeLabel: plan == current,
                  value: context.tr('tokens.plans.${plan.name}_subtitle'),
                  valueColor: plan == current ? palette.gold : palette.muted,
                ),
                // Who the plan is for ("Best for group leaders").
                Text(
                  context.tr('tokens.plans.${plan.name}_desc'),
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    color: palette.dim,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: palette.text,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: palette.dim),
          ],
        ),
      ),
    );
  }
}
