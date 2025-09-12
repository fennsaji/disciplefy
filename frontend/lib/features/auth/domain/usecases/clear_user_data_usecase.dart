import '../repositories/auth_session_repository.dart';
import '../repositories/local_store_repository.dart';
import '../repositories/secure_store_repository.dart';
import '../repositories/storage_repository.dart';

/// Use case for clearing user data during logout and account deletion
/// Orchestrates cleanup through repository interfaces following Clean Architecture
class ClearUserDataUseCase {
  final AuthSessionRepository _authSessionRepository;
  final SecureStoreRepository _secureStoreRepository;
  final LocalStoreRepository _localStoreRepository;
  final StorageRepository
      _storageRepository; // Legacy - for backward compatibility

  const ClearUserDataUseCase({
    required AuthSessionRepository authSessionRepository,
    required SecureStoreRepository secureStoreRepository,
    required LocalStoreRepository localStoreRepository,
    required StorageRepository storageRepository,
  })  : _authSessionRepository = authSessionRepository,
        _secureStoreRepository = secureStoreRepository,
        _localStoreRepository = localStoreRepository,
        _storageRepository = storageRepository;

  /// List of Hive boxes that contain user-specific data
  static const List<String> _userDataBoxes = [
    'user_preferences',
    'cached_data',
    'study_guides_cache',
    'daily_verse_cache',
    'saved_guides',
    'recent_guides',
  ];

  /// Clears all user data including auth session, secure storage, and local storage
  /// Orchestrates cleanup through repository abstractions maintaining Clean Architecture
  Future<void> execute() async {
    await Future.wait([
      _clearAuthSession(),
      _clearSecureStorage(),
      _clearLocalStorage(),
    ]);
  }

  /// Clear authentication session through domain abstraction
  Future<void> _clearAuthSession() async {
    try {
      await _authSessionRepository.clearSession();
    } catch (e) {
      // Log error through repository if needed, don't expose framework details
      rethrow;
    }
  }

  /// Clear secure storage through domain abstraction
  Future<void> _clearSecureStorage() async {
    try {
      await _secureStoreRepository.clearAll();
    } catch (e) {
      // Log error through repository if needed, don't expose framework details
      rethrow;
    }
  }

  /// Clear local storage through domain abstraction
  Future<void> _clearLocalStorage() async {
    try {
      // Try comprehensive clear first
      await _localStoreRepository.clearAll();
    } catch (e) {
      // Fallback to individual clearing through repository abstraction
      try {
        await _clearIndividualLocalData();
      } catch (fallbackError) {
        // If both fail, rethrow original error
        rethrow;
      }
    }
  }

  /// Fallback method: Clear individual local storage components
  Future<void> _clearIndividualLocalData() async {
    await Future.wait([
      _localStoreRepository.clearBoxes(_userDataBoxes),
      _localStoreRepository.clearAppSettingsUserData(),
      _localStoreRepository.clearSharedPreferences(),
    ]);
  }
}
