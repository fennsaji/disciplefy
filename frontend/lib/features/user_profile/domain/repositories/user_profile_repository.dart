import '../../domain/entities/user_profile_entity.dart';

/// Repository interface for user profile operations
/// Following Clean Architecture principles with proper separation of concerns
abstract class UserProfileRepository {
  /// Retrieves user profile by user ID
  Future<UserProfileEntity?> getUserProfile(String userId);
  
  /// Creates or updates user profile
  Future<void> upsertUserProfile(UserProfileEntity profile);
  
  /// Deletes user profile and associated data
  Future<void> deleteUserProfile(String userId);
  
  /// Checks if user has admin privileges
  Future<bool> isUserAdmin(String userId);
  
  /// Updates user language preference
  Future<void> updateLanguagePreference(String userId, String languageCode);
  
  /// Updates user theme preference
  Future<void> updateThemePreference(String userId, String theme);
}