import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';

/// API service for saving/unsaving study guides
class SaveGuideApiService {
  static String get _baseUrl =>
      AppConfig.baseApiUrl.replaceAll('/functions/v1', '');
  static const String _saveGuideEndpoint = '/functions/v1/study-guides';

  final http.Client _httpClient;

  SaveGuideApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Save or unsave a study guide
  Future<bool> toggleSaveGuide({
    required String guideId,
    required bool save,
  }) async {
    try {
      print(
          '🔍 [SAVE_GUIDE] Starting toggleSaveGuide - guideId: $guideId, save: $save');

      final headers = await _getApiHeaders();
      print('🔍 [SAVE_GUIDE] Got headers: ${headers.keys.join(', ')}');

      final body = json.encode({
        'guide_id': guideId,
        'action': save ? 'save' : 'unsave',
      });
      print('🔍 [SAVE_GUIDE] Request body: $body');

      final url = '$_baseUrl$_saveGuideEndpoint';
      print('🔍 [SAVE_GUIDE] Making POST request to: $url');

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      print('🔍 [SAVE_GUIDE] Response status: ${response.statusCode}');
      print('🔍 [SAVE_GUIDE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['success'] == true;
      } else if (response.statusCode == 401) {
        throw const AuthenticationException(
          message: 'Authentication required to save guides',
          code: 'UNAUTHORIZED',
        );
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Study guide not found',
          code: 'NOT_FOUND',
        );
      } else {
        final Map<String, dynamic>? errorData =
            json.decode(response.body) as Map<String, dynamic>?;

        // Handle nested error structure
        String errorMessage =
            'Failed to ${save ? 'save' : 'unsave'} study guide';
        String errorCode = 'SERVER_ERROR';

        if (errorData != null) {
          if (errorData['error'] is Map<String, dynamic>) {
            final errorObj = errorData['error'] as Map<String, dynamic>;
            errorMessage = errorObj['message'] ?? errorMessage;
            errorCode = errorObj['code'] ?? errorCode;
          } else if (errorData['message'] is String) {
            errorMessage = errorData['message'];
          }

          // Handle specific database errors
          if (errorMessage
              .contains('duplicate key value violates unique constraint')) {
            errorMessage = 'This study guide is already saved!';
            errorCode = 'ALREADY_SAVED';
          }
        }

        throw ServerException(
          message: errorMessage,
          code: errorCode,
        );
      }
    } catch (e) {
      print('🚨 [SAVE_GUIDE] Error caught: $e');
      print('🚨 [SAVE_GUIDE] Error type: ${e.runtimeType}');

      if (e is AuthenticationException || e is ServerException) {
        rethrow;
      }

      throw NetworkException(
        message: 'Failed to connect to save guide service: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Get API headers with authentication
  Future<Map<String, String>> _getApiHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'apikey': AppConfig.supabaseAnonKey,
    };

    // Use Supabase session token for consistent authentication
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
      print(
          '🔐 [SAVE_GUIDE] Using Supabase session token for user: ${session.user.id}');
    } else {
      print('🔐 [SAVE_GUIDE] No valid session found');
      throw const AuthenticationException(
        message: 'Authentication required to save guides',
        code: 'UNAUTHORIZED',
      );
    }

    return headers;
  }

  /// Mark a study guide as completed
  ///
  /// This is called automatically when both completion conditions are met:
  /// 1. User spent at least 60 seconds on the study guide
  /// 2. User scrolled to the bottom of the content
  Future<bool> markStudyGuideComplete({
    required String guideId,
    required int timeSpentSeconds,
    required bool scrolledToBottom,
  }) async {
    try {
      print(
          '📋 [MARK_COMPLETE] Starting markStudyGuideComplete - guideId: $guideId');
      print(
          '📋 [MARK_COMPLETE] Time spent: ${timeSpentSeconds}s, Scrolled: $scrolledToBottom');

      final headers = await _getApiHeaders();
      print('📋 [MARK_COMPLETE] Got headers: ${headers.keys.join(', ')}');

      final body = json.encode({
        'study_guide_id': guideId,
        'time_spent_seconds': timeSpentSeconds,
        'scrolled_to_bottom': scrolledToBottom,
      });
      print('📋 [MARK_COMPLETE] Request body: $body');

      final url = '$_baseUrl/functions/v1/mark-study-guide-complete';
      print('📋 [MARK_COMPLETE] Making POST request to: $url');

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      print('📋 [MARK_COMPLETE] Response status: ${response.statusCode}');
      print('📋 [MARK_COMPLETE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        print('📋 [MARK_COMPLETE] ✅ Successfully marked as complete');
        return jsonData['success'] == true;
      } else if (response.statusCode == 401) {
        throw const AuthenticationException(
          message: 'Authentication required to mark guides complete',
          code: 'UNAUTHORIZED',
        );
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Study guide not found or you do not have permission',
          code: 'NOT_FOUND',
        );
      } else if (response.statusCode == 400) {
        // Handle validation errors (e.g., completion conditions not met)
        final Map<String, dynamic>? errorData =
            json.decode(response.body) as Map<String, dynamic>?;
        String errorMessage = 'Completion conditions not met';
        String errorCode = 'VALIDATION_ERROR';

        if (errorData != null && errorData['error'] is Map<String, dynamic>) {
          final errorObj = errorData['error'] as Map<String, dynamic>;
          errorMessage = errorObj['message'] ?? errorMessage;
          errorCode = errorObj['code'] ?? errorCode;
        }

        throw ServerException(
          message: errorMessage,
          code: errorCode,
        );
      } else {
        final Map<String, dynamic>? errorData =
            json.decode(response.body) as Map<String, dynamic>?;

        String errorMessage = 'Failed to mark study guide as complete';
        String errorCode = 'SERVER_ERROR';

        if (errorData != null) {
          if (errorData['error'] is Map<String, dynamic>) {
            final errorObj = errorData['error'] as Map<String, dynamic>;
            errorMessage = errorObj['message'] ?? errorMessage;
            errorCode = errorObj['code'] ?? errorCode;
          } else if (errorData['message'] is String) {
            errorMessage = errorData['message'];
          }
        }

        throw ServerException(
          message: errorMessage,
          code: errorCode,
        );
      }
    } catch (e) {
      print('🚨 [MARK_COMPLETE] Error caught: $e');
      print('🚨 [MARK_COMPLETE] Error type: ${e.runtimeType}');

      if (e is AuthenticationException || e is ServerException) {
        rethrow;
      }

      throw NetworkException(
        message: 'Failed to connect to completion service: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Dispose HTTP client
  void dispose() {
    // Don't close the client if it's shared through DI
    // The DI container will handle cleanup
  }
}
