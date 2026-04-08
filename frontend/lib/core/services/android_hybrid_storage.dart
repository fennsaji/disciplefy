import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Robust hybrid storage for Android - SecureStorage PRIMARY + SharedPreferences fallback
///
/// SecureStorage (Android Keystore-backed) is the primary store because it
/// encrypts session data at rest. SharedPreferences is kept as a read-only
/// migration source and last-resort degraded fallback only.
///
/// On session write:
///   1. SecureStorage is written first (primary).
///   2. If SecureStorage fails, SharedPreferences is written with a warning
///      (degraded fallback — plaintext on Android).
///   3. If both fail, an exception is thrown so the caller is aware.
///
/// On session read:
///   1. SecureStorage is read first.
///   2. If empty/unavailable, SharedPreferences is checked for migration data
///      and, if found, the value is migrated back into SecureStorage.
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
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    final storage = AndroidHybridStorage._(secure: secure, prefs: prefs);

    // Migrate any existing data from old backup key to new primary key
    await storage._migrateOldBackupKey();

    Logger.info(
        '✅ [ANDROID STORAGE] Hybrid storage initialized (SecureStorage primary)');

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

  /// Sync both storages - SecureStorage is the source of truth.
  /// If SecureStorage has data and SharedPrefs doesn't, no action is needed
  /// (SharedPrefs is not required). If SharedPrefs has data and SecureStorage
  /// is empty, migrate from SharedPrefs into SecureStorage.
  Future<void> _syncStorages() async {
    String? prefsSession;
    String? secureSession;

    // Read from SecureStorage (primary)
    try {
      secureSession = await _secure.read(key: _secureKey);
    } catch (e) {
      Logger.warning(
          '⚠️  [ANDROID STORAGE] Sync: SecureStorage read failed: $e');
    }

    // Read from SharedPreferences (migration source / fallback)
    try {
      prefsSession = _prefs.getString(_prefsKey);
    } catch (e) {
      Logger.warning('⚠️  [ANDROID STORAGE] Sync: SharedPrefs read failed: $e');
    }

    final hasPrefs = prefsSession != null && prefsSession.isNotEmpty;
    final hasSecure = secureSession != null && secureSession.isNotEmpty;

    if (!hasSecure && hasPrefs) {
      // SecureStorage is empty but SharedPrefs has data — migrate to SecureStorage
      try {
        await _secure.write(key: _secureKey, value: prefsSession);
        Logger.info(
            '✅ [ANDROID STORAGE] Sync: Migrated session from SharedPrefs to SecureStorage');
      } catch (e) {
        Logger.warning(
            '⚠️  [ANDROID STORAGE] Sync: Could not migrate to SecureStorage: $e');
      }
    }
    // If SecureStorage has data, it is already the source of truth — nothing to do.
  }

  @override
  Future<void> persistSession(String sessionString) async {
    bool secureSuccess = false;

    // Write to SecureStorage FIRST (primary — encrypted at rest)
    try {
      await _secure.write(key: _secureKey, value: sessionString);
      secureSuccess = true;
      Logger.info('✅ [ANDROID STORAGE] Saved to SecureStorage (primary)');
    } catch (e) {
      Logger.warning('⚠️  [ANDROID STORAGE] SecureStorage write failed: $e');
    }

    if (secureSuccess) {
      return;
    }

    // SecureStorage failed — fall back to SharedPreferences as a degraded path.
    // WARNING: SharedPreferences stores data in plaintext on Android.
    Logger.warning(
        '⚠️  [ANDROID STORAGE] DEGRADED FALLBACK: Writing session to SharedPreferences (plaintext). SecureStorage unavailable.');
    try {
      await _prefs.setString(_prefsKey, sessionString);
      Logger.warning(
          '⚠️  [ANDROID STORAGE] Saved to SharedPreferences (degraded fallback — plaintext)');
      return;
    } catch (e) {
      Logger.error(
          '🚨 [ANDROID STORAGE] CRITICAL: SharedPreferences write also failed: $e');
    }

    // Both storages failed — throw so the caller knows the session was not persisted.
    throw Exception(
        '[ANDROID STORAGE] Failed to persist session: both SecureStorage and SharedPreferences writes failed.');
  }

  /// Read session with SecureStorage as PRIMARY source.
  /// Falls back to SharedPreferences only when SecureStorage is empty/unavailable,
  /// and migrates the value back into SecureStorage when possible.
  Future<String?> _readSession() async {
    // Try SecureStorage FIRST (primary — encrypted)
    try {
      final session = await _secure.read(key: _secureKey);
      if (session != null && session.isNotEmpty) {
        Logger.info('✅ [ANDROID STORAGE] Found in SecureStorage (primary)');
        return session;
      }
    } catch (e) {
      Logger.warning('⚠️  [ANDROID STORAGE] SecureStorage read failed: $e');
    }

    // SecureStorage is empty or failed — check SharedPreferences for migration data
    try {
      final session = _prefs.getString(_prefsKey);
      if (session != null && session.isNotEmpty) {
        Logger.warning(
            '⚠️  [ANDROID STORAGE] Fell back to SharedPreferences (plaintext). Attempting migration to SecureStorage...');
        // Attempt to migrate back into SecureStorage
        try {
          await _secure.write(key: _secureKey, value: session);
          Logger.info(
              '✅ [ANDROID STORAGE] Migrated session from SharedPrefs back to SecureStorage');
        } catch (e) {
          Logger.warning(
              '⚠️  [ANDROID STORAGE] Could not migrate back to SecureStorage: $e');
        }
        return session;
      }
    } catch (e) {
      Logger.error('⚠️  [ANDROID STORAGE] SharedPreferences read failed: $e');
    }

    Logger.debug('❌ [ANDROID STORAGE] No session found in any storage');
    return null;
  }

  @override
  Future<void> removePersistedSession() async {
    // Remove from both storages
    try {
      await _secure.delete(key: _secureKey);
      Logger.info('✅ [ANDROID STORAGE] Removed from SecureStorage');
    } catch (e) {
      Logger.warning('⚠️  [ANDROID STORAGE] SecureStorage delete failed: $e');
    }

    try {
      await _prefs.remove(_prefsKey);
      Logger.info('✅ [ANDROID STORAGE] Removed from SharedPreferences');
    } catch (e) {
      Logger.warning(
          '⚠️  [ANDROID STORAGE] SharedPreferences delete failed: $e');
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
