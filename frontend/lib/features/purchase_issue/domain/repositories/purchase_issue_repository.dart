import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/purchase_issue_entity.dart';

/// Repository abstraction for purchase issue operations
abstract class PurchaseIssueRepository {
  /// Submit a purchase issue report
  ///
  /// Returns [PurchaseIssueResponse] on success or [Failure] on error
  Future<Either<Failure, PurchaseIssueResponse>> submitIssueReport(
    PurchaseIssueEntity issue,
  );

  /// Upload a screenshot for the issue report
  ///
  /// [fileName] - Original file name
  /// [fileBytes] - Image data as bytes
  /// [mimeType] - MIME type (image/jpeg, image/png, image/webp)
  ///
  /// Returns [ScreenshotUploadResponse] on success or [Failure] on error
  Future<Either<Failure, ScreenshotUploadResponse>> uploadScreenshot({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  });
}
