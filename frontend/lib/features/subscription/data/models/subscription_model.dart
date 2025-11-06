import '../../domain/entities/subscription.dart';

/// Data model for Subscription that handles JSON serialization
class SubscriptionModel extends Subscription {
  const SubscriptionModel({
    required super.id,
    required super.userId,
    required super.razorpaySubscriptionId,
    required super.status,
    required super.planType,
    required super.amountPaise,
    required super.currency,
    super.currentPeriodStart,
    super.currentPeriodEnd,
    super.nextBillingAt,
    super.totalCount, // nullable for unlimited subscriptions
    required super.paidCount,
    super.remainingCount, // nullable for unlimited subscriptions
    super.cancelledAt,
    required super.cancelAtCycleEnd,
    super.cancellationReason,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      razorpaySubscriptionId: json['razorpay_subscription_id'] as String,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'] as String,
        orElse: () => SubscriptionStatus.created,
      ),
      planType: json['plan_type'] as String,
      amountPaise: json['amount_paise'] as int,
      currency: json['currency'] as String,
      currentPeriodStart: json['current_period_start'] != null
          ? DateTime.parse(json['current_period_start'] as String)
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
      nextBillingAt: json['next_billing_at'] != null
          ? DateTime.parse(json['next_billing_at'] as String)
          : null,
      totalCount: json['total_count'] as int?, // null = unlimited subscription
      paidCount: json['paid_count'] as int,
      remainingCount:
          json['remaining_count'] as int?, // null = unlimited remaining
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancelAtCycleEnd: json['cancel_at_cycle_end'] as bool? ?? false,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'razorpay_subscription_id': razorpaySubscriptionId,
      'status': status.name,
      'plan_type': planType,
      'amount_paise': amountPaise,
      'currency': currency,
      'current_period_start': currentPeriodStart?.toIso8601String(),
      'current_period_end': currentPeriodEnd?.toIso8601String(),
      'next_billing_at': nextBillingAt?.toIso8601String(),
      'total_count': totalCount,
      'paid_count': paidCount,
      'remaining_count': remainingCount,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancel_at_cycle_end': cancelAtCycleEnd,
      'cancellation_reason': cancellationReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Data model for CreateSubscriptionResult
class CreateSubscriptionResponseModel extends CreateSubscriptionResult {
  const CreateSubscriptionResponseModel({
    required super.success,
    required super.subscriptionId,
    required super.razorpaySubscriptionId,
    required super.authorizationUrl,
    required super.amountRupees,
    required super.status,
    required super.message,
  });

  factory CreateSubscriptionResponseModel.fromJson(Map<String, dynamic> json) {
    return CreateSubscriptionResponseModel(
      success: json['success'] as bool,
      subscriptionId: json['subscription_id'] as String,
      razorpaySubscriptionId: json['razorpay_subscription_id'] as String,
      authorizationUrl: json['short_url'] as String,
      amountRupees: (json['amount_rupees'] as num).toDouble(),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'] as String,
        orElse: () => SubscriptionStatus.created,
      ),
      message: json['message'] as String,
    );
  }
}

/// Data model for CancelSubscriptionResult
class CancelSubscriptionResponseModel extends CancelSubscriptionResult {
  const CancelSubscriptionResponseModel({
    required super.success,
    required super.subscriptionId,
    required super.status,
    required super.cancelledAt,
    super.activeUntil,
    required super.message,
  });

  factory CancelSubscriptionResponseModel.fromJson(Map<String, dynamic> json) {
    return CancelSubscriptionResponseModel(
      success: json['success'] as bool,
      subscriptionId: json['subscription_id'] as String,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'] as String,
        orElse: () => SubscriptionStatus.cancelled,
      ),
      cancelledAt: DateTime.parse(json['cancelled_at'] as String),
      activeUntil: json['active_until'] != null
          ? DateTime.parse(json['active_until'] as String)
          : null,
      message: json['message'] as String,
    );
  }
}

/// Data model for ResumeSubscriptionResult
class ResumeSubscriptionResponseModel {
  final bool success;
  final String subscriptionId;
  final String status;
  final String resumedAt;
  final String message;

  const ResumeSubscriptionResponseModel({
    required this.success,
    required this.subscriptionId,
    required this.status,
    required this.resumedAt,
    required this.message,
  });

  factory ResumeSubscriptionResponseModel.fromJson(Map<String, dynamic> json) {
    return ResumeSubscriptionResponseModel(
      success: json['success'] as bool,
      subscriptionId: json['subscription_id'] as String,
      status: json['status'] as String,
      resumedAt: json['resumed_at'] as String,
      message: json['message'] as String,
    );
  }
}

/// Data model for SubscriptionInvoice
class SubscriptionInvoiceModel extends SubscriptionInvoice {
  const SubscriptionInvoiceModel({
    required super.id,
    required super.subscriptionId,
    required super.userId,
    required super.razorpayPaymentId,
    super.invoiceNumber,
    required super.amountPaise,
    required super.status,
    required super.billingPeriodStart,
    required super.billingPeriodEnd,
    super.paymentMethod,
    super.paidAt,
    required super.createdAt,
  });

  factory SubscriptionInvoiceModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionInvoiceModel(
      id: json['id'] as String,
      subscriptionId: json['subscription_id'] as String,
      userId: json['user_id'] as String,
      razorpayPaymentId: json['razorpay_payment_id'] as String,
      invoiceNumber: json['invoice_number'] as String?,
      amountPaise: json['amount_paise'] as int,
      status: json['status'] as String,
      billingPeriodStart:
          DateTime.parse(json['billing_period_start'] as String),
      billingPeriodEnd: DateTime.parse(json['billing_period_end'] as String),
      paymentMethod: json['payment_method'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscription_id': subscriptionId,
      'user_id': userId,
      'razorpay_payment_id': razorpayPaymentId,
      'invoice_number': invoiceNumber,
      'amount_paise': amountPaise,
      'status': status,
      'billing_period_start': billingPeriodStart.toIso8601String(),
      'billing_period_end': billingPeriodEnd.toIso8601String(),
      'payment_method': paymentMethod,
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
