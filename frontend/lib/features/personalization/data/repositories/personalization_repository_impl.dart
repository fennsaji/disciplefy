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
    required String? faithJourney,
    required List<String> seeking,
    required String? timeCommitment,
  }) async {
    final data = await _remoteDataSource.savePersonalization(
      faithJourney: faithJourney,
      seeking: seeking,
      timeCommitment: timeCommitment,
    );
    return _mapToEntity(data);
  }

  @override
  Future<PersonalizationEntity> skipQuestionnaire() async {
    final data = await _remoteDataSource.skipQuestionnaire();
    return _mapToEntity(data);
  }

  PersonalizationEntity _mapToEntity(Map<String, dynamic> data) {
    return PersonalizationEntity(
      faithJourney: data['faith_journey'] as String?,
      seeking: (data['seeking'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      timeCommitment: data['time_commitment'] as String?,
      questionnaireCompleted: data['questionnaire_completed'] as bool? ?? false,
      questionnaireSkipped: data['questionnaire_skipped'] as bool? ?? false,
    );
  }
}
