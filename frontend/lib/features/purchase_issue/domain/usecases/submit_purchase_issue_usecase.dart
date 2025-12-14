import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/purchase_issue_entity.dart';
import '../repositories/purchase_issue_repository.dart';

/// Use case for submitting a purchase issue report
class SubmitPurchaseIssueUseCase
    implements UseCase<PurchaseIssueResponse, SubmitPurchaseIssueParams> {
  final PurchaseIssueRepository repository;

  SubmitPurchaseIssueUseCase({required this.repository});

  @override
  Future<Either<Failure, PurchaseIssueResponse>> call(
    SubmitPurchaseIssueParams params,
  ) async {
    return await repository.submitIssueReport(params.issue);
  }
}

/// Parameters for submitting a purchase issue
class SubmitPurchaseIssueParams {
  final PurchaseIssueEntity issue;

  const SubmitPurchaseIssueParams({required this.issue});
}

/// Use case for uploading a screenshot
class UploadIssueScreenshotUseCase
    implements UseCase<ScreenshotUploadResponse, UploadScreenshotParams> {
  final PurchaseIssueRepository repository;

  UploadIssueScreenshotUseCase({required this.repository});

  @override
  Future<Either<Failure, ScreenshotUploadResponse>> call(
    UploadScreenshotParams params,
  ) async {
    return await repository.uploadScreenshot(
      fileName: params.fileName,
      fileBytes: params.fileBytes,
      mimeType: params.mimeType,
    );
  }
}

/// Parameters for uploading a screenshot
class UploadScreenshotParams {
  final String fileName;
  final Uint8List fileBytes;
  final String mimeType;

  const UploadScreenshotParams({
    required this.fileName,
    required this.fileBytes,
    required this.mimeType,
  });
}
