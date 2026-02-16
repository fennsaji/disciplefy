import 'package:equatable/equatable.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/user_subscription_status.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/pricing_service.dart';
import '../../../../core/di/injection_container.dart';

/// Subscription BLoC States
///
/// Represents all possible states in the subscription management system
abstract class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

/// Initial state when the subscription BLoC is first created
///
/// No subscription data has been loaded yet
class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

/// State when subscription data is being loaded from the API
///
/// Shows loading indicators to the user
class SubscriptionLoading extends SubscriptionState {
  final String? operation; // 'fetching', 'creating', 'cancelling', 'refreshing'

  const SubscriptionLoading({this.operation});

  @override
  List<Object?> get props => [operation];
}

/// State when subscription data has been successfully loaded
///
/// Contains the active subscription or null if user has no subscription
class SubscriptionLoaded extends SubscriptionState {
  final Subscription? activeSubscription;
  final List<Subscription>? subscriptionHistory;
  final List<SubscriptionInvoice>? invoices;
  final DateTime lastUpdated;
  final bool isRefreshing; // True when refreshing in background

  const SubscriptionLoaded({
    this.activeSubscription,
    this.subscriptionHistory,
    this.invoices,
    required this.lastUpdated,
    this.isRefreshing = false,
  });

  @override
  List<Object?> get props => [
        activeSubscription,
        subscriptionHistory,
        invoices,
        lastUpdated,
        isRefreshing,
      ];

  /// Create a copy with updated fields
  SubscriptionLoaded copyWith({
    Subscription? activeSubscription,
    List<Subscription>? subscriptionHistory,
    List<SubscriptionInvoice>? invoices,
    DateTime? lastUpdated,
    bool? isRefreshing,
  }) {
    return SubscriptionLoaded(
      activeSubscription: activeSubscription ?? this.activeSubscription,
      subscriptionHistory: subscriptionHistory ?? this.subscriptionHistory,
      invoices: invoices ?? this.invoices,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  /// Check if subscription data is stale and needs refreshing
  bool get isStale {
    final now = DateTime.now();
    final staleDuration =
        Duration(minutes: 10); // Consider stale after 10 minutes
    return now.difference(lastUpdated) > staleDuration;
  }

  /// Check if user has premium access
  bool get hasPremiumAccess {
    return activeSubscription?.isActive ?? false;
  }

  /// Get user-friendly status message
  String get statusMessage {
    if (activeSubscription == null) {
      return 'No active subscription';
    } else if (activeSubscription!.isActive) {
      return 'Premium active';
    } else if (activeSubscription!.status == SubscriptionStatus.cancelled) {
      final daysRemaining = activeSubscription!.daysRemainingInPeriod;
      if (daysRemaining != null && daysRemaining > 0) {
        return 'Cancelled - $daysRemaining days remaining';
      } else {
        return 'Subscription cancelled';
      }
    } else {
      return activeSubscription!.status.displayName;
    }
  }

  /// Check if subscription is ending soon (within 7 days)
  bool get isEndingSoon {
    return activeSubscription?.isEndingSoon ?? false;
  }

  /// Get days until next billing
  int? get daysUntilNextBilling {
    return activeSubscription?.daysUntilNextBilling;
  }
}

/// State when subscription has been created and awaiting payment authorization
///
/// Contains the authorization URL for user to complete payment setup
class SubscriptionCreated extends SubscriptionState {
  final CreateSubscriptionResult result;
  final DateTime createdAt;

  const SubscriptionCreated({
    required this.result,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [result, createdAt];

  /// Get the authorization URL for opening in browser
  String get authorizationUrl => result.authorizationUrl;

  /// Get subscription ID
  String get subscriptionId => result.subscriptionId;

  /// Get amount in rupees
  double get amountRupees => result.amountRupees;
}

/// State when subscription has been cancelled successfully
///
/// Contains cancellation details and when access ends
class SubscriptionCancelled extends SubscriptionState {
  final CancelSubscriptionResult result;
  final DateTime cancelledAt;

  const SubscriptionCancelled({
    required this.result,
    required this.cancelledAt,
  });

  @override
  List<Object?> get props => [result, cancelledAt];

  /// Check if subscription remains active until period end
  bool get activeUntilPeriodEnd => result.activeUntil != null;

  /// Get the date when premium access ends
  DateTime? get accessEndsAt => result.activeUntil;

  /// Get user-friendly message
  String get message => result.message;
}

/// State when subscription has been resumed successfully
///
/// Contains resumption details and updated subscription status
class SubscriptionResumed extends SubscriptionState {
  final ResumeSubscriptionResult result;
  final DateTime resumedAt;

  const SubscriptionResumed({
    required this.result,
    required this.resumedAt,
  });

  @override
  List<Object?> get props => [result, resumedAt];

  /// Get subscription ID
  String get subscriptionId => result.subscriptionId;

  /// Get updated status
  SubscriptionStatus get status => result.status;

  /// Get user-friendly message
  String get message => result.message;
}

/// State when an error occurs in subscription operations
///
/// Contains error information and maintains previous subscription data if available
class SubscriptionError extends SubscriptionState {
  final Failure failure;
  final String? operation; // Which operation failed
  final Subscription? previousSubscription; // Keep previous data if available

  const SubscriptionError({
    required this.failure,
    this.operation,
    this.previousSubscription,
  });

  @override
  List<Object?> get props => [failure, operation, previousSubscription];

  /// Get user-friendly error message
  String get errorMessage {
    if (failure is NetworkFailure) {
      return 'No internet connection. Please check your network.';
    } else if (failure is AuthenticationFailure) {
      return 'Please sign in to manage subscriptions.';
    } else if (failure is ServerFailure) {
      return 'Server error. Please try again later.';
    } else if (failure is ClientFailure) {
      final clientFailure = failure as ClientFailure;

      // Handle specific subscription error codes
      if (clientFailure.code == 'ALREADY_PREMIUM') {
        return 'You already have premium access.';
      } else if (clientFailure.code == 'SUBSCRIPTION_NOT_FOUND') {
        return 'No active subscription found.';
      }

      return clientFailure.message;
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Check if error is recoverable (user can retry)
  bool get isRecoverable {
    return failure is NetworkFailure || failure is ServerFailure;
  }

  /// Check if error requires authentication
  bool get requiresAuth {
    return failure is AuthenticationFailure;
  }
}

/// State when checking subscription eligibility
///
/// Determines if user can create a new subscription
class SubscriptionEligibilityChecked extends SubscriptionState {
  final bool canSubscribe;
  final String? reason; // Why user cannot subscribe (if applicable)
  final Subscription? existingSubscription;

  const SubscriptionEligibilityChecked({
    required this.canSubscribe,
    this.reason,
    this.existingSubscription,
  });

  @override
  List<Object?> get props => [canSubscribe, reason, existingSubscription];

  /// Get user-friendly eligibility message
  String get eligibilityMessage {
    if (canSubscribe) {
      return 'You can upgrade to premium for ${sl<PricingService>().getFormattedPricePerMonth('premium')}';
    } else if (reason != null) {
      return reason!;
    } else {
      return 'Unable to subscribe at this time';
    }
  }
}

/// State when user subscription status has been loaded
///
/// Contains UserSubscriptionStatus with trial info and current plan
class UserSubscriptionStatusLoaded extends SubscriptionState {
  final UserSubscriptionStatus subscriptionStatus;
  final DateTime lastUpdated;
  final bool isLoading; // For Standard subscription creation
  final String? authorizationUrl; // Razorpay authorization URL
  final String? errorMessage; // Error during Standard subscription

  const UserSubscriptionStatusLoaded({
    required this.subscriptionStatus,
    required this.lastUpdated,
    this.isLoading = false,
    this.authorizationUrl,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
        subscriptionStatus,
        lastUpdated,
        isLoading,
        authorizationUrl,
        errorMessage,
      ];

  /// Create a copy with updated fields
  UserSubscriptionStatusLoaded copyWith({
    UserSubscriptionStatus? subscriptionStatus,
    DateTime? lastUpdated,
    bool? isLoading,
    String? authorizationUrl,
    String? errorMessage,
    bool clearAuthorizationUrl = false,
    bool clearErrorMessage = false,
  }) {
    return UserSubscriptionStatusLoaded(
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isLoading: isLoading ?? this.isLoading,
      authorizationUrl: clearAuthorizationUrl
          ? null
          : (authorizationUrl ?? this.authorizationUrl),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Check if user needs to subscribe to Standard
  bool get needsSubscription => subscriptionStatus.needsSubscription;

  /// Check if trial is ending soon
  bool get isTrialEndingSoon => subscriptionStatus.isTrialEndingSoon;

  /// Whether to show subscription banner
  bool get shouldShowBanner => subscriptionStatus.shouldShowSubscriptionBanner;

  /// Current plan
  String get currentPlan => subscriptionStatus.currentPlan;

  /// Check if user can start Premium trial
  bool get canStartPremiumTrial => subscriptionStatus.canStartPremiumTrial;

  /// Check if user is in Premium trial
  bool get isInPremiumTrial => subscriptionStatus.isInPremiumTrial;

  /// Premium trial days remaining
  int get premiumTrialDaysRemaining =>
      subscriptionStatus.premiumTrialDaysRemaining;
}

/// State when Premium trial has been started successfully
class PremiumTrialStarted extends SubscriptionState {
  final DateTime trialStartedAt;
  final DateTime trialEndAt;
  final int daysRemaining;
  final String message;

  const PremiumTrialStarted({
    required this.trialStartedAt,
    required this.trialEndAt,
    required this.daysRemaining,
    required this.message,
  });

  @override
  List<Object?> get props =>
      [trialStartedAt, trialEndAt, daysRemaining, message];
}
