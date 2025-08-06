import 'package:hive_flutter/hive_flutter.dart';
import '../models/onboarding_state_model.dart';

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

/// Implementation of OnboardingLocalDataSource using Hive
class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  static const String _boxName = 'app_settings';
  static const String _languageKey = 'selected_language';
  static const String _onboardingCompletedKey = 'onboarding_completed';

  Box get _box => Hive.box(_boxName);

  @override
  Future<OnboardingStateModel> getOnboardingState() async {
    final selectedLanguage =
        _box.get(_languageKey, defaultValue: 'en') as String;
    final isCompleted =
        _box.get(_onboardingCompletedKey, defaultValue: false) as bool;

    return OnboardingStateModel(
      selectedLanguage: selectedLanguage,
      isCompleted: isCompleted,
    );
  }

  @override
  Future<void> saveLanguagePreference(String languageCode) async {
    await _box.put(_languageKey, languageCode);
  }

  @override
  Future<void> completeOnboarding() async {
    await _box.put(_onboardingCompletedKey, true);
  }

  @override
  Future<void> resetOnboarding() async {
    await _box.delete(_languageKey);
    await _box.delete(_onboardingCompletedKey);
  }
}
