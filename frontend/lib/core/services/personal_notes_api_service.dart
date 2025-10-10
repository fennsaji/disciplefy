import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';
import '../utils/logger.dart';

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

  /// Secure logger that redacts sensitive content and uses app Logger
  void _secureLog(
    String message, {
    String? sensitiveData,
    LogLevel level = LogLevel.debug,
    Map<String, dynamic>? context,
  }) {
    final logContext = <String, dynamic>{
      ...?context,
    };

    if (sensitiveData != null) {
      // Redact sensitive content completely - never log actual content
      final contentLength = sensitiveData.length;
      final hasContent = contentLength > 0;

      logContext.addAll({
        'has_content': hasContent,
        'content_length': contentLength,
        'content_preview': hasContent ? '[REDACTED]' : 'null',
      });

      _logWithLevel(
          level, '$message - Content redacted for security', logContext);
    } else {
      _logWithLevel(level, message, logContext);
    }
  }

  /// Helper to call the appropriate Logger static method based on level
  void _logWithLevel(
      LogLevel level, String message, Map<String, dynamic>? context) {
    switch (level) {
      case LogLevel.verbose:
        Logger.verbose(message, tag: 'PERSONAL_NOTES', context: context);
        break;
      case LogLevel.debug:
        Logger.debug(message, tag: 'PERSONAL_NOTES', context: context);
        break;
      case LogLevel.info:
        Logger.info(message, tag: 'PERSONAL_NOTES', context: context);
        break;
      case LogLevel.warning:
        Logger.warning(message, tag: 'PERSONAL_NOTES', context: context);
        break;
      case LogLevel.error:
        Logger.error(message, tag: 'PERSONAL_NOTES', context: context);
        break;
      case LogLevel.critical:
        Logger.critical(message, tag: 'PERSONAL_NOTES', context: context);
        break;
    }
  }

  /// Update personal notes for a study guide
  ///
  /// If the study guide is not saved, it will be saved automatically.
  /// Pass null for [notes] to delete existing notes.
  Future<PersonalNotesResponse> updatePersonalNotes({
    required String studyGuideId,
    required String? notes,
  }) async {
    try {
      _secureLog('Updating notes for study guide', context: {
        'study_guide_id': '[REDACTED]',
        'notes_length': notes?.length ?? 0,
        'operation': 'update',
      });

      final headers = await _getApiHeaders();
      final body = json.encode({
        'study_guide_id': studyGuideId,
        'personal_notes': notes,
      });

      final url = '$_baseUrl$_personalNotesEndpoint';
      _secureLog('Making API request', context: {
        'method': 'POST',
        'endpoint': _personalNotesEndpoint,
        'url': url,
      });

      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      _secureLog('API response received',
          sensitiveData: response.body,
          context: {
            'status_code': response.statusCode,
            'method': 'POST',
            'endpoint': _personalNotesEndpoint,
          });

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
      _secureLog('Exception caught during update operation',
          level: LogLevel.error,
          context: {
            'error_type': e.runtimeType.toString(),
            'operation': 'update_personal_notes',
          });

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
      _secureLog('Getting notes for study guide', context: {
        'study_guide_id': '[REDACTED]',
        'operation': 'get',
      });

      final headers = await _getApiHeaders();
      final uri = Uri.parse(_baseUrl).replace(
        path: _personalNotesEndpoint,
        queryParameters: {'study_guide_id': studyGuideId},
      );

      _secureLog('Making API request', context: {
        'method': 'GET',
        'endpoint': _personalNotesEndpoint,
        'uri': uri.toString(),
      });

      final response = await _httpClient
          .get(
            uri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      _secureLog('API response received',
          sensitiveData: response.body,
          context: {
            'status_code': response.statusCode,
            'method': 'GET',
            'endpoint': _personalNotesEndpoint,
          });

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
      _secureLog('Exception caught during get operation',
          level: LogLevel.error,
          context: {
            'error_type': e.runtimeType.toString(),
            'operation': 'get_personal_notes',
          });

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
      _secureLog('Deleting notes for study guide', context: {
        'study_guide_id': '[REDACTED]',
        'operation': 'delete',
      });

      final headers = await _getApiHeaders();
      final uri = Uri.parse(_baseUrl).replace(
        path: _personalNotesEndpoint,
        queryParameters: {'study_guide_id': studyGuideId},
      );

      _secureLog('Making API request', context: {
        'method': 'DELETE',
        'endpoint': _personalNotesEndpoint,
        'uri': uri.toString(),
      });

      final response = await _httpClient
          .delete(
            uri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      _secureLog('API response received',
          sensitiveData: response.body,
          context: {
            'status_code': response.statusCode,
            'method': 'DELETE',
            'endpoint': _personalNotesEndpoint,
          });

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
      _secureLog('Exception caught during delete operation',
          level: LogLevel.error,
          context: {
            'error_type': e.runtimeType.toString(),
            'operation': 'delete_personal_notes',
          });

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
      _secureLog('Using Supabase session authentication', context: {
        'auth_type': 'supabase_session',
        'user_id': '[REDACTED]',
        'has_access_token': session.accessToken.isNotEmpty,
      });
    } else {
      _secureLog('Authentication failed - no valid session',
          level: LogLevel.warning,
          context: {
            'auth_type': 'supabase_session',
            'session_exists': false,
          });
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
      _secureLog('Failed to parse error response',
          level: LogLevel.warning,
          context: {
            'error_type': e.runtimeType.toString(),
            'operation': 'parse_error_response',
          });
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
