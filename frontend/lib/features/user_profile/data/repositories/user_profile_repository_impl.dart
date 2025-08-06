import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../../auth/domain/exceptions/auth_exceptions.dart'
    as auth_exceptions;

/// Supabase implementation of UserProfileRepository
/// Handles all user profile database operations
class UserProfileRepositoryImpl implements UserProfileRepository {
  final SupabaseClient _supabase;

  UserProfileRepositoryImpl(this._supabase);

  @override
  Future<UserProfileEntity?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      return UserProfileEntity.fromMap(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user profile: $e');
      }
      return null;
    }
  }

  @override
  Future<void> upsertUserProfile(UserProfileEntity profile) async {
    try {
      await _supabase.from('user_profiles').upsert(profile.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error upserting user profile: $e');
      }
      throw const auth_exceptions.AuthenticationFailedException(
          'Failed to update user profile');
    }
  }

  @override
  Future<void> deleteUserProfile(String userId) async {
    try {
      // Delete user profile (cascade will handle related data)
      await _supabase.from('user_profiles').delete().eq('id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting user profile: $e');
      }
      throw const auth_exceptions.AuthenticationFailedException(
          'Failed to delete user profile');
    }
  }

  @override
  Future<bool> isUserAdmin(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      return profile?.isAdmin ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking admin status: $e');
      }
      return false;
    }
  }

  @override
  Future<void> updateLanguagePreference(
      String userId, String languageCode) async {
    try {
      await _supabase.from('user_profiles').update({
        'language_preference': languageCode,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating language preference: $e');
      }
      throw const auth_exceptions.AuthenticationFailedException(
          'Failed to update language preference');
    }
  }

  @override
  Future<void> updateThemePreference(String userId, String theme) async {
    try {
      await _supabase.from('user_profiles').update({
        'theme_preference': theme,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating theme preference: $e');
      }
      throw const auth_exceptions.AuthenticationFailedException(
          'Failed to update theme preference');
    }
  }
}
