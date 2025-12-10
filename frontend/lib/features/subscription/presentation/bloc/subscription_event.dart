import 'package:equatable/equatable.dart';

/// Subscription BLoC Events
///
/// Defines all possible events that can occur in the subscription management system
abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

/// Event to fetch the user's active subscription
///
/// Triggers API call to check if user has an active premium subscription
class GetActiveSubscription extends SubscriptionEvent {
  const GetActiveSubscription();
}

/// Event to create a new premium subscription
///
/// Creates a Razorpay subscription and returns authorization URL
class CreateSubscription extends SubscriptionEvent {
  const CreateSubscription();
}

/// Event to cancel the user's active subscription
///
/// [cancelAtCycleEnd] - If true, remains active until period ends. If false, cancels immediately.
/// [reason] - Optional cancellation reason for analytics
class CancelSubscription extends SubscriptionEvent {
  final bool cancelAtCycleEnd;
  final String? reason;

  const CancelSubscription({
    required this.cancelAtCycleEnd,
    this.reason,
  });

  @override
  List<Object?> get props => [cancelAtCycleEnd, reason];

  @override
  String toString() =>
      'CancelSubscription(cancelAtCycleEnd: $cancelAtCycleEnd, reason: $reason)';
}

/// Event to resume a cancelled subscription
///
/// Reactivates a subscription that was cancelled with cancel_at_cycle_end=true
/// and is still within its billing period
class ResumeSubscription extends SubscriptionEvent {
  const ResumeSubscription();

  @override
  String toString() => 'ResumeSubscription()';
}

/// Event to refresh subscription status from the server
///
/// Forces a fresh API call to get latest subscription data
class RefreshSubscription extends SubscriptionEvent {
  const RefreshSubscription();
}

/// Event to fetch subscription history (all subscriptions: active and past)
///
/// Loads complete subscription history for the user
class GetSubscriptionHistory extends SubscriptionEvent {
  const GetSubscriptionHistory();
}

/// Event to fetch subscription invoices
///
/// [limit] - Maximum number of invoices to return (optional)
/// [offset] - Number of invoices to skip for pagination (optional)
class GetSubscriptionInvoices extends SubscriptionEvent {
  final int? limit;
  final int? offset;

  const GetSubscriptionInvoices({
    this.limit,
    this.offset,
  });

  @override
  List<Object?> get props => [limit, offset];
}

/// Event to open the Razorpay authorization URL
///
/// Triggered after successful subscription creation
/// Opens the URL in browser/WebView for user to complete payment setup
class OpenAuthorizationUrl extends SubscriptionEvent {
  final String authorizationUrl;

  const OpenAuthorizationUrl({
    required this.authorizationUrl,
  });

  @override
  List<Object?> get props => [authorizationUrl];

  @override
  String toString() => 'OpenAuthorizationUrl(url: $authorizationUrl)';
}

/// Event to handle subscription activation success
///
/// Triggered when webhook confirms subscription is activated
/// Updates UI to reflect premium status
class SubscriptionActivated extends SubscriptionEvent {
  final String subscriptionId;

  const SubscriptionActivated({
    required this.subscriptionId,
  });

  @override
  List<Object?> get props => [subscriptionId];

  @override
  String toString() => 'SubscriptionActivated(subscriptionId: $subscriptionId)';
}

/// Event to handle subscription expiration
///
/// Triggered when subscription expires or is cancelled
/// Downgrades user to standard plan
class SubscriptionExpired extends SubscriptionEvent {
  final String subscriptionId;
  final String reason;

  const SubscriptionExpired({
    required this.subscriptionId,
    required this.reason,
  });

  @override
  List<Object?> get props => [subscriptionId, reason];

  @override
  String toString() =>
      'SubscriptionExpired(subscriptionId: $subscriptionId, reason: $reason)';
}

/// Event to clear any error states and reset to initial state
///
/// Used when user dismisses error messages or retries operations
class ClearSubscriptionError extends SubscriptionEvent {
  const ClearSubscriptionError();
}

/// Event to check subscription eligibility
///
/// Verifies if user can create a new subscription
/// (not already premium, no active subscription, etc.)
class CheckSubscriptionEligibility extends SubscriptionEvent {
  const CheckSubscriptionEligibility();
}

/// Event to prefetch subscription data for performance
///
/// Proactively loads subscription data in background for faster UI responses
class PrefetchSubscriptionData extends SubscriptionEvent {
  const PrefetchSubscriptionData();
}

/// Event to load the user's subscription status including trial information
///
/// Fetches UserSubscriptionStatus with current plan, trial status, and subscription details
class LoadSubscriptionStatus extends SubscriptionEvent {
  const LoadSubscriptionStatus();
}

/// Event to create a new Standard subscription
///
/// Creates a Razorpay subscription for Standard plan (₹50/month)
/// Only allowed after trial period ends
class CreateStandardSubscription extends SubscriptionEvent {
  const CreateStandardSubscription();
}

/// Event to refresh subscription invoices from the server
///
/// Forces a fresh API call for latest invoice data
class RefreshSubscriptionInvoices extends SubscriptionEvent {
  const RefreshSubscriptionInvoices();
}

/// Event to start a 7-day Premium trial
///
/// Only available for new users who signed up after April 1st, 2025
/// and haven't used their trial yet
class StartPremiumTrial extends SubscriptionEvent {
  const StartPremiumTrial();
}
