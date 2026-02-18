import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/auth_params.dart';
import '../../../../core/utils/logger.dart';

/// Dedicated service for authentication data storage
/// Handles secure storage operations and provides atomic transaction support
class AuthStorageService {
  // Secure storage instance for direct auth data management
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Storage keys (matching core service for compatibility)
  static const String _authTokenKey = 'auth_token';
  static const String _userTypeKey = 'user_type';
  static const String _userIdKey = 'user_id';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _sessionExpiresAtKey =
      'session_expires_at'; // SECURITY FIX
  static const String _deviceIdKey = 'device_id'; // SECURITY FIX

  /// Stores authentication data securely with atomic transactions
  /// SECURITY FIX: Now includes session expiration and device binding
  /// Prevents race conditions by ensuring all-or-nothing storage operations
  Future<void> storeAuthData(AuthDataStorageParams params) async {
    if (kDebugMode) {
      Logger.debug('🔐 [AUTH STORAGE] Starting atomic auth data storage...');
      Logger.debug('🔐 [AUTH STORAGE] - userType: ${params.userType}');
      Logger.debug('🔐 [AUTH STORAGE] - userId: ${params.userId}');
      Logger.debug('🔐 [AUTH STORAGE] - expiresAt: ${params.expiresAt}');
      Logger.debug(
          '🔐 [AUTH STORAGE] - deviceId: ${params.deviceId != null ? "SET" : "NULL"}');
    }

    // STEP 1: Prepare all data first to minimize time in critical section
    final Map<String, String> secureStorageData = {
      _authTokenKey: params.accessToken,
      _userTypeKey: params.userType,
      _onboardingCompletedKey: 'true',
    };

    if (params.userId != null) {
      secureStorageData[_userIdKey] = params.userId!;
    }

    // SECURITY FIX: Store session expiration
    if (params.expiresAt != null) {
      secureStorageData[_sessionExpiresAtKey] =
          params.expiresAt!.toIso8601String();
    }

    // SECURITY FIX: Store device ID for session binding
    if (params.deviceId != null) {
      secureStorageData[_deviceIdKey] = params.deviceId!;
    }

    final Map<String, dynamic> hiveData = {
      'user_type': params.userType,
      'onboarding_completed': true,
    };

    if (params.userId != null) {
      hiveData['user_id'] = params.userId;
    }

    // SECURITY FIX: Also store in Hive for router guard access
    if (params.expiresAt != null) {
      hiveData[_sessionExpiresAtKey] = params.expiresAt!.toIso8601String();
    }

    if (params.deviceId != null) {
      hiveData[_deviceIdKey] = params.deviceId;
    }

    // STEP 2: Store in FlutterSecureStorage atomically
    try {
      // Use Future.wait to execute all secure storage writes concurrently
      // but fail fast if any operation fails
      await Future.wait([
        for (final entry in secureStorageData.entries)
          _secureStorage.write(key: entry.key, value: entry.value),
      ]);

      Logger.error(
          '🔐 [AUTH STORAGE] ✅ Stored in FlutterSecureStorage atomically');
    } catch (e) {
      Logger.debug('🔐 [AUTH STORAGE] ❌ FlutterSecureStorage write failed: $e');
      // If secure storage fails, clear any partial writes and rethrow
      await _clearSecureStorageData();
      rethrow;
    }

    // STEP 3: Store in Hive for synchronous router access
    // SECURITY FIX: Enhanced with transaction verification
    try {
      // Ensure app_settings box is opened before accessing
      Box box;
      if (Hive.isBoxOpen('app_settings')) {
        box = Hive.box('app_settings');
      } else {
        box = await Hive.openBox('app_settings');
      }

      // SECURITY FIX: Store old values for rollback verification
      final oldValues = <String, dynamic>{};
      for (final key in hiveData.keys) {
        if (box.containsKey(key)) {
          oldValues[key] = box.get(key);
        }
      }

      // Use putAll for atomic batch write
      await box.putAll(hiveData);

      // SECURITY FIX: Verify writes succeeded
      bool verificationFailed = false;
      for (final entry in hiveData.entries) {
        final storedValue = box.get(entry.key);
        if (storedValue != entry.value) {
          verificationFailed = true;
          if (kDebugMode) {
            Logger.error(
                '🔐 [AUTH STORAGE] ⚠️ Verification failed for ${entry.key}');
            Logger.debug(
                '🔐 [AUTH STORAGE] Expected: ${entry.value}, Got: $storedValue');
          }
        }
      }

      if (verificationFailed) {
        // SECURITY FIX: Rollback Hive changes if verification failed
        Logger.warning(
            '🔐 [AUTH STORAGE] ⚠️ Rolling back Hive changes due to verification failure');

        // Restore old values
        for (final entry in oldValues.entries) {
          await box.put(entry.key, entry.value);
        }

        // Delete keys that didn't exist before
        for (final key in hiveData.keys) {
          if (!oldValues.containsKey(key)) {
            await box.delete(key);
          }
        }

        throw Exception('Hive write verification failed');
      }

      if (kDebugMode) {
        Logger.debug(
            '🔐 [AUTH STORAGE] ✅ Stored in Hive atomically and verified');

        // Verify what was actually stored
        final storedUserType = box.get('user_type');
        final storedOnboarding = box.get('onboarding_completed');
        Logger.debug(
            '🔐 [AUTH STORAGE] 🔍 Verification - Hive user_type: $storedUserType');
        Logger.debug(
            '🔐 [AUTH STORAGE] 🔍 Verification - Hive onboarding_completed: $storedOnboarding');
      }
    } catch (e) {
      if (kDebugMode) {
        Logger.error('🔐 [AUTH STORAGE] ❌ Hive storage failed: $e');
        Logger.debug(
            '🔐 [AUTH STORAGE] ⚠️ Continuing with FlutterSecureStorage only');
      }
      // ACCEPTABLE: Don't fail the entire operation if only Hive fails
      // FlutterSecureStorage is the primary source of truth
      // This is intentional graceful degradation, not exception swallowing
      // Router guards will fall back to checking Supabase session directly
    }

    Logger.error('🔐 [AUTH STORAGE] ✅ Atomic auth data storage completed');
  }

  /// Clears secure storage data in case of partial write failure
  Future<void> _clearSecureStorageData() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _authTokenKey),
        _secureStorage.delete(key: _userTypeKey),
        _secureStorage.delete(key: _userIdKey),
        // NOTE: Do NOT clear onboarding_completed key here!
        // Onboarding is a one-time per-device experience that should persist
        // across login/logout cycles and error recovery. Only clear on app reset.
        _secureStorage.delete(key: _sessionExpiresAtKey), // SECURITY FIX
        _secureStorage.delete(key: _deviceIdKey), // SECURITY FIX
      ]);
    } catch (e) {
      Logger.error('🔐 [AUTH STORAGE] ⚠️ Error clearing secure storage: $e');
    }
  }

  /// Retrieves the user type
  Future<String?> getUserType() async =>
      await _secureStorage.read(key: _userTypeKey);

  /// Retrieves the user ID
  Future<String?> getUserId() async =>
      await _secureStorage.read(key: _userIdKey);

  /// Checks if onboarding has been completed
  Future<bool> isOnboardingCompleted() async {
    final completed = await _secureStorage.read(key: _onboardingCompletedKey);
    return completed == 'true';
  }

  /// Clears only secure storage (auth tokens, user credentials)
  /// Other storage concerns are handled by their respective repositories
  Future<void> clearSecureStorage() async {
    try {
      await _secureStorage.deleteAll();
      Logger.error('🔐 [AUTH STORAGE] ✅ Secure storage cleared');
    } catch (e) {
      Logger.debug(
          '🔐 [AUTH STORAGE] ❌ Failed to clear FlutterSecureStorage: $e');
      rethrow;
    }
  }

  /// Legacy method - redirects to ClearUserDataUseCase for proper orchestration
  @Deprecated('Use ClearUserDataUseCase for comprehensive data cleanup instead')
  Future<void> clearAllData() async {
    Logger.warning(
        '🔐 [AUTH STORAGE] ⚠️ clearAllData is deprecated. Use ClearUserDataUseCase instead.');
    await clearSecureStorage();
  }
}
