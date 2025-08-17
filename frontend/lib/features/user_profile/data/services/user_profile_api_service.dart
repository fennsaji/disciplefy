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
        return const Left(ServerFailure(
          message: 'User profile not found',
        ));
      } else {
        final Map<String, dynamic>? errorData =
            json.decode(response.body) as Map<String, dynamic>?;

        return Left(ServerFailure(
          message: errorData?['error'] ?? 'Failed to fetch user profile',
        ));
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

  /// Update multiple profile fields
  Future<Either<Failure, UserProfileEntity>> updateProfile(
      Map<String, dynamic> updates) async {
    return _updateProfile(updates);
  }

  /// Internal method to handle profile updates
  Future<Either<Failure, UserProfileEntity>> _updateProfile(
      Map<String, dynamic> updates) async {
    try {
      final headers = await _httpService.createHeaders();
      const url = '${AppConfig.supabaseUrl}$_userProfileEndpoint';

      final response = await _httpService.put(
        url,
        headers: headers,
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        return _parseProfileResponse(response.body);
      } else if (response.statusCode == 404) {
        return const Left(ServerFailure(
          message: 'User profile not found',
        ));
      } else if (response.statusCode == 400) {
        final Map<String, dynamic>? errorData =
            json.decode(response.body) as Map<String, dynamic>?;

        return Left(ServerFailure(
          message: errorData?['error'] ?? 'Invalid update data',
        ));
      } else {
        final Map<String, dynamic>? errorData =
            json.decode(response.body) as Map<String, dynamic>?;

        return Left(ServerFailure(
          message: errorData?['error'] ?? 'Failed to update user profile',
        ));
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
}
