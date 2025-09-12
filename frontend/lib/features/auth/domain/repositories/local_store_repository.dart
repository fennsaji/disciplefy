/// Domain-level repository interface for local storage operations
/// Abstracts Hive and SharedPreferences operations from domain layer
abstract class LocalStoreRepository {
  /// Clear all local storage data including Hive boxes
  Future<void> clearAll();

  /// Clear a specific Hive box
  Future<void> clearBox(String boxName);

  /// Clear multiple Hive boxes
  Future<void> clearBoxes(List<String> boxNames);

  /// Clear SharedPreferences data
  Future<void> clearSharedPreferences();

  /// Clear user-specific keys from app settings
  Future<void> clearAppSettingsUserData();

  /// Reinitialize local storage after complete wipe
  Future<void> reinitializeStorage();

  /// Check if a box is open
  bool isBoxOpen(String boxName);

  /// Open a box if not already open
  Future<void> ensureBoxOpen(String boxName);
}
