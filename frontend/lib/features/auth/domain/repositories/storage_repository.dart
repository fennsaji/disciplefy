/// Repository interface for managing different types of app storage
/// Follows Clean Architecture principles by defining contracts in domain layer
abstract class StorageRepository {
  /// Clear all data from secure storage (auth tokens, credentials)
  Future<void> clearSecureStorage();

  /// Clear specific Hive box by name
  Future<void> clearHiveBox(String boxName);

  /// Clear user-specific data from app_settings box while preserving app-level settings
  Future<void> clearAppSettingsUserData();

  /// Clear all SharedPreferences data
  Future<void> clearSharedPreferences();

  /// Clear and delete multiple Hive boxes
  Future<void> clearHiveBoxes(List<String> boxNames);
}
