import 'package:equatable/equatable.dart';

import '../../domain/entities/purchase_issue_entity.dart';

/// States for Purchase Issue BLoC
abstract class PurchaseIssueState extends Equatable {
  const PurchaseIssueState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no form data
class PurchaseIssueInitial extends PurchaseIssueState {
  const PurchaseIssueInitial();
}

/// Form is ready with purchase data
class PurchaseIssueFormReady extends PurchaseIssueState {
  final String purchaseId;
  final String paymentId;
  final String orderId;
  final int tokenAmount;
  final double costRupees;
  final DateTime purchasedAt;
  final PurchaseIssueType issueType;
  final String description;
  final List<String> screenshotUrls;
  final bool isUploadingScreenshot;
  final String? uploadError;

  const PurchaseIssueFormReady({
    required this.purchaseId,
    required this.paymentId,
    required this.orderId,
    required this.tokenAmount,
    required this.costRupees,
    required this.purchasedAt,
    this.issueType = PurchaseIssueType.other,
    this.description = '',
    this.screenshotUrls = const [],
    this.isUploadingScreenshot = false,
    this.uploadError,
  });

  /// Check if form is valid for submission
  bool get isValid =>
      description.trim().length >= 10 && description.length <= 2000;

  /// Check if can add more screenshots (max 3)
  bool get canAddScreenshot => screenshotUrls.length < 3;

  PurchaseIssueFormReady copyWith({
    String? purchaseId,
    String? paymentId,
    String? orderId,
    int? tokenAmount,
    double? costRupees,
    DateTime? purchasedAt,
    PurchaseIssueType? issueType,
    String? description,
    List<String>? screenshotUrls,
    bool? isUploadingScreenshot,
    String? uploadError,
  }) {
    return PurchaseIssueFormReady(
      purchaseId: purchaseId ?? this.purchaseId,
      paymentId: paymentId ?? this.paymentId,
      orderId: orderId ?? this.orderId,
      tokenAmount: tokenAmount ?? this.tokenAmount,
      costRupees: costRupees ?? this.costRupees,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      issueType: issueType ?? this.issueType,
      description: description ?? this.description,
      screenshotUrls: screenshotUrls ?? this.screenshotUrls,
      isUploadingScreenshot:
          isUploadingScreenshot ?? this.isUploadingScreenshot,
      uploadError: uploadError,
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
        isUploadingScreenshot,
        uploadError,
      ];
}

/// Submitting the issue report
class PurchaseIssueSubmitting extends PurchaseIssueState {
  const PurchaseIssueSubmitting();
}

/// Issue report submitted successfully
class PurchaseIssueSubmitSuccess extends PurchaseIssueState {
  final String message;
  final String? reportId;

  const PurchaseIssueSubmitSuccess({
    required this.message,
    this.reportId,
  });

  @override
  List<Object?> get props => [message, reportId];
}

/// Issue report submission failed
class PurchaseIssueSubmitFailure extends PurchaseIssueState {
  final String message;
  final PurchaseIssueFormReady previousState;

  const PurchaseIssueSubmitFailure({
    required this.message,
    required this.previousState,
  });

  @override
  List<Object?> get props => [message, previousState];
}
