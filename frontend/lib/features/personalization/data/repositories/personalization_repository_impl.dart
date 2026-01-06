import '../../domain/entities/personalization_entity.dart';
import '../../domain/repositories/personalization_repository.dart';
import '../datasources/personalization_remote_datasource.dart';

/// Implementation of PersonalizationRepository
class PersonalizationRepositoryImpl implements PersonalizationRepository {
  final PersonalizationRemoteDataSource _remoteDataSource;

  PersonalizationRepositoryImpl({
    PersonalizationRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
            remoteDataSource ?? PersonalizationRemoteDataSource();

  @override
  Future<PersonalizationEntity> getPersonalization() async {
    final data = await _remoteDataSource.getPersonalization();
    return _mapToEntity(data);
  }

  @override
  Future<PersonalizationEntity> savePersonalization({
    required FaithStage? faithStage,
    required List<SpiritualGoal> spiritualGoals,
    required TimeAvailability? timeAvailability,
    required LearningStyle? learningStyle,
    required LifeStageFocus? lifeStageFocus,
    required BiggestChallenge? biggestChallenge,
  }) async {
    final data = await _remoteDataSource.savePersonalization(
      faithStage: faithStage?.value,
      spiritualGoals: spiritualGoals.map((g) => g.value).toList(),
      timeAvailability: timeAvailability?.value,
      learningStyle: learningStyle?.value,
      lifeStageFocus: lifeStageFocus?.value,
      biggestChallenge: biggestChallenge?.value,
    );
    return _mapToEntity(data);
  }

  @override
  Future<PersonalizationEntity> skipQuestionnaire() async {
    final data = await _remoteDataSource.skipQuestionnaire();
    return _mapToEntity(data);
  }

  PersonalizationEntity _mapToEntity(Map<String, dynamic> data) {
    // Parse spiritual goals from array of strings
    final spiritualGoalsData = data['spiritual_goals'] as List<dynamic>?;
    final spiritualGoalsList =
        spiritualGoalsData?.map((e) => e.toString()).toList() ?? [];

    return PersonalizationEntity(
      faithStage: FaithStage.fromValue(data['faith_stage'] as String?),
      spiritualGoals: SpiritualGoal.listFromValues(spiritualGoalsList),
      timeAvailability:
          TimeAvailability.fromValue(data['time_availability'] as String?),
      learningStyle: LearningStyle.fromValue(data['learning_style'] as String?),
      lifeStageFocus:
          LifeStageFocus.fromValue(data['life_stage_focus'] as String?),
      biggestChallenge:
          BiggestChallenge.fromValue(data['biggest_challenge'] as String?),
      scoringResults: data['scoring_results'] as Map<String, dynamic>?,
      questionnaireCompleted: data['questionnaire_completed'] as bool? ?? false,
      questionnaireSkipped: data['questionnaire_skipped'] as bool? ?? false,
    );
  }
}
