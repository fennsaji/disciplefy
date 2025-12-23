import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:dartz/dartz.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../models/user_profile_model.dart';
import '../../domain/entities/user_profile_entity.dart';

/// API service for user profile operations
class UserProfileApiService {
  static const String _userProfileEndpoint = '/functions/v1/user-profile';

  final HttpService _httpService;

  UserProfileApiService({HttpService? httpService})
      : _httpService = httpService ?? HttpServiceProvider.instance;

  /// Get current user's profile
  Future<Either<Failure, UserProfileEntity>> getUserProfile() async {
    try {
      final headers = await _httpService.createHeaders();
      const url = '${AppConfig.supabaseUrl}$_userProfileEndpoint';

      final response = await _httpService.get(url, headers: headers);

      if (response.statusCode == 200) {
        return _parseProfileResponse(response.body);
      } else if (response.statusCode == 404) {
        return const Left(NotFoundFailure(
          message: 'User profile not found',
        ));
      } else {
        // Check for authentication failure
        if (response.statusCode == 401) {
          return const Left(AuthenticationFailure(
            message: 'Authentication required. Please log in again.',
          ));
        }

        try {
          final Map<String, dynamic>? errorData =
              json.decode(response.body) as Map<String, dynamic>?;

          return Left(ServerFailure(
            message: errorData?['error'] ?? 'Failed to fetch user profile',
          ));
        } catch (e) {
          // Safe handling of non-JSON responses
          final bodyPreview = response.body.length > 100
              ? '${response.body.substring(0, 100)}...'
              : response.body.trim();
          final fallbackMessage = bodyPreview.isNotEmpty
              ? 'Failed to fetch user profile: $bodyPreview'
              : 'Failed to fetch user profile';
          return Left(ServerFailure(message: fallbackMessage));
        }
      }
    } on SocketException {
      return const Left(NetworkFailure());
    } on TimeoutException {
      return const Left(NetworkFailure(
        message: 'Request timeout. Please try again.',
      ));
    } on FormatException catch (e) {
      return Left(ServerFailure(
        message: 'Invalid response format: ${e.message}',
      ));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error: ${e.toString()}',
      ));
    }
  }

  /// Update user profile language preference
  Future<Either<Failure, UserProfileEntity>> updateLanguagePreference(
      String languageCode) async {
    return _updateProfile({'language_preference': languageCode});
  }

  /// Update user profile theme preference
  Future<Either<Failure, UserProfileEntity>> updateThemePreference(
      String themePreference) async {
    return _updateProfile({'theme_preference': themePreference});
  }

  /// Update user profile study mode preference
  Future<Either<Failure, UserProfileEntity>> updateStudyModePreference(
      String? studyMode) async {
    return _updateProfile({'default_study_mode': studyMode});
  }

  /// Update multiple profile fields
  Future<Either<Failure, UserProfileEntity>> updateProfile(
      Map<String, dynamic> updates) async {
    return _updateProfile(updates);
  }

  /// Sync OAuth profile data to backend
  Future<Either<Failure, UserProfileEntity>> syncOAuthProfile(
      Map<String, dynamic> profileData) async {
    return _sendProfileRequest(
      method: 'POST',
      body: profileData,
      invalidDataLabel: 'Invalid OAuth profile data',
      failureLabel: 'Failed to sync OAuth profile',
    );
  }

  /// Internal method to handle profile updates
  Future<Either<Failure, UserProfileEntity>> _updateProfile(
      Map<String, dynamic> updates) async {
    try {
      final baseHeaders = await _httpService.createHeaders();
      final headers = Map<String, String>.from(baseHeaders)
        ..['Content-Type'] = 'application/json';
      const url = '${AppConfig.supabaseUrl}$_userProfileEndpoint';

      final response = await _httpService.put(
        url,
        headers: headers,
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        return _parseProfileResponse(response.body);
      } else if (response.statusCode == 404) {
        return const Left(NotFoundFailure(
          message: 'User profile not found',
        ));
      } else if (response.statusCode == 400) {
        try {
          final Map<String, dynamic>? errorData =
              json.decode(response.body) as Map<String, dynamic>?;

          return Left(ServerFailure(
            message: errorData?['error'] ?? 'Invalid update data',
          ));
        } catch (e) {
          // Safe handling of non-JSON responses
          final bodyPreview = response.body.length > 100
              ? '${response.body.substring(0, 100)}...'
              : response.body.trim();
          final fallbackMessage = bodyPreview.isNotEmpty
              ? 'Invalid update data: $bodyPreview'
              : 'Invalid update data';
          return Left(ServerFailure(message: fallbackMessage));
        }
      } else {
        // Check for authentication failure
        if (response.statusCode == 401) {
          return const Left(AuthenticationFailure(
            message: 'Authentication required. Please log in again.',
          ));
        }

        try {
          final Map<String, dynamic>? errorData =
              json.decode(response.body) as Map<String, dynamic>?;

          return Left(ServerFailure(
            message: errorData?['error'] ?? 'Failed to update user profile',
          ));
        } catch (e) {
          // Safe handling of non-JSON responses
          final bodyPreview = response.body.length > 100
              ? '${response.body.substring(0, 100)}...'
              : response.body.trim();
          final fallbackMessage = bodyPreview.isNotEmpty
              ? 'Failed to update user profile: $bodyPreview'
              : 'Failed to update user profile';
          return Left(ServerFailure(message: fallbackMessage));
        }
      }
    } on SocketException {
      return const Left(NetworkFailure());
    } on TimeoutException {
      return const Left(NetworkFailure(
        message: 'Request timeout. Please try again.',
      ));
    } on FormatException catch (e) {
      return Left(ServerFailure(
        message: 'Invalid response format: ${e.message}',
      ));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error: ${e.toString()}',
      ));
    }
  }

  /// Parse profile response from JSON
  Either<Failure, UserProfileEntity> _parseProfileResponse(
      String responseBody) {
    try {
      final Map<String, dynamic> data = json.decode(responseBody);

      // Handle both direct profile data and wrapped response
      final profileData = data['data'] ?? data;

      final profile = UserProfileModel.fromJson(profileData);
      return Right(profile.toEntity());
    } on FormatException catch (e) {
      return Left(ServerFailure(
        message: 'Invalid JSON response: ${e.message}',
      ));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to parse profile response: ${e.toString()}',
      ));
    }
  }

  /// Shared request sender that handles POST/PUT requests with consistent error handling
  Future<Either<Failure, UserProfileEntity>> _sendProfileRequest({
    required String method,
    required Map<String, dynamic> body,
    required String invalidDataLabel,
    required String failureLabel,
  }) async {
    try {
      final baseHeaders = await _httpService.createHeaders();
      final headers = Map<String, String>.from(baseHeaders)
        ..['Content-Type'] = 'application/json';
      const url = '${AppConfig.supabaseUrl}$_userProfileEndpoint';

      final response = method == 'POST'
          ? await _httpService.post(
              url,
              headers: headers,
              body: json.encode(body),
            )
          : await _httpService.put(
              url,
              headers: headers,
              body: json.encode(body),
            );

      // Handle response status codes
      if (response.statusCode == 200) {
        return _parseProfileResponse(response.body);
      } else if (response.statusCode == 404) {
        return const Left(NotFoundFailure(
          message: 'User profile not found',
        ));
      } else if (response.statusCode == 401) {
        return const Left(AuthenticationFailure(
          message: 'Authentication required. Please log in again.',
        ));
      } else if (response.statusCode == 400) {
        final errorMessage =
            _extractErrorMessage(response.body, invalidDataLabel);
        return Left(ServerFailure(message: errorMessage));
      } else {
        final errorMessage = _extractErrorMessage(response.body, failureLabel);
        return Left(ServerFailure(message: errorMessage));
      }
    } on SocketException {
      return const Left(NetworkFailure());
    } on TimeoutException {
      return const Left(NetworkFailure(
        message: 'Request timeout. Please try again.',
      ));
    } on FormatException catch (e) {
      return Left(ServerFailure(
        message: 'Invalid response format: ${e.message}',
      ));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Unexpected error: ${e.toString()}',
      ));
    }
  }

  /// Extract error message from JSON response with fallback to body preview
  String _extractErrorMessage(String responseBody, String fallbackLabel) {
    try {
      final Map<String, dynamic>? errorData =
          json.decode(responseBody) as Map<String, dynamic>?;
      return errorData?['error'] ?? fallbackLabel;
    } catch (e) {
      final bodyPreview = _previewBody(responseBody);
      return bodyPreview.isNotEmpty
          ? '$fallbackLabel: $bodyPreview'
          : fallbackLabel;
    }
  }

  /// Create a preview of response body for error messages
  String _previewBody(String responseBody) {
    final trimmed = responseBody.trim();
    return trimmed.length > 100 ? '${trimmed.substring(0, 100)}...' : trimmed;
  }
}
