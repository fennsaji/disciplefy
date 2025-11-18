import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'exceptions.dart';

/// Centralized API error handler for remote datasources.
///
/// Provides consistent error handling and logging across all API calls.
/// Follows DRY principle by consolidating error handling logic.
class ApiErrorHandler {
  /// Feature/module name for logging context
  final String feature;

  const ApiErrorHandler({required this.feature});

  /// Handles HTTP error responses from the API
  ///
  /// Parses error response body and throws appropriate [ServerException]
  /// with error message and code from the API response.
  Never handleErrorResponse(dynamic response) {
    final statusCode = response.statusCode;
    String errorMessage = 'Unknown error occurred';
    String errorCode = 'UNKNOWN_ERROR';

    try {
      final jsonData = jsonDecode(response.body);
      if (jsonData['error'] != null && jsonData['error']['message'] != null) {
        errorMessage = jsonData['error']['message'] as String;
      }
      if (jsonData['error'] != null && jsonData['error']['code'] != null) {
        errorCode = jsonData['error']['code'] as String;
      }
    } catch (e) {
      errorMessage = 'Server error: ${response.body}';
    }

    if (kDebugMode) {
      print('❌ [$feature] Error ($statusCode): $errorMessage');
    }

    throw ServerException(
      message: errorMessage,
      code: errorCode,
    );
  }

  /// Handles exceptions during API calls
  ///
  /// Wraps generic exceptions in [ServerException] for consistent error handling.
  /// Preserves [ServerException] and [NetworkException] as-is.
  ///
  /// [error] - The caught exception
  /// [operation] - Description of the operation being performed (e.g., 'fetching verses')
  Never handleException(dynamic error, String operation) {
    if (kDebugMode) {
      print('❌ [$feature] Exception while $operation: $error');
    }

    if (error is ServerException) {
      throw error;
    }

    if (error is NetworkException) {
      throw error;
    }

    throw ServerException(
      message: 'Failed to complete $operation: ${error.toString()}',
      code: 'OPERATION_FAILED',
    );
  }

  /// Logs a debug message for the feature
  void logDebug(String message) {
    if (kDebugMode) {
      print('🚀 [$feature] $message');
    }
  }

  /// Logs a success message for the feature
  void logSuccess(String message) {
    if (kDebugMode) {
      print('✅ [$feature] $message');
    }
  }

  /// Logs a warning message for the feature
  void logWarning(String message) {
    if (kDebugMode) {
      print('⚠️ [$feature] $message');
    }
  }
}
