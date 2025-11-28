import '../entities/personalization_entity.dart';

/// Repository interface for personalization operations
abstract class PersonalizationRepository {
  /// Gets the user's personalization data
  Future<PersonalizationEntity> getPersonalization();

  /// Saves the user's questionnaire responses
  Future<PersonalizationEntity> savePersonalization({
    required String? faithJourney,
    required List<String> seeking,
    required String? timeCommitment,
  });

  /// Marks the questionnaire as skipped
  Future<PersonalizationEntity> skipQuestionnaire();
}
