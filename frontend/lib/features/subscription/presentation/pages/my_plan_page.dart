import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/i18n/translation_service.dart';
import '../../data/datasources/subscription_remote_data_source.dart';
import '../utils/plan_features_extractor.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/user_subscription_status.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_event.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../tokens/domain/entities/token_status.dart';
import '../widgets/premium_trial_banner.dart';

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

class _MyPlanPageState extends State<MyPlanPage> {
  List<String> _planFeatures = [];
  bool _featuresLoading = true;

  @override
  void initState() {
    super.initState();
    // Load subscription and invoices when page opens
    context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    context.read<SubscriptionBloc>().add(const GetSubscriptionInvoices());
    _loadPlanFeatures();
  }

  /// Fetch plan features from the DB via get-plans Edge Function,
  /// using the same data source as PricingPage for consistency.
  Future<void> _loadPlanFeatures() async {
    try {
      final tokenState = sl<TokenBloc>().state;
      final userPlan = tokenState is TokenLoaded
          ? tokenState.tokenStatus.userPlan
          : UserPlan.free;

      final locale = sl<TranslationService>().currentLanguage.code;
      final response = await sl<SubscriptionRemoteDataSource>()
          .getPlans(provider: 'razorpay', locale: locale);

      final plan = response.plans.firstWhere(
        (p) => p.planCode == userPlan.name,
        orElse: () => response.plans.first,
      );

      if (mounted) {
        setState(() {
          _planFeatures = PlanFeaturesExtractor.extractFeaturesFromPlan(plan);
          _featuresLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _featuresLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(TranslationKeys.myPlanTitle),
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
              context.read<SubscriptionBloc>().add(const RefreshSubscription());
              context
                  .read<SubscriptionBloc>()
                  .add(const RefreshSubscriptionInvoices());
            },
            tooltip: context.tr(TranslationKeys.myPlanRefresh),
          ),
        ],
      ),
      body: BlocBuilder<TokenBloc, TokenState>(
        builder: (context, tokenState) {
          TokenStatus? tokenStatus;
          if (tokenState is TokenLoaded) {
            tokenStatus = tokenState.tokenStatus;
          }

          // Determine plan status
          final trialEndDate = DateTime(2026, 3, 31);
          final isTrialActive = DateTime.now().isBefore(trialEndDate);

          return BlocConsumer<SubscriptionBloc, SubscriptionState>(
            listener: (context, state) {
              if (state is SubscriptionCancelled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
              } else if (state is SubscriptionResumed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              } else if (state is PremiumTrialStarted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
                // Refresh token status to reflect new Premium access
                context.read<TokenBloc>().add(const RefreshTokenStatus());
              } else if (state is SubscriptionError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Something went wrong. Please try again.'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              } else if (state is UserSubscriptionStatusLoaded &&
                  state.authorizationUrl != null) {
                // Open Razorpay payment URL
                _openPaymentUrl(state.authorizationUrl!);
              } else if (state is SubscriptionCreated) {
                // Open Razorpay payment URL from create result
                _openPaymentUrl(state.authorizationUrl);
              }
            },
            builder: (context, state) {
              if (state is SubscriptionLoading &&
                  state.operation == 'fetching') {
                return const Center(child: CircularProgressIndicator());
              }

              Subscription? subscription;
              List<SubscriptionInvoice> invoices = [];

              // Get subscription status for trial/grace period info
              final subscriptionStatus = state is UserSubscriptionStatusLoaded
                  ? state.subscriptionStatus
                  : null;

              if (state is SubscriptionLoaded) {
                subscription = state.activeSubscription;
                invoices = state.invoices ?? [];
              } else if (state is SubscriptionError &&
                  state.previousSubscription != null) {
                subscription = state.previousSubscription;
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context
                      .read<SubscriptionBloc>()
                      .add(const RefreshSubscription());
                  context
                      .read<SubscriptionBloc>()
                      .add(const RefreshSubscriptionInvoices());
                  await Future.delayed(const Duration(seconds: 1));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Plan Status Card (always shown)
                      _buildPlanStatusCard(
                        tokenStatus,
                        subscription,
                        isTrialActive,
                        trialEndDate,
                        subscriptionStatus,
                      ),
                      const SizedBox(height: 20),

                      // Plan Features Section (always shown)
                      _buildPlanFeaturesCard(tokenStatus),
                      const SizedBox(height: 20),

                      // Subscription Details (if has subscription)
                      if (subscription != null) ...[
                        _buildSubscriptionDetailsCard(subscription),
                        const SizedBox(height: 20),
                      ],

                      // Payment History Section (if has invoices)
                      if (invoices.isNotEmpty) ...[
                        _buildPaymentHistoryCard(invoices),
                        const SizedBox(height: 20),
                      ],

                      // Actions Section (contextual)
                      _buildActionsSection(
                        tokenStatus,
                        subscription,
                        isTrialActive,
                        state,
                        subscriptionStatus,
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildPlanStatusCard(
    TokenStatus? tokenStatus,
    Subscription? subscription,
    bool isTrialActive,
    DateTime trialEndDate,
    UserSubscriptionStatus? subscriptionStatus,
  ) {
    final userPlan = tokenStatus?.userPlan ?? UserPlan.free;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get plan colors
    final planColor = _getPlanColor(userPlan);
    final planIcon = _getPlanIcon(userPlan);

    // Determine status based on UserSubscriptionStatus if available
    String statusText;
    Color statusColor;
    IconData statusIcon;

    // Check Premium trial first
    if (subscriptionStatus?.isInPremiumTrial == true) {
      final daysLeft = subscriptionStatus!.premiumTrialDaysRemaining;
      if (daysLeft <= 2) {
        statusText = context.tr(TranslationKeys.myPlanTrialEndingSoon);
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.timer;
      } else {
        statusText = context.tr(TranslationKeys.myPlanPremiumTrialActive);
        statusColor = AppColors.tierPremium;
        statusIcon = Icons.workspace_premium;
      }
    } else if (subscription != null && subscription.isActive) {
      if (subscription.status == SubscriptionStatus.pending_cancellation) {
        statusText = context.tr(TranslationKeys.myPlanCancellationPending);
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.warning_rounded;
      } else {
        statusText = context.tr(TranslationKeys.myPlanActiveSubscription);
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle_rounded;
      }
    } else if (subscriptionStatus?.isInGracePeriod == true) {
      // Grace period state
      statusText = context.tr(TranslationKeys.myPlanGracePeriod);
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.access_time;
    } else if (subscriptionStatus?.hasTrialExpired == true) {
      // Trial expired state
      statusText = context.tr(TranslationKeys.myPlanTrialExpired);
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.warning_amber_rounded;
    } else if (subscriptionStatus?.isNewUserWithoutTrial == true) {
      // New user (never had trial)
      statusText = context.tr(TranslationKeys.myPlanFreePlan);
      statusColor = Colors.grey;
      statusIcon = Icons.person;
    } else if (userPlan == UserPlan.standard && isTrialActive) {
      statusText = context.tr(TranslationKeys.myPlanTrialActive);
      statusColor =
          isDark ? AppColors.brandPrimaryLight : AppColors.brandPrimary;
      statusIcon = Icons.auto_awesome;
    } else if (userPlan == UserPlan.free) {
      statusText = context.tr(TranslationKeys.myPlanFreePlan);
      statusColor = Colors.grey;
      statusIcon = Icons.person;
    } else {
      statusText = context.tr(TranslationKeys.myPlanSubscriptionNeeded);
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.info_outline;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              planColor.withOpacity(0.15),
              planColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: planColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    planIcon,
                    color: planColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userPlan.displayName,
                        style: AppFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: AppFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Premium trial banner (in trial or ending soon)
            if (subscriptionStatus?.isInPremiumTrial == true) ...[
              const SizedBox(height: 20),
              _buildPremiumTrialInfoBanner(subscriptionStatus!, isDark),
            ]
            // Can start Premium trial banner
            else if (subscriptionStatus?.canStartPremiumTrial == true) ...[
              const SizedBox(height: 20),
              _buildPremiumTrialPromoBanner(isDark),
            ]
            // Grace period banner
            else if (subscriptionStatus?.isInGracePeriod == true &&
                subscription == null) ...[
              const SizedBox(height: 20),
              _buildGracePeriodBanner(subscriptionStatus!, isDark),
            ]
            // Trial countdown or new user promo
            else if (userPlan == UserPlan.standard &&
                isTrialActive &&
                subscription == null) ...[
              const SizedBox(height: 20),
              _buildTrialInfoBanner(trialEndDate, isDark),
            ]
            // Trial expired banner
            else if (subscriptionStatus?.hasTrialExpired == true) ...[
              const SizedBox(height: 20),
              _buildTrialExpiredBanner(isDark),
            ]
            // New user promo banner
            else if (subscriptionStatus?.isNewUserWithoutTrial == true) ...[
              const SizedBox(height: 20),
              _buildNewUserPromoBanner(isDark),
            ],
            if (subscription?.status ==
                SubscriptionStatus.pending_cancellation) ...[
              const SizedBox(height: 20),
              _buildCancellationNoticeBanner(subscription!, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrialInfoBanner(DateTime trialEndDate, bool isDark) {
    const standardColor = AppColors.brandPrimary;
    final daysRemaining = trialEndDate.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? standardColor.withOpacity(0.15) : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark ? standardColor.withOpacity(0.4) : const Color(0xFFD8B4FE),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            color: isDark ? const Color(0xFFB794F4) : standardColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr(TranslationKeys.myPlanFreeUntil)} ${_formatDate(trialEndDate)}',
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFB794F4) : standardColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$daysRemaining ${context.tr(TranslationKeys.myPlanDaysRemaining)}',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: (isDark ? const Color(0xFFB794F4) : standardColor)
                        .withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGracePeriodBanner(UserSubscriptionStatus status, bool isDark) {
    final isUrgent = status.graceDaysRemaining <= 3;
    final bannerColor = isUrgent ? AppColors.warning : AppColors.brandPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? bannerColor.withOpacity(0.15)
            : isUrgent
                ? AppColors.warningLight
                : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? bannerColor.withOpacity(0.4)
              : isUrgent
                  ? AppColors.warning
                  : const Color(0xFFD8B4FE),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_amber_rounded : Icons.access_time_rounded,
            color: isDark
                ? bannerColor.withOpacity(0.8)
                : isUrgent
                    ? AppColors.warningDark
                    : AppColors.brandPrimary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrgent
                      ? context.tr(TranslationKeys.myPlanGracePeriodEndsSoon)
                      : context.tr(TranslationKeys.myPlanGracePeriodActive),
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? bannerColor.withOpacity(0.9)
                        : isUrgent
                            ? AppColors.warningDark
                            : AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context
                      .tr(TranslationKeys.myPlanSubscribeWithinDays)
                      .replaceAll(
                          '{days}', status.graceDaysRemaining.toString()),
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? bannerColor.withOpacity(0.8)
                        : (isUrgent
                                ? AppColors.warningDark
                                : AppColors.brandPrimary)
                            .withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialExpiredBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.error.withOpacity(0.15) : AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.error.withOpacity(0.4) : AppColors.error,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: isDark ? AppColors.error : AppColors.errorDark,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.myPlanTrialEnded),
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.error : AppColors.errorDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(TranslationKeys.myPlanSubscribeToContinue),
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: isDark ? AppColors.error : AppColors.errorDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewUserPromoBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.success.withOpacity(0.15)
            : AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark ? AppColors.success.withOpacity(0.4) : AppColors.success,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: isDark ? AppColors.success : AppColors.successDark,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.myPlanUnlockStandardFeatures),
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.success : AppColors.successDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(TranslationKeys.myPlanGetTokensDaily),
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: isDark ? AppColors.success : AppColors.successDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTrialInfoBanner(
      UserSubscriptionStatus status, bool isDark) {
    final isUrgent = status.premiumTrialDaysRemaining <= 2;
    final bannerColor = isUrgent ? AppColors.warning : AppColors.tierPremium;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? bannerColor.withOpacity(0.15)
            : isUrgent
                ? AppColors.warningLight
                : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? bannerColor.withOpacity(0.4)
              : isUrgent
                  ? AppColors.warning
                  : const Color(0xFFCE93D8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.timer : Icons.workspace_premium,
            color: isDark
                ? bannerColor.withOpacity(0.8)
                : isUrgent
                    ? AppColors.warningDark
                    : const Color(0xFF7B1FA2),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrgent
                      ? context.tr(TranslationKeys.myPlanPremiumTrialEndsSoon)
                      : context.tr(TranslationKeys.myPlanEnjoyingPremium),
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? bannerColor.withOpacity(0.9)
                        : isUrgent
                            ? AppColors.warningDark
                            : const Color(0xFF7B1FA2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context
                      .tr(TranslationKeys.myPlanDaysRemainingInTrial)
                      .replaceAll('{days}',
                          status.premiumTrialDaysRemaining.toString()),
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? bannerColor.withOpacity(0.8)
                        : (isUrgent
                                ? AppColors.warningDark
                                : const Color(0xFF7B1FA2))
                            .withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTrialPromoBanner(bool isDark) {
    const bannerColor = AppColors.tierPremium;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFFE040FB).withOpacity(0.2),
                  AppColors.tierPremium.withOpacity(0.2)
                ]
              : [
                  const Color(0xFFE040FB).withOpacity(0.1),
                  AppColors.tierPremium.withOpacity(0.1)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark ? bannerColor.withOpacity(0.4) : const Color(0xFFCE93D8),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bannerColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: isDark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.myPlanTryPremiumFree),
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFCE93D8)
                        : const Color(0xFF7B1FA2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(TranslationKeys.myPlanGet7DaysTrial),
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: (isDark
                            ? const Color(0xFFCE93D8)
                            : const Color(0xFF7B1FA2))
                        .withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationNoticeBanner(
      Subscription subscription, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.warning.withOpacity(0.15)
            : AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark ? AppColors.warning.withOpacity(0.4) : AppColors.warning,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? AppColors.warning : AppColors.warningDark,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.plansCancelledNotice),
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.warning : AppColors.warningDark,
                  ),
                ),
                if (subscription.currentPeriodEnd != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${context.tr(TranslationKeys.myPlanAccessUntil)} ${_formatDate(subscription.currentPeriodEnd!)}',
                    style: AppFonts.inter(
                      fontSize: 13,
                      color: isDark ? AppColors.warning : AppColors.warningDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanFeaturesCard(TokenStatus? tokenStatus) {
    final userPlan = tokenStatus?.userPlan ?? UserPlan.free;
    final planColor = _getPlanColor(userPlan);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  color: isDark ? planColor.withOpacity(0.8) : planColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr(TranslationKeys.myPlanPlanFeatures),
                  style: AppFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            if (_featuresLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_planFeatures.isEmpty)
              Text(
                'No features available',
                style: AppFonts.inter(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              )
            else
              ..._planFeatures.map((f) => _buildFeatureItem(f, planColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: AppFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDetailsCard(Subscription subscription) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr(TranslationKeys.myPlanBillingDetails),
                  style: AppFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow(
              context.tr(TranslationKeys.myPlanAmount),
              '\u20b9${subscription.amountRupees.toStringAsFixed(0)}/month',
            ),
            if (subscription.currentPeriodEnd != null)
              _buildDetailRow(
                subscription.isActive
                    ? context.tr(TranslationKeys.myPlanNextBilling)
                    : context.tr(TranslationKeys.myPlanAccessUntil),
                _formatDate(subscription.currentPeriodEnd!),
              ),
            _buildDetailRow(
              context.tr(TranslationKeys.myPlanStatus),
              subscription.status.displayName,
              valueColor: subscription.isActive
                  ? AppTheme.successColor
                  : AppTheme.warningColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard(List<SubscriptionInvoice> invoices) {
    // Show only recent 3 invoices
    final recentInvoices = invoices.take(3).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr(TranslationKeys.myPlanRecentPayments),
                      style: AppFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (invoices.length > 3)
                  TextButton(
                    onPressed: () {
                      context.push(AppRoutes.subscriptionPaymentHistory);
                    },
                    child: Text(
                      context.tr(TranslationKeys.myPlanViewAll),
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            ...recentInvoices.map((invoice) => _buildInvoiceItem(invoice)),
            if (invoices.length <= 3 && invoices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      context.push(AppRoutes.subscriptionPaymentHistory);
                    },
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(
                        context.tr(TranslationKeys.myPlanViewPaymentHistory)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItem(SubscriptionInvoice invoice) {
    final isPaid = invoice.status == 'paid';
    final statusColor = isPaid ? AppTheme.successColor : AppTheme.warningColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPaid ? Icons.check_circle : Icons.pending,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(invoice.createdAt),
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  invoice.status.toUpperCase(),
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\u20b9${invoice.amountRupees.toStringAsFixed(0)}',
            style: AppFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(
    TokenStatus? tokenStatus,
    Subscription? subscription,
    bool isTrialActive,
    SubscriptionState state,
    UserSubscriptionStatus? subscriptionStatus,
  ) {
    final isLoading = state is SubscriptionLoading;

    // Pending cancellation: resume button + view plans
    if (subscription?.status == SubscriptionStatus.pending_cancellation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionButton(
            label: context.tr(TranslationKeys.myPlanContinueSubscription),
            sublabel: context.tr(TranslationKeys.myPlanResumeSubscription),
            icon: Icons.restart_alt,
            color: AppTheme.successColor,
            isLoading: isLoading,
            onPressed: () => context
                .read<SubscriptionBloc>()
                .add(const ResumeSubscription()),
          ),
          const SizedBox(height: 12),
          _buildViewPlansButton(),
        ],
      );
    }

    // Active subscription: view plans (if standard, for upgrade) + cancel
    if (subscription != null && subscription.isActive) {
      final userPlan = tokenStatus?.userPlan ?? UserPlan.free;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (userPlan == UserPlan.standard) ...[
            _buildViewPlansButton(),
            const SizedBox(height: 12),
          ],
          _buildActionButton(
            label: context.tr(TranslationKeys.myPlanCancelSubscription),
            sublabel: context.tr(TranslationKeys.myPlanCancelAtPeriodEnd),
            icon: Icons.cancel_outlined,
            color: AppTheme.errorColor,
            isOutlined: true,
            isLoading: isLoading,
            onPressed: () => _showCancelConfirmationDialog(subscription),
          ),
        ],
      );
    }

    // All other states (trial, expired, free, grace period): single View Plans button
    return _buildViewPlansButton();
  }

  Widget _buildViewPlansButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.push(AppRoutes.pricing),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: const Icon(Icons.auto_awesome, size: 20),
        label: Text(
          'Upgrade',
          style: AppFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
    bool isLoading = false,
  }) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: AppFonts.inter(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        elevation: 2,
      ),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sublabel,
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open payment page. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showCancelConfirmationDialog(Subscription subscription) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          context.tr(TranslationKeys.subscriptionCancelEndTitle),
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          context.tr(TranslationKeys.subscriptionCancelEndMessage),
          style: AppFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.tr(TranslationKeys.subscriptionKeep),
              style: AppFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<SubscriptionBloc>().add(
                    const CancelSubscription(
                      cancelAtCycleEnd: true,
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              context.tr(TranslationKeys.subscriptionConfirmCancel),
              style: AppFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPlanColor(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return Colors.grey[600]!;
      case UserPlan.standard:
        return AppColors.brandPrimary;
      case UserPlan.plus:
        return Colors.purple[600]!;
      case UserPlan.premium:
        return Colors.amber[700]!;
    }
  }

  IconData _getPlanIcon(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return Icons.person;
      case UserPlan.standard:
        return Icons.auto_awesome;
      case UserPlan.plus:
        return Icons.workspace_premium;
      case UserPlan.premium:
        return Icons.star;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
