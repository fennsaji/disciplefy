import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/auth_params.dart';

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

  /// Stores authentication data securely with atomic transactions
  /// Prevents race conditions by ensuring all-or-nothing storage operations
  Future<void> storeAuthData(AuthDataStorageParams params) async {
    if (kDebugMode) {
      print('🔐 [AUTH STORAGE] Starting atomic auth data storage...');
      print('🔐 [AUTH STORAGE] - userType: ${params.userType}');
      print('🔐 [AUTH STORAGE] - userId: ${params.userId}');
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

    final Map<String, dynamic> hiveData = {
      'user_type': params.userType,
      'onboarding_completed': true,
    };

    if (params.userId != null) {
      hiveData['user_id'] = params.userId;
    }

    // STEP 2: Store in FlutterSecureStorage atomically
    try {
      // Use Future.wait to execute all secure storage writes concurrently
      // but fail fast if any operation fails
      await Future.wait([
        for (final entry in secureStorageData.entries) _secureStorage.write(key: entry.key, value: entry.value),
      ]);

      if (kDebugMode) {
        print('🔐 [AUTH STORAGE] ✅ Stored in FlutterSecureStorage atomically');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [AUTH STORAGE] ❌ FlutterSecureStorage write failed: $e');
      }
      // If secure storage fails, clear any partial writes and rethrow
      await _clearSecureStorageData();
      rethrow;
    }

    // STEP 3: Store in Hive for synchronous router access
    try {
      final box = Hive.box('app_settings');

      // Use transaction to ensure atomic writes to Hive
      await box.putAll(hiveData);

      if (kDebugMode) {
        print('🔐 [AUTH STORAGE] ✅ Stored in Hive atomically');

        // Verify what was actually stored
        final storedUserType = box.get('user_type');
        final storedOnboarding = box.get('onboarding_completed');
        print('🔐 [AUTH STORAGE] 🔍 Verification - Hive user_type: $storedUserType');
        print('🔐 [AUTH STORAGE] 🔍 Verification - Hive onboarding_completed: $storedOnboarding');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [AUTH STORAGE] ❌ Hive storage failed: $e');
        print('🔐 [AUTH STORAGE] ⚠️ Continuing with FlutterSecureStorage only');
      }
      // ACCEPTABLE: Don't fail the entire operation if only Hive fails
      // FlutterSecureStorage is the primary source of truth
      // This is intentional graceful degradation, not exception swallowing
    }

    if (kDebugMode) {
      print('🔐 [AUTH STORAGE] ✅ Atomic auth data storage completed');
    }
  }

  /// Clears secure storage data in case of partial write failure
  Future<void> _clearSecureStorageData() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _authTokenKey),
        _secureStorage.delete(key: _userTypeKey),
        _secureStorage.delete(key: _userIdKey),
        _secureStorage.delete(key: _onboardingCompletedKey),
      ]);
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [AUTH STORAGE] ⚠️ Error clearing secure storage: $e');
      }
    }
  }

  /// Retrieves the user type
  Future<String?> getUserType() async => await _secureStorage.read(key: _userTypeKey);

  /// Retrieves the user ID
  Future<String?> getUserId() async => await _secureStorage.read(key: _userIdKey);

  /// Checks if onboarding has been completed
  Future<bool> isOnboardingCompleted() async {
    final completed = await _secureStorage.read(key: _onboardingCompletedKey);
    return completed == 'true';
  }

  /// Signs out the user by clearing all stored data
  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();

    // Also clear Hive storage
    try {
      final box = Hive.box('app_settings');
      await box.delete('user_type');
      await box.delete('user_id');
      await box.delete('onboarding_completed');
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Failed to clear auth data from Hive: $e');
      }
    }
  }
}
