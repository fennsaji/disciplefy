import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/local_store_repository.dart';
import '../../../../core/utils/logger.dart';

/// Implementation of LocalStoreRepository that wraps Hive and SharedPreferences
/// Isolates Hive and SharedPreferences SDKs from domain layer following Clean Architecture
class LocalStoreRepositoryImpl implements LocalStoreRepository {
  /// Keys in app_settings box that should be cleared during logout
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

  @override
  Future<void> clearAll() async {
    try {
      // Close all open Hive boxes
      await Hive.close();

      // Reinitialize Hive for the app
      // Note: Hive.deleteFromDisk() is a no-op after close() because close()
      // unregisters all boxes first. We explicitly clear the box contents below.
      await Hive.initFlutter();

      // Reopen essential app_settings box and explicitly clear ALL stale data.
      // putAll() only adds/updates keys — it does NOT remove existing ones, so
      // calling clear() first is required to evict user_type, user_id, etc.
      final appSettingsBox = await Hive.openBox('app_settings');
      await appSettingsBox.clear();

      // Restore only the settings that should survive logout
      await appSettingsBox.putAll({
        'onboarding_completed': true,
        'app_version': '1.0.0',
      });

      // Clear SharedPreferences
      await clearSharedPreferences();

      Logger.debug(
          '🗄️ [LOCAL STORE] ✅ All local storage cleared and reinitialized');
    } catch (e) {
      Logger.debug('🗄️ [LOCAL STORE] ❌ Error clearing all local storage: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearBox(String boxName) async {
    try {
      Box? box;

      if (Hive.isBoxOpen(boxName)) {
        box = Hive.box(boxName);
      } else {
        try {
          box = await Hive.openBox(boxName);
        } catch (e) {
          // Box doesn't exist, nothing to clear
          return;
        }
      }

      final itemCount = box.length;
      await box.clear();
      await box.close();
      await Hive.deleteBoxFromDisk(boxName);

      Logger.debug(
          '🗄️ [LOCAL STORE] ✅ Cleared box: $boxName ($itemCount items)');
    } catch (e) {
      Logger.debug('🗄️ [LOCAL STORE] ❌ Error clearing box $boxName: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearBoxes(List<String> boxNames) async {
    final List<Future<void>> clearTasks = boxNames.map(clearBox).toList();
    await Future.wait(clearTasks);
  }

  @override
  Future<void> clearSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Logger.debug('🗄️ [LOCAL STORE] ✅ SharedPreferences cleared');
    } catch (e) {
      Logger.debug('🗄️ [LOCAL STORE] ❌ Failed to clear SharedPreferences: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAppSettingsUserData() async {
    try {
      if (Hive.isBoxOpen('app_settings')) {
        final box = Hive.box('app_settings');
        int clearedKeys = 0;

        // Clear only user-specific keys
        for (final key in _appSettingsUserKeys) {
          if (box.containsKey(key)) {
            await box.delete(key);
            clearedKeys++;
          }
        }

        Logger.debug(
            '🗄️ [LOCAL STORE] ✅ Cleared $clearedKeys user keys from app_settings');
      }
    } catch (e) {
      Logger.debug(
          '🗄️ [LOCAL STORE] ❌ Error clearing app_settings user data: $e');
      rethrow;
    }
  }

  @override
  Future<void> reinitializeStorage() async {
    try {
      // Reinitialize Hive
      await Hive.initFlutter();

      // Reopen essential boxes
      await Hive.openBox('app_settings');

      Logger.debug('🗄️ [LOCAL STORE] ✅ Storage reinitialized');
    } catch (e) {
      Logger.debug('🗄️ [LOCAL STORE] ❌ Error reinitializing storage: $e');
      rethrow;
    }
  }

  @override
  bool isBoxOpen(String boxName) {
    return Hive.isBoxOpen(boxName);
  }

  @override
  Future<void> ensureBoxOpen(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }
}
