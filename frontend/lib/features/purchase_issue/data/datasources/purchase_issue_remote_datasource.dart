import 'dart:typed_data';

import '../../domain/entities/purchase_issue_entity.dart';

/// Remote data source abstraction for purchase issue operations
abstract class PurchaseIssueRemoteDataSource {
  /// Submit a purchase issue report to the remote server
  Future<PurchaseIssueResponse> submitIssueReport(PurchaseIssueEntity issue);

  /// Upload a screenshot for the issue report
  Future<ScreenshotUploadResponse> uploadScreenshot({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  });
}
