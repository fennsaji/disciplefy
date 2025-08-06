import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Use case for clearing user data during logout and account deletion
/// Centralized data cleanup following Clean Architecture principles
class ClearUserDataUseCase {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// List of Hive boxes that contain user-specific data
  static const List<String> _userDataBoxes = [
    'user_preferences',
    'cached_data',
    'study_guides_cache',
    'daily_verse_cache',
  ];

  /// Keys in app_settings box that should be cleared during logout
  /// (user-specific data that shouldn't persist across sessions)
  static const List<String> _appSettingsUserKeys = [
    'user_type',
    'user_id',
    'auth_token',
    'refresh_token',
    'access_token',
    'google_auth_data',
    'last_sync_timestamp',
    'current_user_session',
  ];

  /// Keys in app_settings box that should be preserved during logout
  /// (app-level settings that persist across user sessions)
  static const List<String> _appSettingsPreservedKeys = [
    'onboarding_completed',
    'app_version',
    'first_launch_date',
    'app_theme_preference', // Global theme preference
    'default_language', // Global language preference
    'notification_permissions',
  ];

  /// Clears all user data including Supabase session, secure storage, and Hive boxes
  Future<void> execute() async {
    if (kDebugMode) {
      print('🧹 [CLEAR DATA] Starting user data cleanup...');
    }

    await Future.wait([
      _clearSupabaseSession(),
      _clearSecureStorage(),
      _clearHiveBoxes(),
      _clearAdditionalUserData(),
    ]);

    if (kDebugMode) {
      print('🧹 [CLEAR DATA] ✅ User data cleanup completed');
    }
  }

  /// Clear Supabase authentication session
  Future<void> _clearSupabaseSession() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ✅ Supabase session cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ⚠️ Error clearing Supabase session: $e');
      }
    }
  }

  /// Clear Flutter secure storage completely
  Future<void> _clearSecureStorage() async {
    try {
      await _secureStorage.deleteAll();
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ✅ Secure storage cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ⚠️ Error clearing secure storage: $e');
      }
    }
  }

  /// Clear all user-specific Hive boxes
  Future<void> _clearHiveBoxes() async {
    final List<Future<void>> clearTasks = [];

    // Clear regular user data boxes completely
    for (final boxName in _userDataBoxes) {
      clearTasks.add(_clearHiveBox(boxName));
    }

    // Handle app_settings box specially - only clear user-specific keys
    clearTasks.add(_clearAppSettingsUserData());

    await Future.wait(clearTasks);

    if (kDebugMode) {
      print('🧹 [CLEAR DATA] ✅ All user-specific data cleared');
    }
  }

  /// Clear individual Hive box with error handling
  Future<void> _clearHiveBox(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).clear();
        if (kDebugMode) {
          print('🧹 [CLEAR DATA] ✅ Cleared Hive box: $boxName');
        }
      } else {
        if (kDebugMode) {
          print('🧹 [CLEAR DATA] ℹ️ Box $boxName not open, skipping');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ⚠️ Error clearing box $boxName: $e');
      }
    }
  }

  /// Selectively clear user-specific keys from app_settings box
  /// Preserves app-level settings like onboarding completion status
  Future<void> _clearAppSettingsUserData() async {
    try {
      if (Hive.isBoxOpen('app_settings')) {
        final box = Hive.box('app_settings');

        // Log current state for debugging
        if (kDebugMode) {
          print(
              '🧹 [CLEAR DATA] 📊 app_settings keys before cleanup: ${box.keys.toList()}');
          print(
              '🧹 [CLEAR DATA] 📊 onboarding_completed before: ${box.get('onboarding_completed')}');
        }

        // Clear only user-specific keys
        for (final key in _appSettingsUserKeys) {
          if (box.containsKey(key)) {
            await box.delete(key);
            if (kDebugMode) {
              print('🧹 [CLEAR DATA] 🗑️ Removed user key: $key');
            }
          }
        }

        // Log preserved state
        if (kDebugMode) {
          print(
              '🧹 [CLEAR DATA] 📊 app_settings keys after cleanup: ${box.keys.toList()}');
          print(
              '🧹 [CLEAR DATA] 📊 onboarding_completed after: ${box.get('onboarding_completed')}');
          print(
              '🧹 [CLEAR DATA] ✅ app_settings user data cleared, app settings preserved');
        }
      } else {
        if (kDebugMode) {
          print(
              '🧹 [CLEAR DATA] ℹ️ app_settings box not open, skipping selective clear');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ⚠️ Error clearing app_settings user data: $e');
      }
    }
  }

  /// Clear additional app-specific storage (extend as needed)
  Future<void> _clearAdditionalUserData() async {
    try {
      // Add any additional cleanup logic here
      // For example: SharedPreferences, temporary files, etc.

      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ✅ Additional user data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ⚠️ Error clearing additional data: $e');
      }
    }
  }
}
