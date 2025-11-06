import 'package:equatable/equatable.dart';

/// Subscription status enum
enum SubscriptionStatus {
  created,
  authenticated,
  active,
  pending_cancellation, // snake_case to match backend
  paused,
  cancelled,
  completed,
  expired;

  String get displayName {
    switch (this) {
      case SubscriptionStatus.created:
        return 'Created';
      case SubscriptionStatus.authenticated:
        return 'Authenticated';
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.pending_cancellation:
        return 'Pending Cancellation';
      case SubscriptionStatus.paused:
        return 'Paused';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.completed:
        return 'Completed';
      case SubscriptionStatus.expired:
        return 'Expired';
    }
  }

  String get description {
    switch (this) {
      case SubscriptionStatus.created:
        return 'Subscription created, awaiting payment authorization';
      case SubscriptionStatus.authenticated:
        return 'Payment authorized, pending activation';
      case SubscriptionStatus.active:
        return 'Subscription is active';
      case SubscriptionStatus.pending_cancellation:
        return 'Scheduled to cancel at end of billing period';
      case SubscriptionStatus.paused:
        return 'Subscription is paused';
      case SubscriptionStatus.cancelled:
        return 'Subscription has been cancelled';
      case SubscriptionStatus.completed:
        return 'Subscription period completed';
      case SubscriptionStatus.expired:
        return 'Subscription has expired';
    }
  }

  bool get isActive =>
      this == SubscriptionStatus.active ||
      this == SubscriptionStatus.authenticated ||
      this == SubscriptionStatus.pending_cancellation;

  bool get canCancel =>
      this == SubscriptionStatus.active ||
      this == SubscriptionStatus.authenticated;
}

/// Entity representing a premium subscription
class Subscription extends Equatable {
  final String id;
  final String userId;
  final String razorpaySubscriptionId;
  final SubscriptionStatus status;
  final String planType;
  final int amountPaise;
  final String currency;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? nextBillingAt;
  final int? totalCount; // null = unlimited subscription
  final int paidCount;
  final int? remainingCount; // null = unlimited remaining
  final DateTime? cancelledAt;
  final bool cancelAtCycleEnd;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Subscription({
    required this.id,
    required this.userId,
    required this.razorpaySubscriptionId,
    required this.status,
    required this.planType,
    required this.amountPaise,
    required this.currency,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.nextBillingAt,
    this.totalCount, // nullable for unlimited subscriptions
    required this.paidCount,
    this.remainingCount, // nullable for unlimited subscriptions
    this.cancelledAt,
    required this.cancelAtCycleEnd,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Amount in rupees (convenience getter)
  double get amountRupees => amountPaise / 100.0;

  /// Check if subscription is active
  bool get isActive => status.isActive;

  /// Check if subscription can be cancelled
  bool get canCancel => status.canCancel;

  /// Days until next billing (null if no next billing date)
  int? get daysUntilNextBilling {
    if (nextBillingAt == null) return null;
    return nextBillingAt!.difference(DateTime.now()).inDays;
  }

  /// Days remaining in current period
  int? get daysRemainingInPeriod {
    if (currentPeriodEnd == null) return null;
    final remaining = currentPeriodEnd!.difference(DateTime.now()).inDays;
    return remaining >= 0 ? remaining : 0;
  }

  /// Time until next billing
  Duration? get timeUntilNextBilling {
    if (nextBillingAt == null) return null;
    final now = DateTime.now();
    return nextBillingAt!.isAfter(now)
        ? nextBillingAt!.difference(now)
        : Duration.zero;
  }

  /// Check if subscription is ending soon (within 7 days)
  bool get isEndingSoon {
    final days = daysRemainingInPeriod;
    return days != null && days <= 7 && days > 0;
  }

  /// Check if subscription is unlimited (lifetime until cancelled)
  bool get isUnlimited => totalCount == null;

  @override
  List<Object?> get props => [
        id,
        userId,
        razorpaySubscriptionId,
        status,
        planType,
        amountPaise,
        currency,
        currentPeriodStart,
        currentPeriodEnd,
        nextBillingAt,
        totalCount,
        paidCount,
        remainingCount,
        cancelledAt,
        cancelAtCycleEnd,
        cancellationReason,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() => 'Subscription('
      'id: $id, '
      'status: $status, '
      'amountRupees: $amountRupees, '
      'isActive: $isActive, '
      'daysRemaining: $daysRemainingInPeriod'
      ')';
}

/// Entity representing a subscription creation response
class CreateSubscriptionResult extends Equatable {
  final bool success;
  final String subscriptionId;
  final String razorpaySubscriptionId;
  final String authorizationUrl;
  final double amountRupees;
  final SubscriptionStatus status;
  final String message;

  const CreateSubscriptionResult({
    required this.success,
    required this.subscriptionId,
    required this.razorpaySubscriptionId,
    required this.authorizationUrl,
    required this.amountRupees,
    required this.status,
    required this.message,
  });

  @override
  List<Object?> get props => [
        success,
        subscriptionId,
        razorpaySubscriptionId,
        authorizationUrl,
        amountRupees,
        status,
        message,
      ];
}

/// Entity representing a subscription cancellation response
class CancelSubscriptionResult extends Equatable {
  final bool success;
  final String subscriptionId;
  final SubscriptionStatus status;
  final DateTime cancelledAt;
  final DateTime? activeUntil;
  final String message;

  const CancelSubscriptionResult({
    required this.success,
    required this.subscriptionId,
    required this.status,
    required this.cancelledAt,
    this.activeUntil,
    required this.message,
  });

  /// Time remaining until subscription ends (if cancel_at_cycle_end = true)
  Duration? get timeUntilEnd {
    if (activeUntil == null) return null;
    final now = DateTime.now();
    return activeUntil!.isAfter(now)
        ? activeUntil!.difference(now)
        : Duration.zero;
  }

  @override
  List<Object?> get props => [
        success,
        subscriptionId,
        status,
        cancelledAt,
        activeUntil,
        message,
      ];
}

/// Entity representing a subscription resumption response
class ResumeSubscriptionResult extends Equatable {
  final bool success;
  final String subscriptionId;
  final SubscriptionStatus status;
  final DateTime resumedAt;
  final String message;

  const ResumeSubscriptionResult({
    required this.success,
    required this.subscriptionId,
    required this.status,
    required this.resumedAt,
    required this.message,
  });

  @override
  List<Object?> get props => [
        success,
        subscriptionId,
        status,
        resumedAt,
        message,
      ];
}

/// Entity representing a subscription invoice
class SubscriptionInvoice extends Equatable {
  final String id;
  final String subscriptionId;
  final String userId;
  final String razorpayPaymentId;
  final String? invoiceNumber;
  final int amountPaise;
  final String status;
  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final String? paymentMethod;
  final DateTime? paidAt;
  final DateTime createdAt;

  const SubscriptionInvoice({
    required this.id,
    required this.subscriptionId,
    required this.userId,
    required this.razorpayPaymentId,
    this.invoiceNumber,
    required this.amountPaise,
    required this.status,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    this.paymentMethod,
    this.paidAt,
    required this.createdAt,
  });

  /// Amount in rupees (convenience getter)
  double get amountRupees => amountPaise / 100.0;

  /// Check if invoice is paid
  bool get isPaid => status == 'paid';

  /// Billing period duration
  Duration get billingPeriodDuration =>
      billingPeriodEnd.difference(billingPeriodStart);

  @override
  List<Object?> get props => [
        id,
        subscriptionId,
        userId,
        razorpayPaymentId,
        invoiceNumber,
        amountPaise,
        status,
        billingPeriodStart,
        billingPeriodEnd,
        paymentMethod,
        paidAt,
        createdAt,
      ];

  @override
  String toString() => 'SubscriptionInvoice('
      'invoiceNumber: $invoiceNumber, '
      'amountRupees: $amountRupees, '
      'status: $status, '
      'isPaid: $isPaid'
      ')';
}
