import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/secure_store_repository.dart';
import '../../../../core/utils/logger.dart';

/// Implementation of SecureStoreRepository that wraps FlutterSecureStorage
/// Isolates FlutterSecureStorage SDK from domain layer following Clean Architecture
class SecureStoreRepositoryImpl implements SecureStoreRepository {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  @override
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
      Logger.error('🔐 [SECURE STORE] ✅ All secure storage cleared');
    } catch (e) {
      Logger.debug('🔐 [SECURE STORE] ❌ Error clearing secure storage: $e');
      rethrow;
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      Logger.error('🔐 [SECURE STORE] ❌ Error reading key $key: $e');
      rethrow;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      Logger.error('🔐 [SECURE STORE] ✅ Written key: $key');
    } catch (e) {
      Logger.debug('🔐 [SECURE STORE] ❌ Error writing key $key: $e');
      rethrow;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
      Logger.error('🔐 [SECURE STORE] ✅ Deleted key: $key');
    } catch (e) {
      Logger.debug('🔐 [SECURE STORE] ❌ Error deleting key $key: $e');
      rethrow;
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _secureStorage.containsKey(key: key);
    } catch (e) {
      Logger.error('🔐 [SECURE STORE] ❌ Error checking key $key: $e');
      rethrow;
    }
  }
}
