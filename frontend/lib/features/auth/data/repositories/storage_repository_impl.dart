import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/storage_repository.dart';
import '../../../../core/utils/logger.dart';

/// Implementation of StorageRepository handling different storage types
/// Separated into data layer following Clean Architecture principles
class StorageRepositoryImpl implements StorageRepository {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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
  Future<void> clearSecureStorage() async {
    try {
      await _secureStorage.deleteAll();
      Logger.error('🗄️ [STORAGE REPO] ✅ Secure storage cleared');
    } catch (e) {
      Logger.debug('🗄️ [STORAGE REPO] ❌ Failed to clear secure storage: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearHiveBox(String boxName) async {
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

      Logger.error(
          '🗄️ [STORAGE REPO] ✅ Cleared Hive box: $boxName ($itemCount items)');
    } catch (e) {
      Logger.debug('🗄️ [STORAGE REPO] ❌ Error clearing Hive box $boxName: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearHiveBoxes(List<String> boxNames) async {
    final List<Future<void>> clearTasks = boxNames.map(clearHiveBox).toList();
    await Future.wait(clearTasks);
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

        Logger.error(
            '🗄️ [STORAGE REPO] ✅ Cleared $clearedKeys user keys from app_settings');
      }
    } catch (e) {
      Logger.debug(
          '🗄️ [STORAGE REPO] ❌ Error clearing app_settings user data: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Logger.error('🗄️ [STORAGE REPO] ✅ SharedPreferences cleared');
    } catch (e) {
      Logger.debug(
          '🗄️ [STORAGE REPO] ❌ Failed to clear SharedPreferences: $e');
      rethrow;
    }
  }
}
