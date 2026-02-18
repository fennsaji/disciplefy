import '../models/app_language.dart';
import '../di/injection_container.dart';
import '../router/app_routes.dart';
import 'language_preference_service.dart';
import '../utils/logger.dart';

/// Service to handle authentication flow redirects including language selection
class AuthFlowService {
  static final LanguagePreferenceService _languageService =
      sl<LanguagePreferenceService>();

  /// Check if authenticated user needs language selection
  /// Returns the appropriate redirect path or null if no redirect needed
  static Future<String?> checkPostAuthRedirect({
    required bool isNewUser,
  }) async {
    try {
      // For new users, always show language selection if not completed
      if (isNewUser) {
        final hasCompleted =
            await _languageService.hasCompletedLanguageSelection();
        if (!hasCompleted) {
          return AppRoutes.languageSelection;
        }
      }

      // For existing users, check if they have completed language selection
      final hasCompleted =
          await _languageService.hasCompletedLanguageSelection();
      if (!hasCompleted) {
        return AppRoutes.languageSelection;
      }

      return null; // No redirect needed
    } catch (e) {
      Logger.debug('Error checking post-auth redirect: $e');
      return null; // Don't block user flow due to errors
    }
  }

  /// Mark user as having completed the initial setup flow
  static Future<void> markInitialSetupComplete() async {
    try {
      await _languageService.markLanguageSelectionCompleted();
    } catch (e) {
      Logger.debug('Error marking initial setup complete: $e');
    }
  }

  /// Check if a user should see language selection based on their auth state
  static Future<bool> shouldShowLanguageSelection() async {
    try {
      final hasCompleted =
          await _languageService.hasCompletedLanguageSelection();
      if (hasCompleted) {
        return false;
      }

      // Check if user has completed language selection
      return false; // If we reach here, selection is completed
    } catch (e) {
      Logger.debug('Error checking if should show language selection: $e');
      return false;
    }
  }

  /// Set up language preference for new user
  static Future<void> initializeUserLanguage(AppLanguage language) async {
    try {
      await _languageService.saveLanguagePreference(language);
      await _languageService.markLanguageSelectionCompleted();
    } catch (e) {
      Logger.debug('Error initializing user language: $e');
      // Still mark as completed to prevent infinite loops
      await _languageService.markLanguageSelectionCompleted();
    }
  }
}
