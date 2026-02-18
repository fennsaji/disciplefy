import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding_state_model.dart';
import '../../../../core/utils/logger.dart';

/// Local data source for onboarding state using Hive
abstract class OnboardingLocalDataSource {
  /// Gets the current onboarding state from local storage
  Future<OnboardingStateModel> getOnboardingState();

  /// Saves language preference to local storage
  Future<void> saveLanguagePreference(String languageCode);

  /// Marks onboarding as completed in local storage
  Future<void> completeOnboarding();

  /// Resets onboarding state in local storage
  Future<void> resetOnboarding();
}

/// Implementation of OnboardingLocalDataSource using Hive + SharedPreferences
/// ANDROID FIX: Uses dual storage (Hive + SharedPreferences) for redundancy
class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  static const String _boxName = 'app_settings';
  static const String _languageKey = 'selected_language';
  static const String _onboardingCompletedKey = 'onboarding_completed';

  // ANDROID FIX: SharedPreferences keys for redundant storage
  static const String _prefsOnboardingKey = 'onboarding_completed';
  static const String _prefsLanguageKey = 'selected_language';

  Box get _box => Hive.box(_boxName);

  @override
  Future<OnboardingStateModel> getOnboardingState() async {
    // ANDROID FIX: Check SharedPreferences first (more reliable on Android)
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsCompleted = prefs.getBool(_prefsOnboardingKey);
      final prefsLanguage = prefs.getString(_prefsLanguageKey);

      // If SharedPreferences has data, use it as primary source
      if (prefsCompleted != null) {
        final language = prefsLanguage ?? 'en';

        // Sync back to Hive for consistency
        if (_box.get(_onboardingCompletedKey) != prefsCompleted) {
          await _box.put(_onboardingCompletedKey, prefsCompleted);
        }
        if (_box.get(_languageKey) != language) {
          await _box.put(_languageKey, language);
        }

        return OnboardingStateModel(
          selectedLanguage: language,
          isCompleted: prefsCompleted,
        );
      }
    } catch (e) {
      // SharedPreferences failed, fall back to Hive
      Logger.warning(
          '⚠️ [ONBOARDING] SharedPreferences read failed, using Hive: $e');
    }

    // Fallback to Hive storage
    final selectedLanguage =
        _box.get(_languageKey, defaultValue: 'en') as String;
    final isCompleted =
        _box.get(_onboardingCompletedKey, defaultValue: false) as bool;

    // ANDROID FIX: Sync to SharedPreferences if not present
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsOnboardingKey) == null) {
        await prefs.setBool(_prefsOnboardingKey, isCompleted);
        await prefs.setString(_prefsLanguageKey, selectedLanguage);
      }
    } catch (e) {
      Logger.warning('⚠️ [ONBOARDING] Failed to sync to SharedPreferences: $e');
    }

    return OnboardingStateModel(
      selectedLanguage: selectedLanguage,
      isCompleted: isCompleted,
    );
  }

  @override
  Future<void> saveLanguagePreference(String languageCode) async {
    // ANDROID FIX: Persist to both Hive and SharedPreferences
    await _box.put(_languageKey, languageCode);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLanguageKey, languageCode);
      Logger.warning(
          '✅ [ONBOARDING] Language preference saved to both storages');
    } catch (e) {
      Logger.debug(
          '⚠️ [ONBOARDING] Failed to save language to SharedPreferences: $e');
    }
  }

  @override
  Future<void> completeOnboarding() async {
    // ANDROID FIX: Persist to both Hive and SharedPreferences for redundancy
    await _box.put(_onboardingCompletedKey, true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsOnboardingKey, true);
      Logger.warning(
          '✅ [ONBOARDING] Onboarding completion saved to both storages');
    } catch (e) {
      Logger.error(
          '⚠️ [ONBOARDING] Failed to save onboarding to SharedPreferences: $e');
    }
  }

  @override
  Future<void> resetOnboarding() async {
    // ANDROID FIX: Clear from both Hive and SharedPreferences
    await _box.delete(_languageKey);
    await _box.delete(_onboardingCompletedKey);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsOnboardingKey);
      await prefs.remove(_prefsLanguageKey);
      Logger.warning('✅ [ONBOARDING] Onboarding reset in both storages');
    } catch (e) {
      Logger.debug('⚠️ [ONBOARDING] Failed to reset SharedPreferences: $e');
    }
  }
}
