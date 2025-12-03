import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';
import '../../domain/entities/subscription.dart';

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
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
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
                content: Text(state.errorMessage),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is SubscriptionLoading && state.operation == 'fetching') {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SubscriptionLoaded) {
            if (state.activeSubscription == null) {
              return _buildNoSubscriptionView();
            }
            return _buildSubscriptionView(state.activeSubscription!, state);
          }

          if (state is SubscriptionError &&
              state.previousSubscription != null) {
            return _buildSubscriptionView(state.previousSubscription!, state);
          }

          return _buildNoSubscriptionView();
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
                '${subscription.daysUntilNextBilling} ${context.tr(TranslationKeys.subscriptionDays)}',
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
    // Format plan type nicely (premium_monthly -> Premium)
    final formattedPlanType =
        subscription.planType.split('_').first.replaceFirst(
              subscription.planType.split('_').first[0],
              subscription.planType.split('_').first[0].toUpperCase(),
            );

    // Premium plan features
    final premiumFeatures = [
      context.tr(TranslationKeys.pricingPremiumFeature1),
      context.tr(TranslationKeys.pricingPremiumFeature2),
      context.tr(TranslationKeys.pricingPremiumFeature3),
      context.tr(TranslationKeys.pricingPremiumFeature4),
      context.tr(TranslationKeys.pricingPremiumFeature5),
    ];

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
                  Icons.workspace_premium_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr(TranslationKeys.subscriptionPlanDetails),
                  style: AppFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
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
            ...premiumFeatures.map((feature) => _buildFeatureItem(feature)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppTheme.successColor,
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

  Widget _buildActionButtons(
      Subscription subscription, SubscriptionState state) {
    final isLoading = state is SubscriptionLoading &&
        (state.operation == 'cancelling' || state.operation == 'resuming');

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
                    // Resume the cancelled subscription
                    context
                        .read<SubscriptionBloc>()
                        .add(const ResumeSubscription());
                  },
            icon: const Icon(Icons.restart_alt_rounded),
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
          child: Text(
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
          child: Text(
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
                    subscription.currentPeriodEnd != null
                        ? DateFormat('MMM dd, yyyy')
                            .format(subscription.currentPeriodEnd!)
                        : '',
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
