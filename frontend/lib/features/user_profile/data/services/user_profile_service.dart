import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../repositories/user_profile_repository_impl.dart';

/// Service for user profile management
/// Provides high-level business logic for profile operations
class UserProfileService {
  late final UserProfileRepository _repository;
  
  UserProfileService() {
    _repository = UserProfileRepositoryImpl(Supabase.instance.client);
  }
  
  /// Get user profile data by user ID
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final profile = await _repository.getUserProfile(userId);
      return profile?.toMap();
    } catch (e) {
      if (kDebugMode) {
        print('UserProfileService: Error getting profile: $e');
      }
      return null;
    }
  }
  
  /// Create or update user profile with default values
  Future<void> upsertUserProfile({
    required String userId,
    required String languagePreference,
    String themePreference = 'light',
  }) async {
    final now = DateTime.now();
    final profile = UserProfileEntity(
      id: userId,
      languagePreference: languagePreference,
      themePreference: themePreference,
      updatedAt: now,
    );
    
    await _repository.upsertUserProfile(profile);
  }
  
  /// Delete user profile and all associated data
  Future<void> deleteUserProfile(String userId) async {
    await _repository.deleteUserProfile(userId);
  }
  
  /// Check if user has admin privileges
  Future<bool> isCurrentUserAdmin(String userId) async => await _repository.isUserAdmin(userId);
  
  /// Update user language preference
  Future<void> updateLanguagePreference(String userId, String languageCode) async {
    await _repository.updateLanguagePreference(userId, languageCode);
  }
  
  /// Update user theme preference  
  Future<void> updateThemePreference(String userId, String theme) async {
    await _repository.updateThemePreference(userId, theme);
  }
}