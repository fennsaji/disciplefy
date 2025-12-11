import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../entities/user_subscription_status.dart';

/// Abstract repository for subscription-related operations.
abstract class SubscriptionRepository {
  /// Creates a new premium subscription for the authenticated user.
  ///
  /// Creates a Razorpay subscription and returns authorization URL
  /// for the user to complete payment setup.
  ///
  /// Returns [CreateSubscriptionResult] with subscription details and payment URL on success.
  /// Returns [Failure] on error (network, server, authentication, validation, etc.).
  Future<Either<Failure, CreateSubscriptionResult>> createSubscription();

  /// Cancels the user's active subscription.
  ///
  /// [cancelAtCycleEnd] - If true, subscription remains active until current period ends.
  ///                      If false, cancels immediately and revokes premium access.
  /// [reason] - Optional cancellation reason for analytics
  ///
  /// Returns [CancelSubscriptionResult] with cancellation details on success.
  /// Returns [Failure] on error (network, server, authentication, validation, etc.).
  Future<Either<Failure, CancelSubscriptionResult>> cancelSubscription({
    required bool cancelAtCycleEnd,
    String? reason,
  });

  /// Resumes a cancelled subscription that is still within its billing period.
  ///
  /// Only works for subscriptions that were cancelled with cancel_at_cycle_end=true
  /// and are still active (i.e., current_period_end has not passed).
  ///
  /// Returns [ResumeSubscriptionResult] with resumption details on success.
  /// Returns [Failure] on error (network, server, authentication, validation, etc.).
  Future<Either<Failure, ResumeSubscriptionResult>> resumeSubscription();

  /// Gets the user's active subscription.
  ///
  /// Returns active [Subscription] on success, or null if user has no active subscription.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, Subscription?>> getActiveSubscription();

  /// Gets all subscriptions for the authenticated user (active and historical).
  ///
  /// Returns list of [Subscription] ordered by creation date (newest first) on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, List<Subscription>>> getSubscriptionHistory();

  /// Gets subscription invoices for the authenticated user.
  ///
  /// [limit] - Maximum number of invoices to return (optional)
  /// [offset] - Number of invoices to skip for pagination (optional)
  ///
  /// Returns list of [SubscriptionInvoice] on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, List<SubscriptionInvoice>>> getInvoices({
    int? limit,
    int? offset,
  });

  /// Gets the user's subscription status including trial information.
  ///
  /// Returns [UserSubscriptionStatus] with current plan, trial status,
  /// and subscription details.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, UserSubscriptionStatus>> getSubscriptionStatus();

  /// Creates a new Standard subscription for the authenticated user.
  ///
  /// Creates a Razorpay subscription for Standard plan (₹50/month)
  /// and returns authorization URL for the user to complete payment setup.
  ///
  /// Returns [CreateSubscriptionResult] with subscription details and payment URL on success.
  /// Returns [Failure] on error (network, server, authentication, validation, etc.).
  Future<Either<Failure, CreateSubscriptionResult>>
      createStandardSubscription();

  /// Starts a 7-day Premium trial for eligible users.
  ///
  /// Eligible users: New users who signed up after April 1st, 2025
  /// and haven't used their trial yet.
  ///
  /// Returns [StartPremiumTrialResult] with trial details on success.
  /// Returns [Failure] on error (network, server, authentication, not eligible, etc.).
  Future<Either<Failure, StartPremiumTrialResult>> startPremiumTrial();
}

/// Result of starting a Premium trial
class StartPremiumTrialResult {
  final DateTime trialStartedAt;
  final DateTime trialEndAt;
  final int daysRemaining;
  final String message;

  const StartPremiumTrialResult({
    required this.trialStartedAt,
    required this.trialEndAt,
    required this.daysRemaining,
    required this.message,
  });
}
