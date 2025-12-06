import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../domain/entities/purchase_issue_entity.dart';

/// Events for Purchase Issue BLoC
abstract class PurchaseIssueEvent extends Equatable {
  const PurchaseIssueEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the form with purchase data
class InitializePurchaseIssueForm extends PurchaseIssueEvent {
  final String purchaseId;
  final String paymentId;
  final String orderId;
  final int tokenAmount;
  final double costRupees;
  final DateTime purchasedAt;

  const InitializePurchaseIssueForm({
    required this.purchaseId,
    required this.paymentId,
    required this.orderId,
    required this.tokenAmount,
    required this.costRupees,
    required this.purchasedAt,
  });

  @override
  List<Object?> get props => [
        purchaseId,
        paymentId,
        orderId,
        tokenAmount,
        costRupees,
        purchasedAt,
      ];
}

/// Update issue type selection
class IssueTypeChanged extends PurchaseIssueEvent {
  final PurchaseIssueType issueType;

  const IssueTypeChanged({required this.issueType});

  @override
  List<Object?> get props => [issueType];
}

/// Update issue description
class DescriptionChanged extends PurchaseIssueEvent {
  final String description;

  const DescriptionChanged({required this.description});

  @override
  List<Object?> get props => [description];
}

/// Upload a screenshot
class UploadScreenshotRequested extends PurchaseIssueEvent {
  final String fileName;
  final Uint8List fileBytes;
  final String mimeType;

  const UploadScreenshotRequested({
    required this.fileName,
    required this.fileBytes,
    required this.mimeType,
  });

  @override
  List<Object?> get props => [fileName, fileBytes, mimeType];
}

/// Remove a screenshot
class RemoveScreenshot extends PurchaseIssueEvent {
  final int index;

  const RemoveScreenshot({required this.index});

  @override
  List<Object?> get props => [index];
}

/// Submit the issue report
class SubmitPurchaseIssueRequested extends PurchaseIssueEvent {
  const SubmitPurchaseIssueRequested();
}

/// Reset the state
class ResetPurchaseIssueState extends PurchaseIssueEvent {
  const ResetPurchaseIssueState();
}
