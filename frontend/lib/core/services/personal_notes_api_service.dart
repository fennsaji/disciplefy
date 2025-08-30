import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';

/// Response model for personal notes operations
class PersonalNotesResponse {
  final bool success;
  final String message;
  final String? notes;

  const PersonalNotesResponse({
    required this.success,
    required this.message,
    this.notes,
  });

  factory PersonalNotesResponse.fromJson(Map<String, dynamic> json) {
    final notesData = json['data']?['notes'];
    return PersonalNotesResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? 'Operation completed',
      notes: notesData?['personal_notes'],
    );
  }
}

/// API service for managing personal notes on study guides
///
/// This service handles CRUD operations for personal notes associated
/// with user study guides, following SOLID principles and DRY patterns.
class PersonalNotesApiService {
  static String get _baseUrl =>
      AppConfig.baseApiUrl.replaceAll('/functions/v1', '');
  static const String _personalNotesEndpoint = '/functions/v1/personal-notes';

  final http.Client _httpClient;

  PersonalNotesApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Update personal notes for a study guide
  ///
  /// If the study guide is not saved, it will be saved automatically.
  /// Pass null for [notes] to delete existing notes.
  Future<PersonalNotesResponse> updatePersonalNotes({
    required String studyGuideId,
    required String? notes,
  }) async {
    try {
      print('🔍 [PERSONAL_NOTES] Updating notes for guide: $studyGuideId');
      print('🔍 [PERSONAL_NOTES] Notes length: ${notes?.length ?? 0}');

      final headers = await _getApiHeaders();
      final body = json.encode({
        'study_guide_id': studyGuideId,
        'personal_notes': notes,
      });

      final url = '$_baseUrl$_personalNotesEndpoint';
      print('🔍 [PERSONAL_NOTES] Making POST request to: $url');

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      print('🔍 [PERSONAL_NOTES] Response status: ${response.statusCode}');
      print('🔍 [PERSONAL_NOTES] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return PersonalNotesResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw const AuthenticationException(
          message: 'Authentication required to save personal notes',
          code: 'UNAUTHORIZED',
        );
      } else if (response.statusCode == 404) {
        throw const ServerException(
          message: 'Study guide not found',
          code: 'NOT_FOUND',
        );
      } else {
        final Map<String, dynamic>? errorData =
            _parseErrorResponse(response.body);

        String errorMessage = 'Failed to update personal notes';
        String errorCode = 'SERVER_ERROR';

        if (errorData != null) {
          errorMessage = _extractErrorMessage(errorData, errorMessage);
          errorCode = _extractErrorCode(errorData, errorCode);
        }

        throw ServerException(
          message: errorMessage,
          code: errorCode,
        );
      }
    } catch (e) {
      print('🚨 [PERSONAL_NOTES] Error caught: $e');
      print('🚨 [PERSONAL_NOTES] Error type: ${e.runtimeType}');

      if (e is AuthenticationException || e is ServerException) {
        rethrow;
      }

      throw NetworkException(
        message: 'Failed to connect to personal notes service: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Get personal notes for a study guide
  Future<PersonalNotesResponse> getPersonalNotes({
    required String studyGuideId,
  }) async {
    try {
      print('🔍 [PERSONAL_NOTES] Getting notes for guide: $studyGuideId');

      final headers = await _getApiHeaders();
      final url =
          '$_baseUrl$_personalNotesEndpoint?study_guide_id=$studyGuideId';

      print('🔍 [PERSONAL_NOTES] Making GET request to: $url');

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      print('🔍 [PERSONAL_NOTES] Response status: ${response.statusCode}');
      print('🔍 [PERSONAL_NOTES] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return PersonalNotesResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw const AuthenticationException(
          message: 'Authentication required to access personal notes',
          code: 'UNAUTHORIZED',
        );
      } else if (response.statusCode == 404) {
        // Return empty notes response for 404 (no notes exist yet)
        return const PersonalNotesResponse(
          success: true,
          message: 'No personal notes found',
        );
      } else {
        final Map<String, dynamic>? errorData =
            _parseErrorResponse(response.body);

        String errorMessage = 'Failed to get personal notes';
        String errorCode = 'SERVER_ERROR';

        if (errorData != null) {
          errorMessage = _extractErrorMessage(errorData, errorMessage);
          errorCode = _extractErrorCode(errorData, errorCode);
        }

        throw ServerException(
          message: errorMessage,
          code: errorCode,
        );
      }
    } catch (e) {
      print('🚨 [PERSONAL_NOTES] Error caught: $e');

      if (e is AuthenticationException || e is ServerException) {
        rethrow;
      }

      throw NetworkException(
        message: 'Failed to connect to personal notes service: $e',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Delete personal notes for a study guide
  Future<PersonalNotesResponse> deletePersonalNotes({
    required String studyGuideId,
  }) async {
    try {
      print('🔍 [PERSONAL_NOTES] Deleting notes for guide: $studyGuideId');

      final headers = await _getApiHeaders();
      final url =
          '$_baseUrl$_personalNotesEndpoint?study_guide_id=$studyGuideId';

      print('🔍 [PERSONAL_NOTES] Making DELETE request to: $url');

      final response = await _httpClient
          .delete(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      print('🔍 [PERSONAL_NOTES] Response status: ${response.statusCode}');
      print('🔍 [PERSONAL_NOTES] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return PersonalNotesResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw const AuthenticationException(
          message: 'Authentication required to delete personal notes',
          code: 'UNAUTHORIZED',
        );
      } else if (response.statusCode == 404) {
        // Return success for 404 (notes don't exist, deletion successful)
        return const PersonalNotesResponse(
          success: true,
          message: 'Personal notes deleted successfully',
        );
      } else {
        final Map<String, dynamic>? errorData =
            _parseErrorResponse(response.body);

        String errorMessage = 'Failed to delete personal notes';
        String errorCode = 'SERVER_ERROR';

        if (errorData != null) {
          errorMessage = _extractErrorMessage(errorData, errorMessage);
          errorCode = _extractErrorCode(errorData, errorCode);
        }

        throw ServerException(
          message: errorMessage,
          code: errorCode,
        );
      }
    } catch (e) {
      print('🚨 [PERSONAL_NOTES] Error caught: $e');

      if (e is AuthenticationException || e is ServerException) {
        rethrow;
      }

      throw NetworkException(
        message: 'Failed to connect to personal notes service: $e',
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
          '🔐 [PERSONAL_NOTES] Using Supabase session token for user: ${session.user.id}');
    } else {
      print('🔐 [PERSONAL_NOTES] No valid session found');
      throw const AuthenticationException(
        message: 'Authentication required to access personal notes',
        code: 'UNAUTHORIZED',
      );
    }

    return headers;
  }

  /// Parse error response body safely
  Map<String, dynamic>? _parseErrorResponse(String responseBody) {
    try {
      return json.decode(responseBody) as Map<String, dynamic>?;
    } catch (e) {
      print('🚨 [PERSONAL_NOTES] Failed to parse error response: $e');
      return null;
    }
  }

  /// Extract error message from error response
  String _extractErrorMessage(Map<String, dynamic> errorData, String fallback) {
    if (errorData['error'] is Map<String, dynamic>) {
      final errorObj = errorData['error'] as Map<String, dynamic>;
      return errorObj['message'] ?? fallback;
    } else if (errorData['message'] is String) {
      return errorData['message'];
    }
    return fallback;
  }

  /// Extract error code from error response
  String _extractErrorCode(Map<String, dynamic> errorData, String fallback) {
    if (errorData['error'] is Map<String, dynamic>) {
      final errorObj = errorData['error'] as Map<String, dynamic>;
      return errorObj['code'] ?? fallback;
    } else if (errorData['code'] is String) {
      return errorData['code'];
    }
    return fallback;
  }

  /// Dispose HTTP client
  void dispose() {
    // Don't close the client if it's shared through DI
    // The DI container will handle cleanup
  }
}
