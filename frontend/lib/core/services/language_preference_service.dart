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
  /// For authenticated users, checks database first, then local storage
  /// For anonymous users, checks local storage only
  Future<AppLanguage> getSelectedLanguage() async {
    try {
      // For authenticated non-anonymous users, check database first
      if (_authStateProvider.isAuthenticated &&
          !_authStateProvider.isAnonymous) {
        final dbLanguageResult =
            await _userProfileService.getLanguagePreference();

        final dbLanguage = dbLanguageResult.fold(
          (failure) => null, // Failed to get from DB, fall back to local
          (language) => language,
        );

        if (dbLanguage != null) {
          // Sync local storage with database value
          await _prefs.setString(_languagePreferenceKey, dbLanguage.code);
          return dbLanguage;
        }
      }

      // Fallback to local storage (for anonymous users or DB failure)
      final languageCode = _prefs.getString(_languagePreferenceKey);
      if (languageCode != null) {
        return AppLanguage.fromCode(languageCode);
      }

      // Default to English
      return AppLanguage.english;
    } catch (e) {
      print('Error getting selected language: $e');
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

      // For authenticated non-anonymous users, also save to database
      if (_authStateProvider.isAuthenticated &&
          !_authStateProvider.isAnonymous) {
        // Invalidate profile cache, language cache, and coordinate with other caches
        _authStateProvider.invalidateProfileCache();
        _invalidateLanguageCache();
        _cacheCoordinator.invalidateLanguageCaches();
        print(
            '📄 [LANGUAGE_SERVICE] All caches invalidated for language update (including coordinated caches)');

        final updateResult =
            await _userProfileService.updateLanguagePreference(language);
        updateResult.fold(
          (failure) => print(
              'Failed to update language preference in database: ${failure.message}'),
          (profile) {
            print('Language preference updated in database successfully');
            print(
                '📄 [LANGUAGE_SERVICE] Language preference updated, all caches will be refreshed on next access');
          },
        );
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

        // First, check if we can get language preference from AuthStateProvider cache
        // This prevents API calls in most cases
        final profile = _authStateProvider.userProfile;
        if (profile != null) {
          // Check if profile explicitly has language preference data
          if (profile.containsKey('language_preference')) {
            final hasLanguage = profile['language_preference'] != null &&
                profile['language_preference'].toString().isNotEmpty;
            print(
                '🔍 [LANGUAGE_SELECTION] Found language preference in cached profile: $hasLanguage (${profile['language_preference']})');

            // Cache the result to avoid future checks
            _cacheLanguageCompletion(currentUserId, hasLanguage);

            // Ensure local storage is marked for consistency
            if (hasLanguage) {
              final locallyMarked =
                  _prefs.getBool(_hasCompletedLanguageSelectionKey) ?? false;
              if (!locallyMarked) {
                print(
                    '🔄 [LANGUAGE_SELECTION] Marking locally as completed for consistency');
                await _prefs.setBool(_hasCompletedLanguageSelectionKey, true);
              }
            }

            return hasLanguage;
          } else {
            // Profile exists but doesn't have language_preference key - likely means not set
            print(
                '🔍 [LANGUAGE_SELECTION] Profile exists but no language_preference key - assuming not completed');
            _cacheLanguageCompletion(currentUserId, false);
            return false;
          }
        }

        // If no cached profile, check if there's a language preference stored locally
        // This avoids API calls for users who have already completed language selection
        final localLanguageCode = _prefs.getString(_languagePreferenceKey);
        final locallyMarked =
            _prefs.getBool(_hasCompletedLanguageSelectionKey) ?? false;

        if (localLanguageCode != null && locallyMarked) {
          print(
              '🔍 [LANGUAGE_SELECTION] Found language preference in local storage: $localLanguageCode');

          // Cache the result to avoid future checks
          _cacheLanguageCompletion(currentUserId, true);
          return true;
        }

        // Only make API call if we don't have any local indicators
        // This should only happen for new users or after cache expiry
        print(
            '🔍 [LANGUAGE_SELECTION] No local indicators found, checking database as last resort');

        final profileExists = await _userProfileService.profileExists();
        print('🔍 [LANGUAGE_SELECTION] Profile exists: $profileExists');

        if (profileExists) {
          final languageResult =
              await _userProfileService.getLanguagePreference();
          final hasLanguage = languageResult.fold(
            (failure) {
              print(
                  '🔍 [LANGUAGE_SELECTION] Failed to get language preference: ${failure.message}');
              return false; // No language preference in DB means not completed
            },
            (language) {
              print(
                  '🔍 [LANGUAGE_SELECTION] Found language preference in DB: ${language.displayName}');
              return true; // Has language preference in DB means completed
            },
          );

          // Cache the result
          _cacheLanguageCompletion(currentUserId, hasLanguage);

          // If we have a language preference in DB, also mark local storage for consistency
          if (hasLanguage) {
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

        // Cache negative result
        _cacheLanguageCompletion(currentUserId, false);
        return false; // No profile means not completed
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
  /// For authenticated users, the completion is implicitly tracked by DB presence
  /// For anonymous users, sets local storage completion flag
  Future<void> markLanguageSelectionCompleted() async {
    try {
      // For anonymous users, mark completion in local storage
      // For authenticated users, completion is tracked by DB presence automatically
      if (_authStateProvider.isAnonymous ||
          !_authStateProvider.isAuthenticated) {
        await _prefs.setBool(_hasCompletedLanguageSelectionKey, true);
      }
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
