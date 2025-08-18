import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/app_language.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../models/user_profile_model.dart';
import 'user_profile_api_service.dart';

/// Service for managing user profile operations
/// Handles API communication and business logic for user profiles
class UserProfileService {
  final UserProfileApiService _apiService;
  final AuthService _authService;

  UserProfileService({
    required UserProfileApiService apiService,
    required AuthService authService,
  })  : _apiService = apiService,
        _authService = authService;

  /// Get current user's profile
  Future<Either<Failure, UserProfileEntity>> getUserProfile() async {
    final currentUser = _authService.currentUser;
    if (!_authService.isAuthenticated ||
        currentUser == null ||
        currentUser.isAnonymous) {
      return const Left(AuthenticationFailure(
        message: 'User must be authenticated to access profile',
      ));
    }

    return await _apiService.getUserProfile();
  }

  /// Update user's language preference
  Future<Either<Failure, UserProfileEntity>> updateLanguagePreference(
      AppLanguage language) async {
    final currentUser = _authService.currentUser;
    if (!_authService.isAuthenticated ||
        currentUser == null ||
        currentUser.isAnonymous) {
      return const Left(AuthenticationFailure(
        message: 'User must be authenticated to update profile',
      ));
    }

    return await _apiService.updateLanguagePreference(language.code);
  }

  /// Update user's theme preference
  Future<Either<Failure, UserProfileEntity>> updateThemePreference(
      String themePreference) async {
    final currentUser = _authService.currentUser;
    if (!_authService.isAuthenticated ||
        currentUser == null ||
        currentUser.isAnonymous) {
      return const Left(AuthenticationFailure(
        message: 'User must be authenticated to update profile',
      ));
    }

    return await _apiService.updateThemePreference(themePreference);
  }

  /// Update multiple profile fields at once
  Future<Either<Failure, UserProfileEntity>> updateProfile(
      Map<String, dynamic> updates) async {
    final currentUser = _authService.currentUser;
    if (!_authService.isAuthenticated ||
        currentUser == null ||
        currentUser.isAnonymous) {
      return const Left(AuthenticationFailure(
        message: 'User must be authenticated to update profile',
      ));
    }

    return await _apiService.updateProfile(updates);
  }

  /// Get user's language preference as AppLanguage
  Future<Either<Failure, AppLanguage>> getLanguagePreference() async {
    final profileResult = await getUserProfile();

    return profileResult.fold(
      (failure) => Left(failure),
      (profile) => Right(AppLanguage.fromCode(profile.languagePreference)),
    );
  }

  /// Check if user profile exists
  Future<bool> profileExists() async {
    final currentUser = _authService.currentUser;
    if (!_authService.isAuthenticated ||
        currentUser == null ||
        currentUser.isAnonymous) {
      return false;
    }

    final result = await getUserProfile();
    return result.fold(
      (failure) => failure is! NotFoundFailure,
      (profile) => true,
    );
  }

  /// Create or update user profile with language preference
  /// This method is useful for first-time users
  Future<Either<Failure, UserProfileEntity>> initializeProfile({
    required AppLanguage language,
    String themePreference = 'light',
  }) async {
    final currentUser = _authService.currentUser;
    if (!_authService.isAuthenticated ||
        currentUser == null ||
        currentUser.isAnonymous) {
      return const Left(AuthenticationFailure(
        message: 'User must be authenticated to initialize profile',
      ));
    }

    // Try to get existing profile first
    final existingProfile = await getUserProfile();

    return existingProfile.fold(
      (failure) {
        // If profile doesn't exist, create with initial values
        if (failure is NotFoundFailure) {
          return updateProfile({
            'language_preference': language.code,
            'theme_preference': themePreference,
          });
        }
        return Left(failure);
      },
      (profile) {
        // Profile exists, update language preference
        return updateLanguagePreference(language);
      },
    );
  }

  /// Get user profile by user ID (for compatibility with AuthBloc)
  Future<Either<Failure, UserProfileEntity>> getUserProfileById(
      String userId) async {
    // For now, just use the current user's profile
    // In a full implementation, this would validate userId matches current user
    return await getUserProfile();
  }

  /// Upsert user profile (create or update)
  Future<Either<Failure, UserProfileEntity>> upsertUserProfile({
    required String userId,
    required String languagePreference,
    String? themePreference,
  }) async {
    return await updateProfile({
      'language_preference': languagePreference,
      if (themePreference != null) 'theme_preference': themePreference,
    });
  }

  /// Check if current user is admin (placeholder implementation)
  Future<bool> isCurrentUserAdmin(String userId) async {
    // Placeholder implementation - would check admin status from profile
    // For now, return false as admin functionality is not implemented
    return false;
  }

  /// Get user profile as Map for AuthBloc compatibility
  Future<Map<String, dynamic>?> getUserProfileAsMap(String userId) async {
    final result = await getUserProfileById(userId);
    return result.fold(
      (failure) => null,
      (profile) => UserProfileModel.fromEntity(profile).toMap(),
    );
  }

  /// Get current user profile as Map for AuthBloc compatibility
  Future<Map<String, dynamic>?> getCurrentUserProfileAsMap() async {
    final result = await getUserProfile();
    return result.fold(
      (failure) => null,
      (profile) => UserProfileModel.fromEntity(profile).toMap(),
    );
  }
}
