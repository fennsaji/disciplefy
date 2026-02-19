import 'package:flutter/material.dart';

import '../../domain/entities/user_subscription_status.dart';
import '../../../../core/services/pricing_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';

/// Banner widget shown on Home screen when user needs to subscribe
/// to Standard plan after trial ends, when trial is ending soon,
/// during grace period, or to promote Standard to new free users.
class StandardSubscriptionBanner extends StatelessWidget {
  /// The user's subscription status
  final UserSubscriptionStatus status;

  /// Callback when user taps subscribe button
  final VoidCallback onSubscribe;

  /// Callback when user dismisses the banner (optional)
  final VoidCallback? onDismiss;

  const StandardSubscriptionBanner({
    super.key,
    required this.status,
    required this.onSubscribe,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine banner style based on urgency
    // Urgent: trial expired, grace period ending soon (<=3 days), or trial ending soon (<=3 days)
    final isUrgent = status.hasTrialExpired ||
        status.isGracePeriodUrgent ||
        (status.needsSubscription && !status.isNewUserWithoutTrial) ||
        status.daysUntilTrialEnd <= 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
              : [AppColors.brandPrimary, const Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? const Color(0xFFFF6B6B) : AppColors.brandPrimary)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSubscribe,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isUrgent ? Icons.warning_rounded : Icons.star_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTitle(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getSubtitle(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dismiss button (if provided)
                    if (onDismiss != null && !status.needsSubscription)
                      IconButton(
                        onPressed: onDismiss,
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Subscribe button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSubscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isUrgent
                          ? const Color(0xFFFF6B6B)
                          : AppColors.brandPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Subscribe Now',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isUrgent
                                ? const Color(0xFFFF6B6B)
                                : AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          sl<PricingService>()
                              .getFormattedPricePerMonth('standard'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: (isUrgent
                                    ? const Color(0xFFFF6B6B)
                                    : AppColors.brandPrimary)
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    // Grace period states
    if (status.isInGracePeriod) {
      if (status.graceDaysRemaining <= 1) {
        return 'Grace Period Ends Today!';
      } else if (status.graceDaysRemaining <= 3) {
        return 'Only ${status.graceDaysRemaining} Days Left';
      }
      return 'Grace Period Active';
    }

    // Trial expired (after grace period)
    if (status.hasTrialExpired) {
      return 'Your Trial Has Ended';
    }

    // New user without trial (signed up after March 31)
    if (status.isNewUserWithoutTrial) {
      return 'Unlock Standard Features';
    }

    // Needs subscription (trial ended, no grace period)
    if (status.needsSubscription) {
      return 'Subscribe to Continue';
    }

    // Trial ending soon
    if (status.daysUntilTrialEnd <= 1) {
      return 'Trial Ends Today!';
    } else if (status.daysUntilTrialEnd <= 3) {
      return 'Only ${status.daysUntilTrialEnd} Days Left';
    }
    return 'Trial Ending Soon';
  }

  String _getSubtitle() {
    // Grace period states
    if (status.isInGracePeriod) {
      if (status.graceDaysRemaining <= 1) {
        return 'Subscribe now to keep your Standard access';
      }
      return 'Subscribe within ${status.graceDaysRemaining} days to keep Standard access';
    }

    // Trial expired (after grace period)
    if (status.hasTrialExpired) {
      return 'Subscribe to continue using Standard features';
    }

    // New user without trial (signed up after March 31)
    if (status.isNewUserWithoutTrial) {
      return 'Get 20 tokens daily for just ${sl<PricingService>().getFormattedPricePerMonth('standard')}';
    }

    // Needs subscription
    if (status.needsSubscription) {
      return 'Subscribe to continue using Standard features';
    }

    // Trial ending soon
    if (status.daysUntilTrialEnd <= 1) {
      return 'Subscribe now to keep your Standard access';
    }
    return 'Your free trial ends in ${status.daysUntilTrialEnd} days';
  }
}

/// Compact version of the banner for tighter spaces
class StandardSubscriptionBannerCompact extends StatelessWidget {
  final UserSubscriptionStatus status;
  final VoidCallback onSubscribe;

  const StandardSubscriptionBannerCompact({
    super.key,
    required this.status,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine urgency based on different states
    final isUrgent = status.hasTrialExpired ||
        status.isGracePeriodUrgent ||
        (status.needsSubscription && !status.isNewUserWithoutTrial) ||
        status.daysUntilTrialEnd <= 3;

    // For new users, use a promotional style (purple/blue) instead of urgent
    final isPromo = status.isNewUserWithoutTrial;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPromo
            ? const Color(0xFFE8F5E9) // Light green for promo
            : isUrgent
                ? const Color(0xFFFFF3E0)
                : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPromo
              ? const Color(0xFF81C784) // Green border for promo
              : isUrgent
                  ? const Color(0xFFFFB74D)
                  : const Color(0xFFD8B4FE),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPromo
                ? Icons.auto_awesome
                : isUrgent
                    ? Icons.access_time
                    : Icons.info_outline,
            color: isPromo
                ? const Color(0xFF388E3C)
                : isUrgent
                    ? const Color(0xFFE65100)
                    : AppColors.tierPlus,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status.statusMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isPromo
                    ? const Color(0xFF388E3C)
                    : isUrgent
                        ? const Color(0xFFE65100)
                        : AppColors.tierPlus,
              ),
            ),
          ),
          TextButton(
            onPressed: onSubscribe,
            style: TextButton.styleFrom(
              foregroundColor: isPromo
                  ? const Color(0xFF388E3C)
                  : isUrgent
                      ? const Color(0xFFE65100)
                      : AppColors.tierPlus,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(isPromo ? 'Upgrade' : 'Subscribe'),
          ),
        ],
      ),
    );
  }
}
