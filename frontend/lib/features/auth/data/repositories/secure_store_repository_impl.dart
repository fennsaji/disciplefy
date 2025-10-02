import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/secure_store_repository.dart';

/// Implementation of SecureStoreRepository that wraps FlutterSecureStorage
/// Isolates FlutterSecureStorage SDK from domain layer following Clean Architecture
class SecureStoreRepositoryImpl implements SecureStoreRepository {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  @override
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
      if (kDebugMode) {
        print('🔐 [SECURE STORE] ✅ All secure storage cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [SECURE STORE] ❌ Error clearing secure storage: $e');
      }
      rethrow;
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [SECURE STORE] ❌ Error reading key $key: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      if (kDebugMode) {
        print('🔐 [SECURE STORE] ✅ Written key: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [SECURE STORE] ❌ Error writing key $key: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
      if (kDebugMode) {
        print('🔐 [SECURE STORE] ✅ Deleted key: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [SECURE STORE] ❌ Error deleting key $key: $e');
      }
      rethrow;
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _secureStorage.containsKey(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [SECURE STORE] ❌ Error checking key $key: $e');
      }
      rethrow;
    }
  }
}
