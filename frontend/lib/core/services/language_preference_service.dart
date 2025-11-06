import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/user_profile/data/services/user_profile_service.dart';
import '../services/auth_state_provider.dart';
import '../services/language_cache_coordinator.dart';

/// Service for managing user language preferences
/// Enhanced version that checks database first for authenticated users
/// Now includes change notifications via StreamController
/// With intelligent caching to prevent excessive API calls
class LanguagePreferenceService {
  static const String _languagePreferenceKey = 'user_language_preference';
  static const String _hasCompletedLanguageSelectionKey =
      'has_completed_language_selection';

  final SharedPreferences _prefs;
  final AuthService _authService;
  final AuthStateProvider _authStateProvider;
  final UserProfileService _userProfileService;
  final LanguageCacheCoordinator _cacheCoordinator;

  // Stream controller for language change notifications
  final StreamController<AppLanguage> _languageChangeController =
      StreamController<AppLanguage>.broadcast();

  // Caching to prevent excessive API calls
  String? _cachedUserId;
  bool? _cachedHasCompletedSelection;
  AppLanguage? _cachedLanguage;
  DateTime? _cacheTimestamp;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  LanguagePreferenceService({
    required SharedPreferences prefs,
    required AuthService authService,
    required AuthStateProvider authStateProvider,
    required UserProfileService userProfileService,
    required LanguageCacheCoordinator cacheCoordinator,
  })  : _prefs = prefs,
        _authService = authService,
        _authStateProvider = authStateProvider,
        _userProfileService = userProfileService,
        _cacheCoordinator = cacheCoordinator;

  /// Stream of language preference changes
  Stream<AppLanguage> get languageChanges => _languageChangeController.stream;

  /// Dispose method to clean up resources
  void dispose() {
    _languageChangeController.close();
  }

  /// Get the selected language preference with fallback logic
  /// For authenticated users, checks database first, then local storage, then cache
  /// For anonymous users, checks local storage, then cache
  /// Uses in-memory cache to prevent language loss during temporary API failures
  Future<AppLanguage> getSelectedLanguage() async {
    try {
      // For authenticated non-anonymous users, check database first
      if (_authStateProvider.isAuthenticated &&
          !_authStateProvider.isAnonymous) {
        final dbLanguageResult =
            await _userProfileService.getLanguagePreference();

        final dbLanguage = dbLanguageResult.fold(
          (failure) {
            print(
                '⚠️ [LANGUAGE_SERVICE] Database call failed: ${failure.message}');
            return null; // Failed to get from DB, fall back to local/cache
          },
          (language) => language,
        );

        if (dbLanguage != null) {
          // Sync local storage with database value and cache it
          await _prefs.setString(_languagePreferenceKey, dbLanguage.code);
          _cachedLanguage = dbLanguage;
          print(
              '✅ [LANGUAGE_SERVICE] Retrieved from DB and cached: ${dbLanguage.displayName}');
          return dbLanguage;
        }
      }

      // Fallback to local storage (for anonymous users or DB failure)
      final languageCode = _prefs.getString(_languagePreferenceKey);
      if (languageCode != null) {
        final language = AppLanguage.fromCode(languageCode);
        _cachedLanguage = language;
        print(
            '✅ [LANGUAGE_SERVICE] Retrieved from local storage and cached: ${language.displayName}');
        return language;
      }

      // Fallback to cached language before defaulting to English
      // This prevents language loss during temporary API/storage failures
      if (_cachedLanguage != null) {
        print(
            '✅ [LANGUAGE_SERVICE] Using cached language (API/storage failed): ${_cachedLanguage!.displayName}');
        return _cachedLanguage!;
      }

      // Default to English only if all sources fail
      print('⚠️ [LANGUAGE_SERVICE] All sources failed, defaulting to English');
      return AppLanguage.english;
    } catch (e) {
      print('Error getting selected language: $e');

      // Even in error cases, try to use cached language before defaulting to English
      if (_cachedLanguage != null) {
        print(
            '✅ [LANGUAGE_SERVICE] Exception occurred, using cached language: ${_cachedLanguage!.displayName}');
        return _cachedLanguage!;
      }

      return AppLanguage.english;
    }
  }

  /// Save language preference to both local storage and database
  /// For authenticated users, saves to database first, then local storage
  /// For anonymous users, saves to local storage only
  /// Notifies listeners of the language change
  /// Invalidates profile cache to ensure fresh data is fetched
  Future<void> saveLanguagePreference(AppLanguage language) async {
    try {
      // Save to local storage first (always)
      await _prefs.setString(_languagePreferenceKey, language.code);

      // Cache the language immediately to prevent loss during API failures
      _cachedLanguage = language;
      print('💾 [LANGUAGE_SERVICE] Language cached: ${language.displayName}');

      // For authenticated non-anonymous users, also save to database
      if (_authStateProvider.isAuthenticated &&
          !_authStateProvider.isAnonymous) {
        final currentUserId = _authStateProvider.userId;

        // FIX: Update database FIRST, then invalidate caches
        final updateResult =
            await _userProfileService.updateLanguagePreference(language);

        final dbUpdateSuccessful = updateResult.fold(
          (failure) {
            print(
                'Failed to update language preference in database: ${failure.message}');
            return false;
          },
          (profile) {
            print('Language preference updated in database successfully');
            return true;
          },
        );

        // FIX: Cache the completion state BEFORE invalidating other caches
        // This prevents race condition where router guard checks before DB update completes
        if (dbUpdateSuccessful) {
          _cacheLanguageCompletion(currentUserId, true);
          print(
              '✅ [LANGUAGE_SERVICE] Language completion cached BEFORE invalidation');

          // Now invalidate other caches after successful DB update
          _authStateProvider.invalidateProfileCache();
          _cacheCoordinator.invalidateLanguageCaches();
          print(
              '📄 [LANGUAGE_SERVICE] Profile caches invalidated after language update');
        }
      }

      // Notify listeners of the language change
      _languageChangeController.add(language);
      print('🔄 Language preference changed to: ${language.displayName}');
    } catch (e) {
      print('Error saving language preference: $e');
    }
  }

  /// Check if user has completed initial language selection
  /// For authenticated users, checks if language preference exists in database
  /// For anonymous users, checks local storage completion flag
  /// Uses intelligent caching to prevent excessive API calls
  Future<bool> hasCompletedLanguageSelection() async {
    try {
      final currentUserId = _authStateProvider.userId;

      // For authenticated non-anonymous users, check if they have a language preference in DB
      if (_authStateProvider.isAuthenticated &&
          !_authStateProvider.isAnonymous) {
        // Check cache first - avoid API calls if we have fresh data for the same user
        if (_isCacheFresh() &&
            _cachedUserId == currentUserId &&
            _cachedHasCompletedSelection != null) {
          print(
              '🔍 [LANGUAGE_SELECTION] Using cached completion status: $_cachedHasCompletedSelection');
          return _cachedHasCompletedSelection!;
        }

        print(
            '🔍 [LANGUAGE_SELECTION] Checking completion for authenticated user');

        // For new phone auth users, we need to check if they actually have a profile
        // If no profile exists, they haven't completed language selection
        final profileExists = await _userProfileService.profileExists();
        print('🔍 [LANGUAGE_SELECTION] Profile exists: $profileExists');

        if (!profileExists) {
          // New user - no profile means language selection not completed
          print(
              '🔍 [LANGUAGE_SELECTION] New user detected - no profile exists');
          _cacheLanguageCompletion(currentUserId, false);
          return false;
        }

        // Profile exists - check if it has language preference
        final languageResult =
            await _userProfileService.getLanguagePreference();
        final hasLanguage = languageResult.fold(
          (failure) {
            print(
                '❌ [LANGUAGE_SELECTION] Failed to get language preference: ${failure.message}');

            // Failure: Use locally stored/cached value as fallback instead of overwriting
            final locallyMarked =
                _prefs.getBool(_hasCompletedLanguageSelectionKey) ?? false;
            print(
                '📦 [LANGUAGE_SELECTION] Using cached local completion status: $locallyMarked');

            // Return local state, DO NOT cache false when remote call failed
            return locallyMarked;
          },
          (language) {
            print(
                '✅ [LANGUAGE_SELECTION] Found language preference in DB: ${language.displayName}');
            return true; // Has language preference in DB means completed
          },
        );

        // Only cache the result if it came from a successful remote call
        // Don't cache when using fallback local state
        if (languageResult.isRight()) {
          _cacheLanguageCompletion(currentUserId, hasLanguage);
        } else {
          print(
              '⚠️ [LANGUAGE_SELECTION] Not caching result - using fallback local state due to API failure');
        }

        // If we have a language preference in DB (successful call), mark local storage for consistency
        if (hasLanguage && languageResult.isRight()) {
          final locallyMarked =
              _prefs.getBool(_hasCompletedLanguageSelectionKey) ?? false;
          print(
              '🔍 [LANGUAGE_SELECTION] Locally marked as completed: $locallyMarked');

          // If not locally marked but has DB preference, mark it locally for consistency
          if (!locallyMarked) {
            print(
                '🔄 [LANGUAGE_SELECTION] Marking locally as completed for consistency');
            await _prefs.setBool(_hasCompletedLanguageSelectionKey, true);
          }
        }

        return hasLanguage;
      }

      // For anonymous users, check local storage completion flag
      final isCompleted =
          _prefs.getBool(_hasCompletedLanguageSelectionKey) ?? false;
      print(
          '🔍 [LANGUAGE_SELECTION] Anonymous user completion status: $isCompleted');
      return isCompleted;
    } catch (e) {
      print('Error checking language selection completion: $e');
      return false;
    }
  }

  /// Mark that user has completed initial language selection
  /// FIX: Now sets local storage flag for ALL users (authenticated and anonymous)
  /// This ensures the flag is set before any async DB operations complete
  Future<void> markLanguageSelectionCompleted() async {
    try {
      // FIX: Set local flag for ALL users, not just anonymous
      // This prevents race condition where router checks before DB update completes
      await _prefs.setBool(_hasCompletedLanguageSelectionKey, true);
      print('✅ [LANGUAGE_SERVICE] Marked language selection completed locally');

      // Also cache the completion state for the current user
      final currentUserId = _authStateProvider.userId;
      _cacheLanguageCompletion(currentUserId, true);
    } catch (e) {
      print('Error marking language selection completed: $e');
    }
  }

  /// Sync local preferences with database profile for authenticated users
  /// This is useful when a user upgrades from anonymous to authenticated
  /// Enhanced to use cached profile data to avoid excessive API calls
  Future<void> syncWithProfile() async {
    try {
      if (!_authStateProvider.isAuthenticated ||
          _authStateProvider.isAnonymous) {
        return;
      }

      // Get current local language preference
      final localLanguageCode = _prefs.getString(_languagePreferenceKey);

      if (localLanguageCode != null) {
        // User has local preference, check if we need to sync it to database
        final localLanguage = AppLanguage.fromCode(localLanguageCode);

        // First, check cached profile to see if sync is needed
        final cachedProfile = _authStateProvider.userProfile;
        if (cachedProfile != null &&
            cachedProfile.containsKey('language_preference')) {
          final dbLanguageCode =
              cachedProfile['language_preference']?.toString();

          // Only make API call if local and database languages differ
          if (dbLanguageCode != localLanguageCode) {
            await _userProfileService.updateLanguagePreference(localLanguage);
            // Update cached profile to reflect the change
            _authStateProvider.invalidateProfileCache();
            print(
                'Synced local language preference to database: ${localLanguage.displayName}');
          } else {
            print('Language preferences already in sync, skipping API call');
          }
        } else {
          // No cached profile or language preference, update database
          await _userProfileService.updateLanguagePreference(localLanguage);
          // Update cached profile to reflect the change
          _authStateProvider.invalidateProfileCache();
          print(
              'Synced local language preference to database: ${localLanguage.displayName}');
        }
      } else {
        // No local preference, check cached profile first before API call
        final cachedProfile = _authStateProvider.userProfile;
        if (cachedProfile != null &&
            cachedProfile.containsKey('language_preference')) {
          final dbLanguageCode =
              cachedProfile['language_preference']?.toString();
          if (dbLanguageCode != null && dbLanguageCode.isNotEmpty) {
            // Use cached language preference
            await _prefs.setString(_languagePreferenceKey, dbLanguageCode);
            final language = AppLanguage.fromCode(dbLanguageCode);
            print(
                'Synced cached language preference to local: ${language.displayName}');
            return;
          }
        }

        // No cached data or language preference, fallback to API call
        final dbLanguageResult =
            await _userProfileService.getLanguagePreference();
        dbLanguageResult.fold(
          (failure) => print('No language preference found in database'),
          (language) async {
            await _prefs.setString(_languagePreferenceKey, language.code);
            print(
                'Synced database language preference to local: ${language.displayName}');
          },
        );
      }
    } catch (e) {
      print('Error syncing with profile: $e');
    }
  }

  /// Reset language selection status
  Future<void> resetLanguageSelectionStatus() async {
    try {
      await _prefs.remove(_hasCompletedLanguageSelectionKey);
      await _prefs.remove(_languagePreferenceKey);
      _invalidateLanguageCache();
      _cacheCoordinator.invalidateLanguageCaches();
    } catch (e) {
      print('Error resetting language selection: $e');
    }
  }

  /// Cache language completion status to avoid repeated API calls
  void _cacheLanguageCompletion(String? userId, bool hasCompleted) {
    _cachedUserId = userId;
    _cachedHasCompletedSelection = hasCompleted;
    _cacheTimestamp = DateTime.now();
    print(
        '🔄 [LANGUAGE_CACHE] Cached completion status: $hasCompleted for user: $userId');
  }

  /// Check if cached data is still fresh
  bool _isCacheFresh() {
    if (_cacheTimestamp == null) return false;
    final age = DateTime.now().difference(_cacheTimestamp!);
    return age < _cacheExpiry;
  }

  /// Invalidate language cache (call when language preferences change)
  void invalidateLanguageCache() {
    _cachedUserId = null;
    _cachedHasCompletedSelection = null;
    _cachedLanguage = null;
    _cacheTimestamp = null;
    print('🔄 [LANGUAGE_CACHE] Language cache invalidated');
  }

  /// Private helper for internal cache invalidation
  void _invalidateLanguageCache() => invalidateLanguageCache();
}
