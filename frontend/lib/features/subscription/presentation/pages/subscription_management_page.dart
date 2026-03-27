import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/pricing_service.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../../domain/entities/subscription.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../tokens/domain/entities/token_status.dart';

/// Subscription Management Page
///
/// Allows users to view and manage their premium subscription including:
/// - Current subscription status
/// - Next billing date and amount
/// - Cancel subscription (immediate or at cycle end)
/// - View subscription history
class SubscriptionManagementPage extends StatefulWidget {
  const SubscriptionManagementPage({super.key});

  @override
  State<SubscriptionManagementPage> createState() =>
      _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState
    extends State<SubscriptionManagementPage> {
  @override
  void initState() {
    super.initState();
    // Load active subscription when page opens
    context.read<SubscriptionBloc>().add(const GetActiveSubscription());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(TranslationKeys.subscriptionTitle),
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
            },
            tooltip: context.tr(TranslationKeys.subscriptionRefresh),
          ),
        ],
      ),
      body: BlocBuilder<TokenBloc, TokenState>(
        builder: (context, tokenState) {
          // Get user plan info for Standard trial detection
          TokenStatus? tokenStatus;
          if (tokenState is TokenLoaded) {
            tokenStatus = tokenState.tokenStatus;
          }

          // Check if user is Standard trial (no subscription yet)
          // Use UserSubscriptionStatus from SubscriptionBloc if available,
          // otherwise fall back to TokenStatus plan check.
          final subState = context.read<SubscriptionBloc>().state;
          DateTime? trialEndDate;
          bool isTrialActive = false;
          if (subState is UserSubscriptionStatusLoaded) {
            isTrialActive = subState.subscriptionStatus.isTrialActive;
            trialEndDate = subState.subscriptionStatus.trialEndDate;
          }
          final isStandardTrialUser = tokenStatus != null &&
              tokenStatus.userPlan == UserPlan.standard &&
              isTrialActive;

          return BlocConsumer<SubscriptionBloc, SubscriptionState>(
            listener: (context, state) {
              if (state is SubscriptionCancelled) {
                // Show cancellation success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
              } else if (state is SubscriptionResumed) {
                // Show resumption success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              } else if (state is SubscriptionError) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Something went wrong. Please try again.'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state is SubscriptionLoading &&
                  (state.operation == 'fetching' ||
                      state.operation == 'cancelling' ||
                      state.operation == 'resuming')) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is SubscriptionLoaded) {
                if (state.activeSubscription == null) {
                  // Show Standard trial view for Standard users in trial period
                  if (isStandardTrialUser) {
                    return _buildStandardTrialView(trialEndDate);
                  }
                  return _buildNoSubscriptionView();
                }
                return _buildSubscriptionView(state.activeSubscription!, state);
              }

              if (state is SubscriptionError &&
                  state.previousSubscription != null) {
                return _buildSubscriptionView(
                    state.previousSubscription!, state);
              }

              // Default: check for Standard trial user
              if (isStandardTrialUser) {
                return _buildStandardTrialView(trialEndDate);
              }
              return _buildNoSubscriptionView();
            },
          );
        },
      ),
    );
  }

  Widget _buildNoSubscriptionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 80,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr(TranslationKeys.subscriptionNoActive),
              style: AppFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(TranslationKeys.subscriptionUpgradePrompt),
              style: AppFonts.inter(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.tr(TranslationKeys.subscriptionUpgradeButton),
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build view for Standard plan users in trial period (no subscription yet)
  Widget _buildStandardTrialView(DateTime? trialEndDate) {
    final standardColor = Theme.of(context).colorScheme.primary;
    const standardColorLight =
        Color(0xFFB794F4); // Lighter purple for dark mode
    final daysRemaining = trialEndDate?.difference(DateTime.now()).inDays ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-aware colors
    final iconColor = isDark ? standardColorLight : standardColor;
    final textColor = isDark ? standardColorLight : standardColor;
    final bannerBgColor =
        isDark ? standardColor.withOpacity(0.15) : const Color(0xFFF3E8FF);
    final bannerBorderColor =
        isDark ? standardColor.withOpacity(0.4) : const Color(0xFFD8B4FE);

    // Get Standard plan features
    final features = [
      context.tr(TranslationKeys.pricingStandardFeature1),
      context.tr(TranslationKeys.pricingStandardFeature2),
      context.tr(TranslationKeys.pricingStandardFeature3),
      context.tr(TranslationKeys.pricingStandardFeature4),
      context.tr(TranslationKeys.pricingStandardFeature5),
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Trial Status Card
          Card(
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
                    standardColor.withOpacity(0.15),
                    standardColor.withOpacity(0.05),
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
                          color: standardColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: iconColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Standard Plan',
                              style: AppFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Free Trial Active',
                              style: AppFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Trial info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bannerBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bannerBorderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: iconColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Free until ${_formatTrialDate(trialEndDate)}',
                                style: AppFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$daysRemaining days remaining',
                                style: AppFonts.inter(
                                  fontSize: 13,
                                  color: textColor.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Plan Details Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: iconColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr(TranslationKeys.subscriptionPlanDetails),
                        style: AppFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(TranslationKeys.subscriptionIncludedFeatures),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...features
                      .map((feature) => _buildFeatureItem(feature, iconColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // After Trial Info Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'After Trial Period',
                        style: AppFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'After ${_formatTrialDate(trialEndDate)}, you can continue using Standard features for just ${sl<PricingService>().getFormattedPricePerMonth('standard')}. We\'ll remind you before the trial ends.',
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatTrialDate(DateTime? date) {
    if (date == null) return 'the trial end date';
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

  Widget _buildSubscriptionView(
      Subscription subscription, SubscriptionState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<SubscriptionBloc>().add(const RefreshSubscription());
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(subscription),
            const SizedBox(height: 20),

            // Billing Information
            _buildBillingInfo(subscription),
            const SizedBox(height: 16),

            // Payment History Button
            _buildPaymentHistoryButton(),
            const SizedBox(height: 20),

            // Plan Details
            _buildPlanDetails(subscription),
            const SizedBox(height: 20),

            // Action Buttons
            _buildActionButtons(subscription, state),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Subscription subscription) {
    final isActive = subscription.isActive;
    final statusColor =
        isActive ? AppTheme.successColor : AppTheme.warningColor;
    final statusIcon =
        isActive ? Icons.check_circle_rounded : Icons.info_outline_rounded;

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
              statusColor.withOpacity(0.1),
              statusColor.withOpacity(0.05),
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
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.status.displayName,
                        style: AppFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subscription.status.description,
                        style: AppFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (subscription.isEndingSoon) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warningColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context
                            .tr(TranslationKeys.subscriptionEndsIn)
                            .replaceAll('{days}',
                                subscription.daysRemainingInPeriod.toString()),
                        style: AppFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillingInfo(Subscription subscription) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(TranslationKeys.subscriptionBillingInfo),
              style: AppFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context.tr(TranslationKeys.subscriptionAmount),
              '₹${subscription.amountRupees.toStringAsFixed(0)}${context.tr(TranslationKeys.subscriptionPerMonth)}',
              Icons.currency_rupee_rounded,
            ),
            if (subscription.nextBillingAt != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                context.tr(TranslationKeys.subscriptionNextBilling),
                dateFormat.format(subscription.nextBillingAt!),
                Icons.calendar_today_rounded,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                context.tr(TranslationKeys.subscriptionDaysUntilBilling),
                '${subscription.daysUntilNextBilling ?? '-'} ${context.tr(TranslationKeys.subscriptionDays)}',
                Icons.access_time_rounded,
              ),
            ],
            if (subscription.currentPeriodEnd != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                context.tr(TranslationKeys.subscriptionCurrentPeriodEnds),
                dateFormat.format(subscription.currentPeriodEnd!),
                Icons.event_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDetails(Subscription subscription) {
    // Format plan type nicely (premium_monthly -> Premium, standard -> Standard, plus -> Plus)
    // Defensive validation: handle null, empty, or malformed planType
    String formattedPlanType = 'Premium';
    final planType = subscription.planType.toLowerCase();
    final isStandardPlan = planType.contains('standard');
    final isPlusPlan = planType.contains('plus');

    if (planType.isNotEmpty) {
      final parts = planType.split('_');
      final firstPart = parts.first;
      if (firstPart.isNotEmpty) {
        formattedPlanType = firstPart[0].toUpperCase() + firstPart.substring(1);
      }
    }

    // Get features based on plan type
    final features = isStandardPlan
        ? [
            context.tr(TranslationKeys.pricingStandardFeature1),
            context.tr(TranslationKeys.pricingStandardFeature2),
            context.tr(TranslationKeys.pricingStandardFeature3),
            context.tr(TranslationKeys.pricingStandardFeature4),
            context.tr(TranslationKeys.pricingStandardFeature5),
          ]
        : isPlusPlan
            ? [
                '50 daily tokens (all study modes)',
                '10 follow-ups per guide',
                '10 AI Discipler conversations/month',
                '10 active memory verses',
                '3 practice sessions per verse per day',
                'All 8 practice modes',
              ]
            : [
                context.tr(TranslationKeys.pricingPremiumFeature1),
                context.tr(TranslationKeys.pricingPremiumFeature2),
                context.tr(TranslationKeys.pricingPremiumFeature3),
                context.tr(TranslationKeys.pricingPremiumFeature4),
                context.tr(TranslationKeys.pricingPremiumFeature5),
              ];

    // Plan icon and color based on type
    const plusColor = AppColors.warning; // Orange/amber for Plus
    final planIcon = isStandardPlan
        ? Icons.auto_awesome
        : isPlusPlan
            ? Icons.star_rounded
            : Icons.workspace_premium_rounded;
    final planColor = isStandardPlan
        ? Theme.of(context).colorScheme.primary
        : isPlusPlan
            ? plusColor
            : AppTheme.primaryColor;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  planIcon,
                  color: planColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr(TranslationKeys.subscriptionPlanDetails),
                  style: AppFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: planColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formattedPlanType,
              style: AppFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              context.tr(TranslationKeys.subscriptionIncludedFeatures),
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            ...features.map((feature) => _buildFeatureItem(feature, planColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature, [Color? checkColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: checkColor ?? AppTheme.successColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature,
              style: AppFonts.inter(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.primaryColor.withOpacity(0.7),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppFonts.inter(
              fontSize: 14,
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
        ),
        Text(
          value,
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentHistoryButton() {
    return OutlinedButton.icon(
      onPressed: () {
        context.push(AppRoutes.subscriptionPaymentHistory);
      },
      icon: const Icon(Icons.receipt_long_outlined, size: 20),
      label: Text(
        'Payment History',
        style: AppFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      Subscription subscription, SubscriptionState state) {
    final isLoading = state is SubscriptionLoading &&
        (state.operation == 'cancelling' || state.operation == 'resuming');

    // Paused subscriptions (Google Play) — direct user to Google Play to resume.
    if (subscription.status == SubscriptionStatus.paused) {
      return _buildPausedSubscriptionUI(subscription.provider);
    }

    // IAP subscriptions (Google Play / App Store) are managed through the respective app store.
    // We cannot cancel/resume IAP subscriptions via API — direct users to the store instead.
    // Use subscription.provider to check, NOT platform detection, so that a Razorpay subscriber
    // opening the app on Android is not incorrectly shown "Manage in Google Play".
    if (subscription.isIAPSubscription) {
      return _buildManageInStoreButton(subscription.provider);
    }

    // Check if subscription has pending cancellation (scheduled to cancel at end of cycle)
    final isCancelledButActive =
        subscription.status == SubscriptionStatus.pending_cancellation;

    if (isCancelledButActive) {
      // Show "Continue Subscription" button for cancelled-but-active subscriptions
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () {
                    context
                        .read<SubscriptionBloc>()
                        .add(const ResumeSubscription());
                  },
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.restart_alt_rounded),
            label: Text(
              context.tr(TranslationKeys.subscriptionContinueButton),
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }

    if (!subscription.canCancel) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed:
              isLoading ? null : () => _showCancelDialog(subscription, false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: BorderSide(color: AppTheme.errorColor),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr(TranslationKeys.subscriptionCancelAtEnd),
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Text(
                  context.tr(TranslationKeys.subscriptionCancelAtEnd),
                  style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed:
              isLoading ? null : () => _showCancelDialog(subscription, true),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr(TranslationKeys.subscriptionCancelImmediately),
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Text(
                  context.tr(TranslationKeys.subscriptionCancelImmediately),
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ],
    );
  }

  /// Builds a button that opens the platform's subscription management page.
  /// Used for Google Play and App Store subscriptions where cancellation
  /// cannot be done via API — users must manage them in the store.
  Widget _buildManageInStoreButton(String subscriptionProvider) {
    final isAndroid = subscriptionProvider == 'google_play';
    final storeLabel =
        isAndroid ? 'Manage in Google Play' : 'Manage in App Store';
    final storeIcon = isAndroid ? Icons.shop_rounded : Icons.apple_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Text(
            'To cancel or modify your subscription, please manage it through ${isAndroid ? 'Google Play' : 'the App Store'}.',
            style: AppFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _openStoreSubscriptions(isAndroid),
          icon: Icon(storeIcon, size: 20),
          label: Text(
            storeLabel,
            style: AppFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the UI shown when a subscription is paused (e.g. via Google Play).
  /// Directs the user to Google Play to resume their subscription.
  Widget _buildPausedSubscriptionUI(String subscriptionProvider) {
    final isAndroid = subscriptionProvider == 'google_play';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.warningColor.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.pause_circle_outline_rounded,
                color: AppTheme.warningColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your subscription is paused. Manage it in ${isAndroid ? 'Google Play' : 'the App Store'} to resume.',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _openStoreSubscriptions(isAndroid),
          icon: Icon(
            isAndroid ? Icons.shop_rounded : Icons.apple_rounded,
            size: 20,
          ),
          label: Text(
            isAndroid ? 'Resume in Google Play' : 'Resume in App Store',
            style: AppFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openStoreSubscriptions(bool isAndroid) async {
    final Uri uri = isAndroid
        ? Uri.parse(
            'https://play.google.com/store/account/subscriptions?package=com.disciplefy.bible_study_app',
          )
        : Uri.parse('https://apps.apple.com/account/subscriptions');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAndroid
                  ? 'Could not open Google Play. Search "Disciplefy" in Google Play > Subscriptions.'
                  : 'Could not open App Store. Go to Settings > Apple ID > Subscriptions.',
            ),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    }
  }

  void _showCancelDialog(Subscription subscription, bool immediate) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          immediate
              ? context.tr(TranslationKeys.subscriptionCancelImmediateTitle)
              : context.tr(TranslationKeys.subscriptionCancelEndTitle),
          style: AppFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        content: Text(
          immediate
              ? context.tr(TranslationKeys.subscriptionCancelImmediateMessage)
              : context
                  .tr(TranslationKeys.subscriptionCancelEndMessage)
                  .replaceAll(
                    '{date}',
                    DateFormat('MMM dd, yyyy').format(
                      subscription.currentPeriodEnd ??
                          subscription.nextBillingAt ??
                          DateTime.now().add(const Duration(days: 30)),
                    ),
                  ),
          style: AppFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr(TranslationKeys.subscriptionKeep)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _cancelSubscription(!immediate);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr(TranslationKeys.subscriptionConfirmCancel)),
          ),
        ],
      ),
    );
  }

  void _cancelSubscription(bool cancelAtCycleEnd) {
    context.read<SubscriptionBloc>().add(
          CancelSubscription(
            cancelAtCycleEnd: cancelAtCycleEnd,
            reason: cancelAtCycleEnd
                ? 'User requested cancellation at cycle end'
                : 'User requested immediate cancellation',
          ),
        );
  }
}
