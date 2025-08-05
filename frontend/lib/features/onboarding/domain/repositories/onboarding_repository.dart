import '../entities/onboarding_state_entity.dart';

/// Repository interface for onboarding data operations
abstract class OnboardingRepository {
  /// Loads the current onboarding state from storage
  Future<OnboardingStateEntity> getOnboardingState();

  /// Saves the selected language preference
  Future<void> saveLanguagePreference(String languageCode);

  /// Marks onboarding as completed
  Future<void> completeOnboarding();

  /// Resets onboarding state (for testing/debugging)
  Future<void> resetOnboarding();
}
