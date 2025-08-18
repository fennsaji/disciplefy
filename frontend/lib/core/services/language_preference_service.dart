import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/user_profile/data/services/user_profile_service.dart';
import '../services/auth_state_provider.dart';

/// Service for managing user language preferences
/// Enhanced version that checks database first for authenticated users
/// Now includes change notifications via StreamController
class LanguagePreferenceService {
  static const String _languagePreferenceKey = 'user_language_preference';
  static const String _hasCompletedLanguageSelectionKey =
      'has_completed_language_selection';

  final SharedPreferences _prefs;
  final AuthService _authService;
  final AuthStateProvider _authStateProvider;
  final UserProfileService _userProfileService;

  // Stream controller for language change notifications
  final StreamController<AppLanguage> _languageChangeController =
      StreamController<AppLanguage>.broadcast();

  LanguagePreferenceService({
    required SharedPreferences prefs,
    required AuthService authService,
    required AuthStateProvider authStateProvider,
    required UserProfileService userProfileService,
  })  : _prefs = prefs,
        _authService = authService,
        _authStateProvider = authStateProvider,
        _userProfileService = userProfileService;

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
  Future<void> saveLanguagePreference(AppLanguage language) async {
    try {
      // Save to local storage first (always)
      await _prefs.setString(_languagePreferenceKey, language.code);

      // For authenticated non-anonymous users, also save to database
      if (_authStateProvider.isAuthenticated &&
          !_authStateProvider.isAnonymous) {
        final updateResult =
            await _userProfileService.updateLanguagePreference(language);
        updateResult.fold(
          (failure) => print(
              'Failed to update language preference in database: ${failure.message}'),
          (profile) =>
              print('Language preference updated in database successfully'),
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
  Future<bool> hasCompletedLanguageSelection() async {
    try {
      // For authenticated non-anonymous users, check if they have a language preference in DB
      if (_authStateProvider.isAuthenticated &&
          !_authStateProvider.isAnonymous) {
        print(
            '🔍 [LANGUAGE_SELECTION] Checking completion for authenticated user');

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

          // If we have a language preference in DB, also check if local storage is marked
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
  Future<void> syncWithProfile() async {
    try {
      if (!_authStateProvider.isAuthenticated ||
          _authStateProvider.isAnonymous) {
        return;
      }

      // Get current local language preference
      final localLanguageCode = _prefs.getString(_languagePreferenceKey);

      if (localLanguageCode != null) {
        // User has local preference, sync it to database
        final localLanguage = AppLanguage.fromCode(localLanguageCode);
        await _userProfileService.updateLanguagePreference(localLanguage);
        print(
            'Synced local language preference to database: ${localLanguage.displayName}');
      } else {
        // No local preference, try to get from database and sync locally
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
    } catch (e) {
      print('Error resetting language selection: $e');
    }
  }
}
