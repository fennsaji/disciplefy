import '../repositories/onboarding_repository.dart';

/// Use case for saving the user's language preference
class SaveLanguagePreference {
  final OnboardingRepository _repository;

  const SaveLanguagePreference(this._repository);

  /// Saves the selected language preference
  Future<void> call(String languageCode) async {
    if (!['en', 'hi', 'ml'].contains(languageCode)) {
      throw ArgumentError('Invalid language code: $languageCode');
    }
    
    await _repository.saveLanguagePreference(languageCode);
  }
}