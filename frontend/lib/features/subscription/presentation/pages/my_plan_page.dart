import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
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
  @override
  void initState() {
    super.initState();
    // Load subscription and invoices when page opens
    context.read<SubscriptionBloc>().add(const GetActiveSubscription());
    context.read<SubscriptionBloc>().add(const GetSubscriptionInvoices());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Plan',
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
            tooltip: 'Refresh',
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
                    content: Text(state.errorMessage),
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
        statusText = 'Trial Ending Soon';
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.timer;
      } else {
        statusText = 'Premium Trial Active';
        statusColor = const Color(0xFF7C4DFF);
        statusIcon = Icons.workspace_premium;
      }
    } else if (subscription != null && subscription.isActive) {
      if (subscription.status == SubscriptionStatus.pending_cancellation) {
        statusText = 'Cancellation Pending';
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.warning_rounded;
      } else {
        statusText = 'Active Subscription';
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle_rounded;
      }
    } else if (subscriptionStatus?.isInGracePeriod == true) {
      // Grace period state
      statusText = 'Grace Period';
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.access_time;
    } else if (subscriptionStatus?.hasTrialExpired == true) {
      // Trial expired state
      statusText = 'Trial Expired';
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.warning_amber_rounded;
    } else if (subscriptionStatus?.isNewUserWithoutTrial == true) {
      // New user (never had trial)
      statusText = 'Free Plan';
      statusColor = Colors.grey;
      statusIcon = Icons.person;
    } else if (userPlan == UserPlan.standard && isTrialActive) {
      statusText = 'Trial Active';
      statusColor = const Color(0xFF6A4FB6);
      statusIcon = Icons.auto_awesome;
    } else if (userPlan == UserPlan.free) {
      statusText = 'Free Plan';
      statusColor = Colors.grey;
      statusIcon = Icons.person;
    } else {
      statusText = 'Subscription Needed';
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
    const standardColor = Color(0xFF6A4FB6);
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
                  'Free until ${_formatDate(trialEndDate)}',
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFB794F4) : standardColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$daysRemaining days remaining',
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
    final bannerColor = isUrgent ? Colors.orange : const Color(0xFF6A4FB6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? bannerColor.withOpacity(0.15)
            : isUrgent
                ? Colors.orange[50]
                : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? bannerColor.withOpacity(0.4)
              : isUrgent
                  ? Colors.orange[300]!
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
                    ? Colors.orange[700]
                    : const Color(0xFF6A4FB6),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrgent ? 'Grace period ends soon!' : 'Grace Period Active',
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? bannerColor.withOpacity(0.9)
                        : isUrgent
                            ? Colors.orange[900]
                            : const Color(0xFF6A4FB6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subscribe within ${status.graceDaysRemaining} days to keep Standard access',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? bannerColor.withOpacity(0.8)
                        : (isUrgent
                                ? Colors.orange[700]!
                                : const Color(0xFF6A4FB6))
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
        color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.red.withOpacity(0.4) : Colors.red[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: isDark ? Colors.red[300] : Colors.red[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Trial Has Ended',
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.red[200] : Colors.red[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subscribe to continue using Standard features',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.red[300] : Colors.red[700],
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
        color: isDark ? Colors.green.withOpacity(0.15) : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.green.withOpacity(0.4) : Colors.green[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: isDark ? Colors.green[300] : Colors.green[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock Standard Features',
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.green[200] : Colors.green[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get 100 tokens daily, AI study guides & more for just \u20b950/month',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.green[300] : Colors.green[700],
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
    final bannerColor = isUrgent ? Colors.orange : const Color(0xFF7C4DFF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? bannerColor.withOpacity(0.15)
            : isUrgent
                ? Colors.orange[50]
                : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? bannerColor.withOpacity(0.4)
              : isUrgent
                  ? Colors.orange[300]!
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
                    ? Colors.orange[700]
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
                      ? 'Premium trial ends soon!'
                      : 'Enjoying Premium Features',
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? bannerColor.withOpacity(0.9)
                        : isUrgent
                            ? Colors.orange[900]
                            : const Color(0xFF7B1FA2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${status.premiumTrialDaysRemaining} day${status.premiumTrialDaysRemaining == 1 ? '' : 's'} remaining in your free trial',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? bannerColor.withOpacity(0.8)
                        : (isUrgent
                                ? Colors.orange[700]!
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
    const bannerColor = Color(0xFF7C4DFF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFFE040FB).withOpacity(0.2),
                  const Color(0xFF7C4DFF).withOpacity(0.2)
                ]
              : [
                  const Color(0xFFE040FB).withOpacity(0.1),
                  const Color(0xFF7C4DFF).withOpacity(0.1)
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
                  'Try Premium FREE',
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
                  'Get 7 days of unlimited Premium features',
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
        color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.orange.withOpacity(0.4) : Colors.orange[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? Colors.orange[300] : Colors.orange[700],
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
                    color: isDark ? Colors.orange[200] : Colors.orange[900],
                  ),
                ),
                if (subscription.currentPeriodEnd != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Access until ${_formatDate(subscription.currentPeriodEnd!)}',
                    style: AppFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.orange[300] : Colors.orange[700],
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

    final features = _getPlanFeatures(userPlan);

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
                  'Plan Features',
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
            ...features.map((feature) => _buildFeatureItem(feature, planColor)),
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
                  'Billing Details',
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
              'Amount',
              '\u20b9${subscription.amountRupees.toStringAsFixed(0)}/month',
            ),
            if (subscription.currentPeriodEnd != null)
              _buildDetailRow(
                subscription.isActive ? 'Next Billing' : 'Access Until',
                _formatDate(subscription.currentPeriodEnd!),
              ),
            _buildDetailRow(
              'Status',
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
                      'Recent Payments',
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
                      'View All',
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
                    label: const Text('View Payment History'),
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
    final userPlan = tokenStatus?.userPlan ?? UserPlan.free;
    final isLoading = state is SubscriptionLoading;
    // Check for loading during standard subscription creation
    final isCreatingSubscription =
        (state is UserSubscriptionStatusLoaded && state.isLoading) ||
            (state is SubscriptionLoading &&
                state.operation == 'creating standard subscription');

    // Check for special states
    final isInGracePeriod = subscriptionStatus?.isInGracePeriod ?? false;
    final hasTrialExpired = subscriptionStatus?.hasTrialExpired ?? false;
    final isNewUserWithoutTrial =
        subscriptionStatus?.isNewUserWithoutTrial ?? false;

    // Premium trial states
    final canStartPremiumTrial =
        subscriptionStatus?.canStartPremiumTrial ?? false;
    final isInPremiumTrial = subscriptionStatus?.isInPremiumTrial ?? false;
    final isStartingPremiumTrial = state is SubscriptionLoading &&
        state.operation == 'starting premium trial';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Users eligible for Premium trial: Show start trial
        if (canStartPremiumTrial && !isInPremiumTrial) ...[
          _buildActionButton(
            label: 'Start 7-Day Premium Trial',
            sublabel: 'Try all Premium features FREE',
            icon: Icons.rocket_launch,
            color: const Color(0xFF6A4FB6),
            isLoading: isStartingPremiumTrial,
            onPressed: () {
              context.read<SubscriptionBloc>().add(
                    const StartPremiumTrial(),
                  );
            },
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Upgrade to Standard',
            sublabel: '\u20b950/month',
            icon: Icons.auto_awesome,
            color: Colors.teal[600]!,
            isLoading: isCreatingSubscription,
            onPressed: () => context.push(AppRoutes.standardUpgrade),
            isOutlined: true,
          ),
        ]
        // Users in Premium trial: Show upgrade options
        else if (isInPremiumTrial) ...[
          _buildActionButton(
            label: 'Upgrade to Premium',
            sublabel: 'Keep Premium access for \u20b9100/month',
            icon: Icons.workspace_premium,
            color: Colors.amber[700]!,
            onPressed: () => context.push(AppRoutes.premiumUpgrade),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Subscribe to Standard',
            sublabel: '\u20b950/month after trial',
            icon: Icons.auto_awesome,
            color: const Color(0xFF6A4FB6),
            isLoading: isCreatingSubscription,
            onPressed: () => context.push(AppRoutes.standardUpgrade),
            isOutlined: true,
          ),
        ]
        // Grace period users: Show urgent subscribe
        else if (isInGracePeriod && subscription == null) ...[
          _buildActionButton(
            label: 'Subscribe Now',
            sublabel: 'Keep Standard access for \u20b950/month',
            icon: Icons.credit_card,
            color: subscriptionStatus!.graceDaysRemaining <= 3
                ? Colors.orange[700]!
                : const Color(0xFF6A4FB6),
            isLoading: isCreatingSubscription,
            onPressed: () => context.push(AppRoutes.standardUpgrade),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Upgrade to Premium',
            sublabel: 'Get all features for \u20b9100/month',
            icon: Icons.workspace_premium,
            color: Colors.amber[700]!,
            onPressed: () => context.push(AppRoutes.premiumUpgrade),
            isOutlined: true,
          ),
        ]
        // Trial expired users: Show subscribe to regain access
        else if (hasTrialExpired) ...[
          _buildActionButton(
            label: 'Subscribe to Standard',
            sublabel: 'Regain access for \u20b950/month',
            icon: Icons.auto_awesome,
            color: const Color(0xFF6A4FB6),
            isLoading: isCreatingSubscription,
            onPressed: () => context.push(AppRoutes.standardUpgrade),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Upgrade to Premium',
            sublabel: 'Get all features for \u20b9100/month',
            icon: Icons.workspace_premium,
            color: Colors.amber[700]!,
            onPressed: () => context.push(AppRoutes.premiumUpgrade),
            isOutlined: true,
          ),
        ]
        // New users (never had trial): Show promo
        else if (isNewUserWithoutTrial) ...[
          _buildActionButton(
            label: 'Upgrade to Standard',
            sublabel: 'Get 100 tokens daily for \u20b950/month',
            icon: Icons.auto_awesome,
            color: const Color(0xFF6A4FB6),
            isLoading: isCreatingSubscription,
            onPressed: () => context.push(AppRoutes.standardUpgrade),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Upgrade to Premium',
            sublabel: 'Unlimited tokens for \u20b9100/month',
            icon: Icons.workspace_premium,
            color: Colors.amber[700]!,
            onPressed: () => context.push(AppRoutes.premiumUpgrade),
            isOutlined: true,
          ),
        ]
        // Free users (generic): Show upgrade options
        else if (userPlan == UserPlan.free) ...[
          _buildActionButton(
            label: 'Upgrade to Standard',
            sublabel: '\u20b950/month',
            icon: Icons.auto_awesome,
            color: const Color(0xFF6A4FB6),
            isLoading: isCreatingSubscription,
            onPressed: () => context.push(AppRoutes.standardUpgrade),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Upgrade to Premium',
            sublabel: '\u20b9100/month',
            icon: Icons.workspace_premium,
            color: Colors.amber[700]!,
            onPressed: () => context.push(AppRoutes.premiumUpgrade),
          ),
        ]
        // Standard trial (no subscription): Show subscribe now
        else if (userPlan == UserPlan.standard &&
            subscription == null &&
            isTrialActive) ...[
          _buildActionButton(
            label: 'Subscribe Now',
            sublabel: 'Continue after trial for \u20b950/month',
            icon: Icons.credit_card,
            color: const Color(0xFF6A4FB6),
            isLoading: isCreatingSubscription,
            onPressed: () => context.push(AppRoutes.standardUpgrade),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'Upgrade to Premium',
            sublabel: 'Get all features for \u20b9100/month',
            icon: Icons.workspace_premium,
            color: Colors.amber[700]!,
            onPressed: () => context.push(AppRoutes.premiumUpgrade),
            isOutlined: true,
          ),
        ]
        // Active subscription with pending cancellation: Show continue option
        else if (subscription?.status ==
            SubscriptionStatus.pending_cancellation) ...[
          _buildActionButton(
            label: 'Continue Subscription',
            sublabel: 'Resume your subscription',
            icon: Icons.restart_alt,
            color: AppTheme.successColor,
            isLoading: isLoading,
            onPressed: () {
              context.read<SubscriptionBloc>().add(
                    const ResumeSubscription(),
                  );
            },
          ),
          if (userPlan == UserPlan.standard) ...[
            const SizedBox(height: 12),
            _buildActionButton(
              label: 'Upgrade to Premium',
              sublabel: 'Get more features',
              icon: Icons.workspace_premium,
              color: Colors.amber[700]!,
              onPressed: () => context.push(AppRoutes.premiumUpgrade),
              isOutlined: true,
            ),
          ],
        ]
        // Active subscription: Show cancel option
        else if (subscription != null && subscription.isActive) ...[
          if (userPlan == UserPlan.standard) ...[
            _buildActionButton(
              label: 'Upgrade to Premium',
              sublabel: 'Get all features for \u20b9100/month',
              icon: Icons.workspace_premium,
              color: Colors.amber[700]!,
              onPressed: () => context.push(AppRoutes.premiumUpgrade),
            ),
            const SizedBox(height: 12),
          ],
          _buildActionButton(
            label: 'Cancel Subscription',
            sublabel: 'Cancel at period end',
            icon: Icons.cancel_outlined,
            color: AppTheme.errorColor,
            isOutlined: true,
            isLoading: isLoading,
            onPressed: () => _showCancelConfirmationDialog(subscription),
          ),
        ]
        // Expired subscription: Show resubscribe
        else if (subscription != null && !subscription.isActive) ...[
          _buildActionButton(
            label: 'Resubscribe',
            sublabel: 'Renew your subscription',
            icon: Icons.refresh,
            color: AppTheme.primaryColor,
            onPressed: () {
              if (userPlan == UserPlan.standard) {
                context.push(AppRoutes.standardUpgrade);
              } else {
                context.push(AppRoutes.premiumUpgrade);
              }
            },
          ),
        ],
      ],
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
            content: Text('Failed to open payment page: $e'),
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
        return const Color(0xFF6A4FB6);
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
      case UserPlan.premium:
        return Icons.workspace_premium;
    }
  }

  List<String> _getPlanFeatures(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return [
          context.tr(TranslationKeys.pricingFreeFeature1),
          context.tr(TranslationKeys.pricingFreeFeature2),
          context.tr(TranslationKeys.pricingFreeFeature3),
          context.tr(TranslationKeys.pricingFreeFeature4),
        ];
      case UserPlan.standard:
        return [
          context.tr(TranslationKeys.pricingStandardFeature1),
          context.tr(TranslationKeys.pricingStandardFeature2),
          context.tr(TranslationKeys.pricingStandardFeature3),
          context.tr(TranslationKeys.pricingStandardFeature4),
          context.tr(TranslationKeys.pricingStandardFeature5),
        ];
      case UserPlan.premium:
        return [
          context.tr(TranslationKeys.pricingPremiumFeature1),
          context.tr(TranslationKeys.pricingPremiumFeature2),
          context.tr(TranslationKeys.pricingPremiumFeature3),
          context.tr(TranslationKeys.pricingPremiumFeature4),
          context.tr(TranslationKeys.pricingPremiumFeature5),
        ];
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
