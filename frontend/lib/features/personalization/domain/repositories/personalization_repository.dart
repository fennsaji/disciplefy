import '../entities/personalization_entity.dart';

/// Repository interface for personalization operations
abstract class PersonalizationRepository {
  /// Gets the user's personalization data
  Future<PersonalizationEntity> getPersonalization();

  /// Saves the user's questionnaire responses (6 questions)
  Future<PersonalizationEntity> savePersonalization({
    required FaithStage? faithStage,
    required List<SpiritualGoal> spiritualGoals,
    required TimeAvailability? timeAvailability,
    required LearningStyle? learningStyle,
    required LifeStageFocus? lifeStageFocus,
    required BiggestChallenge? biggestChallenge,
  });

  /// Marks the questionnaire as skipped
  Future<PersonalizationEntity> skipQuestionnaire();
}
