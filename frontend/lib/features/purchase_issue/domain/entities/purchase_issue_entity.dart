import 'package:equatable/equatable.dart';

/// Types of purchase issues that users can report
enum PurchaseIssueType {
  wrongAmount('wrong_amount', 'Wrong Amount Charged'),
  paymentFailed('payment_failed', 'Payment Failed'),
  tokensNotCredited('tokens_not_credited', 'Tokens Not Credited'),
  duplicateCharge('duplicate_charge', 'Duplicate Charge'),
  refundRequest('refund_request', 'Refund Request'),
  other('other', 'Other Issue');

  final String value;
  final String label;

  const PurchaseIssueType(this.value, this.label);

  static PurchaseIssueType fromValue(String value) {
    return PurchaseIssueType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => PurchaseIssueType.other,
    );
  }
}

/// Entity representing a purchase issue report submission
class PurchaseIssueEntity extends Equatable {
  /// Purchase transaction ID
  final String purchaseId;

  /// Payment gateway payment ID
  final String paymentId;

  /// Payment gateway order ID
  final String orderId;

  /// Number of tokens in the purchase
  final int tokenAmount;

  /// Cost in Indian Rupees
  final double costRupees;

  /// Original purchase timestamp
  final DateTime purchasedAt;

  /// Type of issue being reported
  final PurchaseIssueType issueType;

  /// User's description of the issue
  final String description;

  /// URLs of uploaded screenshots (max 3)
  final List<String> screenshotUrls;

  const PurchaseIssueEntity({
    required this.purchaseId,
    required this.paymentId,
    required this.orderId,
    required this.tokenAmount,
    required this.costRupees,
    required this.purchasedAt,
    required this.issueType,
    required this.description,
    this.screenshotUrls = const [],
  });

  /// Create a copy with updated screenshot URLs
  PurchaseIssueEntity copyWithScreenshots(List<String> urls) {
    return PurchaseIssueEntity(
      purchaseId: purchaseId,
      paymentId: paymentId,
      orderId: orderId,
      tokenAmount: tokenAmount,
      costRupees: costRupees,
      purchasedAt: purchasedAt,
      issueType: issueType,
      description: description,
      screenshotUrls: urls,
    );
  }

  @override
  List<Object?> get props => [
        purchaseId,
        paymentId,
        orderId,
        tokenAmount,
        costRupees,
        purchasedAt,
        issueType,
        description,
        screenshotUrls,
      ];
}

/// Response from submitting a purchase issue report
class PurchaseIssueResponse extends Equatable {
  /// Whether the submission was successful
  final bool success;

  /// Message from the server
  final String message;

  /// Report ID if successful
  final String? reportId;

  const PurchaseIssueResponse({
    required this.success,
    required this.message,
    this.reportId,
  });

  @override
  List<Object?> get props => [success, message, reportId];
}

/// Response from uploading a screenshot
class ScreenshotUploadResponse extends Equatable {
  /// Whether the upload was successful
  final bool success;

  /// URL of the uploaded screenshot
  final String? url;

  /// Error message if failed
  final String? error;

  const ScreenshotUploadResponse({
    required this.success,
    this.url,
    this.error,
  });

  @override
  List<Object?> get props => [success, url, error];
}
