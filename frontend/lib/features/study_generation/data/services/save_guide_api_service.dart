import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';

/// API service for saving/unsaving study guides
class SaveGuideApiService {
  static String get _baseUrl => AppConfig.baseApiUrl.replaceAll('/functions/v1', '');
  static const String _saveGuideEndpoint = '/functions/v1/study-guides';

  final http.Client _httpClient;

  SaveGuideApiService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// Save or unsave a study guide
  Future<bool> toggleSaveGuide({
    required String guideId,
    required bool save,
  }) async {
    try {
      print('🔍 [SAVE_GUIDE] Starting toggleSaveGuide - guideId: $guideId, save: $save');

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
        final Map<String, dynamic>? errorData = json.decode(response.body) as Map<String, dynamic>?;

        // Handle nested error structure
        String errorMessage = 'Failed to ${save ? 'save' : 'unsave'} study guide';
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
          if (errorMessage.contains('duplicate key value violates unique constraint')) {
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
      print('🔐 [SAVE_GUIDE] Using Supabase session token for user: ${session.user.id}');
    } else {
      print('🔐 [SAVE_GUIDE] No valid session found');
      throw const AuthenticationException(
        message: 'Authentication required to save guides',
        code: 'UNAUTHORIZED',
      );
    }

    return headers;
  }

  /// Dispose HTTP client
  void dispose() {
    // Don't close the client if it's shared through DI
    // The DI container will handle cleanup
  }
}
