/// Domain-level repository interface for secure storage operations
/// Abstracts FlutterSecureStorage operations from domain layer
abstract class SecureStoreRepository {
  /// Clear all secure storage data
  Future<void> clearAll();

  /// Read a value from secure storage
  Future<String?> read(String key);

  /// Write a value to secure storage
  Future<void> write(String key, String value);

  /// Delete a specific key from secure storage
  Future<void> delete(String key);

  /// Check if secure storage contains a key
  Future<bool> containsKey(String key);
}
