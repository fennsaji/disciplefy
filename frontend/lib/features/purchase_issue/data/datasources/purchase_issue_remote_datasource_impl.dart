import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/purchase_issue_entity.dart';
import 'purchase_issue_remote_datasource.dart';

/// Implementation of PurchaseIssueRemoteDataSource using Supabase
class PurchaseIssueRemoteDataSourceImpl
    implements PurchaseIssueRemoteDataSource {
  final SupabaseClient supabaseClient;

  PurchaseIssueRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<PurchaseIssueResponse> submitIssueReport(
    PurchaseIssueEntity issue,
  ) async {
    try {
      final body = {
        'action': 'submit_report',
        'purchaseId': issue.purchaseId,
        'paymentId': issue.paymentId,
        'orderId': issue.orderId,
        'tokenAmount': issue.tokenAmount,
        'costRupees': issue.costRupees,
        'purchasedAt': issue.purchasedAt.toIso8601String(),
        'issueType': issue.issueType.value,
        'description': issue.description,
        'screenshotUrls': issue.screenshotUrls,
      };

      final response = await supabaseClient.functions.invoke(
        'report-purchase-issue',
        body: body,
      );

      if (response.status != 200 && response.status != 201) {
        throw ServerException(
          message: response.data?['error'] ?? 'Failed to submit issue report',
          code: 'ISSUE_SUBMIT_ERROR',
        );
      }

      final responseData = response.data;

      if (responseData is Map) {
        if (responseData['success'] == true) {
          return PurchaseIssueResponse(
            success: true,
            message: responseData['message'] ?? 'Report submitted successfully',
            reportId: responseData['reportId'],
          );
        } else {
          throw ServerException(
            message: responseData['error'] ?? 'Failed to submit issue report',
            code: 'ISSUE_SUBMIT_ERROR',
          );
        }
      }

      throw ServerException(
        message: 'Invalid response from server',
        code: 'ISSUE_SUBMIT_ERROR',
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to submit issue report: $e',
        code: 'ISSUE_SUBMIT_ERROR',
      );
    }
  }

  @override
  Future<ScreenshotUploadResponse> uploadScreenshot({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    try {
      // Convert bytes to base64
      final base64Data = base64Encode(fileBytes);

      final body = {
        'action': 'upload_screenshot',
        'fileName': fileName,
        'fileBase64': base64Data,
        'mimeType': mimeType,
      };

      final response = await supabaseClient.functions.invoke(
        'report-purchase-issue',
        body: body,
      );

      if (response.status != 200 && response.status != 201) {
        throw ServerException(
          message: response.data?['error'] ?? 'Failed to upload screenshot',
          code: 'SCREENSHOT_UPLOAD_ERROR',
        );
      }

      final responseData = response.data;

      if (responseData is Map) {
        if (responseData['success'] == true) {
          return ScreenshotUploadResponse(
            success: true,
            url: responseData['url'],
          );
        } else {
          return ScreenshotUploadResponse(
            success: false,
            error: responseData['error'] ?? 'Failed to upload screenshot',
          );
        }
      }

      throw ServerException(
        message: 'Invalid response from server',
        code: 'SCREENSHOT_UPLOAD_ERROR',
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to upload screenshot: $e',
        code: 'SCREENSHOT_UPLOAD_ERROR',
      );
    }
  }
}
