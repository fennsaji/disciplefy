import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    'saved_guides',
    'recent_guides',
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

  /// Clear entire IndexedDB and recreate essential boxes
  Future<void> _clearHiveBoxes() async {
    try {
      // Close all open Hive boxes
      await Hive.close();

      // Delete all Hive data from IndexedDB
      await Hive.deleteFromDisk();

      // Reinitialize Hive for the app
      await Hive.initFlutter();

      // Reopen essential app_settings box to preserve app-level settings
      final appSettingsBox = await Hive.openBox('app_settings');

      // Restore essential app settings that should persist
      await appSettingsBox.putAll({
        'onboarding_completed': true, // Keep onboarding status
        'app_version': '1.0.0', // Preserve app version info
      });

      if (kDebugMode) {
        print(
            '🧹 [CLEAR DATA] ✅ IndexedDB completely cleared and reinitialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ❌ Error clearing IndexedDB: $e');
      }
      // Fallback to individual box clearing if full DB clear fails
      await _clearIndividualBoxes();
    }
  }

  /// Fallback method: Clear individual boxes if full DB clear fails
  Future<void> _clearIndividualBoxes() async {
    final List<Future<void>> clearTasks = [];

    // Clear regular user data boxes completely
    for (final boxName in _userDataBoxes) {
      clearTasks.add(_clearHiveBox(boxName));
    }

    // Handle app_settings box specially - only clear user-specific keys
    clearTasks.add(_clearAppSettingsUserData());

    await Future.wait(clearTasks);
  }

  /// Clear and completely delete individual Hive box from IndexedDB
  Future<void> _clearHiveBox(String boxName) async {
    try {
      Box? box;

      if (Hive.isBoxOpen(boxName)) {
        box = Hive.box(boxName);
      } else {
        // Try to open the box to access existing data
        try {
          box = await Hive.openBox(boxName);
        } catch (e) {
          return;
        }
      }

      final itemCount = box.length;
      // Clear the data
      await box.clear();
      // Close the box
      await box.close();
      // Completely delete the box from IndexedDB
      await Hive.deleteBoxFromDisk(boxName);
    } catch (e) {
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ❌ Error deleting box $boxName: $e');
      }
    }
  }

  /// Selectively clear user-specific keys from app_settings box
  /// Preserves app-level settings like onboarding completion status
  Future<void> _clearAppSettingsUserData() async {
    try {
      if (Hive.isBoxOpen('app_settings')) {
        final box = Hive.box('app_settings');

        // Clear only user-specific keys
        for (final key in _appSettingsUserKeys) {
          if (box.containsKey(key)) {
            await box.delete(key);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ⚠️ Error clearing app_settings user data: $e');
      }
    }
  }

  /// Clear additional app-specific storage (SharedPreferences, web storage)
  Future<void> _clearAdditionalUserData() async {
    // Clear SharedPreferences (web caching, daily verses, etc.)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      if (kDebugMode) {
        print('🧹 [CLEAR DATA] ❌ Failed to clear SharedPreferences: $e');
      }
    }

    if (kDebugMode) {
      print('🧹 [CLEAR DATA] ✅ Additional user data cleared');
    }
  }
}
