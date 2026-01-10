import '../../../../core/network/network_info.dart';
import '../../domain/entities/reflection_response.dart';
import '../../domain/entities/study_mode.dart';
import '../../domain/repositories/reflections_repository.dart';
import '../datasources/reflections_remote_data_source.dart';

/// Concrete implementation of ReflectionsRepository.
///
/// This implementation follows Clean Architecture by:
/// - Implementing the domain repository interface
/// - Delegating to the data layer remote data source
/// - Converting between data models and domain entities
/// - Checking network connectivity before remote operations
class ReflectionsRepositoryImpl implements ReflectionsRepository {
  final ReflectionsRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  ReflectionsRepositoryImpl({
    required ReflectionsRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  @override
  Future<ReflectionSession> saveReflection({
    required String studyGuideId,
    required StudyMode studyMode,
    required List<ReflectionResponse> responses,
    required int timeSpentSeconds,
    DateTime? completedAt,
  }) async {
    // Convert responses to JSONB format
    final responsesJson = <String, dynamic>{};
    for (final response in responses) {
      responsesJson.addAll(response.toJson());
    }

    final model = await _remoteDataSource.saveReflection(
      studyGuideId: studyGuideId,
      studyMode: studyMode,
      responses: responsesJson,
      timeSpentSeconds: timeSpentSeconds,
      completedAt: completedAt,
    );

    return model.toEntity();
  }

  @override
  Future<ReflectionSession?> getReflection(String reflectionId) async {
    final model = await _remoteDataSource.getReflection(reflectionId);
    return model?.toEntity();
  }

  @override
  Future<ReflectionSession?> getReflectionForGuide(String studyGuideId) async {
    final model = await _remoteDataSource.getReflectionForGuide(studyGuideId);
    return model?.toEntity();
  }

  @override
  Future<ReflectionListResult> listReflections({
    int page = 1,
    int perPage = 20,
    StudyMode? studyMode,
  }) async {
    final listModel = await _remoteDataSource.listReflections(
      page: page,
      perPage: perPage,
      studyMode: studyMode,
    );

    return ReflectionListResult(
      reflections: listModel.toEntities(),
      total: listModel.total,
      page: listModel.page,
      perPage: listModel.perPage,
      hasMore: listModel.hasMore,
    );
  }

  @override
  Future<void> deleteReflection(String reflectionId) async {
    await _remoteDataSource.deleteReflection(reflectionId);
  }

  @override
  Future<ReflectionStats> getReflectionStats() async {
    final statsModel = await _remoteDataSource.getReflectionStats();

    // Convert string mode keys to StudyMode enum
    final reflectionsByMode = <StudyMode, int>{};
    for (final entry in statsModel.reflectionsByMode.entries) {
      final mode = studyModeFromString(entry.key);
      if (mode != null) {
        reflectionsByMode[mode] = entry.value;
      } else {
        print(
            '⚠️ [REFLECTIONS_REPOSITORY] Skipping invalid study mode: ${entry.key}');
      }
    }

    return ReflectionStats(
      totalReflections: statsModel.totalReflections,
      totalTimeSpentSeconds: statsModel.totalTimeSpentSeconds,
      reflectionsByMode: reflectionsByMode,
      mostCommonLifeAreas: statsModel.mostCommonLifeAreas,
    );
  }
}
