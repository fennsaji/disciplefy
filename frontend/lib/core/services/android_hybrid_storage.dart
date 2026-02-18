import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Robust hybrid storage for Android - SharedPreferences PRIMARY + SecureStorage backup
///
/// Problem: Android Keystore can be cleared by OS, causing unexpected logouts.
/// flutter_secure_storage v10+ has ResetOnError=true by default, which silently
/// deletes data when decryption fails (e.g., after Keystore clear).
///
/// Solution: Use SharedPreferences as PRIMARY storage (more reliable on Android)
/// and SecureStorage as encrypted backup. This ensures session persistence even
/// when Android clears the Keystore.
///
/// Key changes from previous implementation:
/// 1. SharedPreferences is read FIRST (primary), SecureStorage is backup
/// 2. Both storages are kept in sync during reads and writes
/// 3. Better error handling with explicit recovery logic
class AndroidHybridStorage extends LocalStorage {
  static const String _secureKey = 'supabase.session';
  static const String _prefsKey = 'supabase.session.primary';

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  AndroidHybridStorage._({
    required FlutterSecureStorage secure,
    required SharedPreferences prefs,
  })  : _secure = secure,
        _prefs = prefs;

  /// Create instance - must be called in main() after WidgetsFlutterBinding
  static Future<AndroidHybridStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    // Note: encryptedSharedPreferences is deprecated in v10+ and always enabled
    // ResetOnError is also true by default, which is why we use SharedPrefs as primary
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    final storage = AndroidHybridStorage._(secure: secure, prefs: prefs);

    // Migrate any existing data from old backup key to new primary key
    await storage._migrateOldBackupKey();

    Logger.info(
        '✅ [ANDROID STORAGE] Hybrid storage initialized (SharedPrefs primary)');

    return storage;
  }

  /// Migrate data from old 'supabase.session.backup' key to new 'supabase.session.primary'
  Future<void> _migrateOldBackupKey() async {
    const oldBackupKey = 'supabase.session.backup';
    try {
      final oldData = _prefs.getString(oldBackupKey);
      if (oldData != null && oldData.isNotEmpty) {
        // Check if new key already has data
        final newData = _prefs.getString(_prefsKey);
        if (newData == null || newData.isEmpty) {
          // Migrate old data to new key
          await _prefs.setString(_prefsKey, oldData);
          Logger.info(
              '✅ [ANDROID STORAGE] Migrated session from old backup key');
        }
        // Remove old key after migration
        await _prefs.remove(oldBackupKey);
      }
    } catch (e) {
      Logger.warning('⚠️  [ANDROID STORAGE] Migration from old key failed: $e');
    }
  }

  @override
  Future<void> initialize() async {
    // Sync storages on initialization to recover from any inconsistencies
    await _syncStorages();
    Logger.info('✅ [ANDROID STORAGE] Storage ready and synced');
  }

  /// Sync both storages - if one has data and other doesn't, copy to the empty one
  Future<void> _syncStorages() async {
    String? prefsSession;
    String? secureSession;

    // Read from SharedPreferences (primary)
    try {
      prefsSession = _prefs.getString(_prefsKey);
    } catch (e) {
      Logger.warning('⚠️  [ANDROID STORAGE] Sync: SharedPrefs read failed: $e');
    }

    // Read from SecureStorage (backup)
    try {
      secureSession = await _secure.read(key: _secureKey);
    } catch (e) {
      Logger.warning(
          '⚠️  [ANDROID STORAGE] Sync: SecureStorage read failed: $e');
    }

    final hasPrefs = prefsSession != null && prefsSession.isNotEmpty;
    final hasSecure = secureSession != null && secureSession.isNotEmpty;

    // Sync logic: ensure both have the same data
    if (hasPrefs && !hasSecure) {
      // SharedPrefs has data, SecureStorage doesn't - restore to SecureStorage
      try {
        await _secure.write(key: _secureKey, value: prefsSession);
        Logger.warning(
            '✅ [ANDROID STORAGE] Sync: Restored SecureStorage from SharedPrefs');
      } catch (e) {
        Logger.warning(
            '⚠️  [ANDROID STORAGE] Sync: Could not restore SecureStorage: $e');
      }
    } else if (!hasPrefs && hasSecure) {
      // SecureStorage has data, SharedPrefs doesn't - copy to SharedPrefs
      try {
        await _prefs.setString(_prefsKey, secureSession);
        Logger.warning(
            '✅ [ANDROID STORAGE] Sync: Copied SecureStorage to SharedPrefs');
      } catch (e) {
        Logger.warning(
            '⚠️  [ANDROID STORAGE] Sync: Could not copy to SharedPrefs: $e');
      }
    }
  }

  @override
  Future<void> persistSession(String sessionString) async {
    bool prefsSuccess = false;
    bool secureSuccess = false;

    // Write to SharedPreferences FIRST (primary - more reliable)
    try {
      await _prefs.setString(_prefsKey, sessionString);
      prefsSuccess = true;
      Logger.warning(
          '✅ [ANDROID STORAGE] Saved to SharedPreferences (primary)');
    } catch (e) {
      Logger.debug('⚠️  [ANDROID STORAGE] SharedPreferences write failed: $e');
    }

    // Write to SecureStorage (backup - may fail due to Keystore issues)
    try {
      await _secure.write(key: _secureKey, value: sessionString);
      secureSuccess = true;
      Logger.warning('✅ [ANDROID STORAGE] Saved to SecureStorage (backup)');
    } catch (e) {
      Logger.debug('⚠️  [ANDROID STORAGE] SecureStorage write failed: $e');
    }

    // At least one storage must succeed
    if (!prefsSuccess && !secureSuccess) {
      Logger.debug('🚨 [ANDROID STORAGE] CRITICAL: Both storages failed!');
    }
  }

  /// Read session with SharedPreferences as PRIMARY source
  Future<String?> _readSession() async {
    // Try SharedPreferences FIRST (primary - more reliable on Android)
    try {
      final session = _prefs.getString(_prefsKey);
      if (session != null && session.isNotEmpty) {
        Logger.info('✅ [ANDROID STORAGE] Found in SharedPreferences (primary)');
        // Ensure SecureStorage is synced (background, non-blocking intent)
        _syncSecureStorageBackground(session);
        return session;
      }
    } catch (e) {
      Logger.warning('⚠️  [ANDROID STORAGE] SharedPreferences read failed: $e');
    }

    // Fallback to SecureStorage (may have data if SharedPrefs was cleared)
    try {
      final session = await _secure.read(key: _secureKey);
      if (session != null && session.isNotEmpty) {
        Logger.info(
            '✅ [ANDROID STORAGE] Recovered from SecureStorage (backup)');
        // Restore to SharedPreferences for next time
        try {
          await _prefs.setString(_prefsKey, session);
          Logger.warning('✅ [ANDROID STORAGE] Restored to SharedPreferences');
        } catch (e) {
          Logger.debug(
              '⚠️  [ANDROID STORAGE] Could not restore to SharedPrefs: $e');
        }
        return session;
      }
    } catch (e) {
      Logger.error('⚠️  [ANDROID STORAGE] SecureStorage read failed: $e');
    }

    Logger.debug('❌ [ANDROID STORAGE] No session found in any storage');
    return null;
  }

  /// Background sync to SecureStorage (non-blocking)
  void _syncSecureStorageBackground(String session) {
    // Fire-and-forget sync to SecureStorage
    Future.microtask(() async {
      try {
        final existing = await _secure.read(key: _secureKey);
        if (existing != session) {
          await _secure.write(key: _secureKey, value: session);
          Logger.warning(
              '✅ [ANDROID STORAGE] Background sync to SecureStorage complete');
        }
      } catch (e) {
        // Silently fail - SecureStorage is just backup
        Logger.debug('⚠️  [ANDROID STORAGE] Background sync failed: $e');
      }
    });
  }

  @override
  Future<void> removePersistedSession() async {
    // Remove from both storages
    try {
      await _prefs.remove(_prefsKey);
      Logger.warning('✅ [ANDROID STORAGE] Removed from SharedPreferences');
    } catch (e) {
      Logger.debug('⚠️  [ANDROID STORAGE] SharedPreferences delete failed: $e');
    }

    try {
      await _secure.delete(key: _secureKey);
      Logger.warning('✅ [ANDROID STORAGE] Removed from SecureStorage');
    } catch (e) {
      Logger.debug('⚠️  [ANDROID STORAGE] SecureStorage delete failed: $e');
    }

    Logger.info('✅ [ANDROID STORAGE] Session removed from all storages');
  }

  @override
  Future<bool> hasAccessToken() async {
    final session = await _readSession();
    return session != null && session.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    // Return the full session JSON string (not just the token)
    // Supabase expects the complete session to restore authentication
    return _readSession();
  }
}
