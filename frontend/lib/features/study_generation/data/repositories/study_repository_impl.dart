import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/study_guide.dart';
import '../../domain/repositories/study_repository.dart';
import '../../../../core/network/network_info.dart';
import '../datasources/study_remote_data_source.dart';
import '../datasources/study_local_data_source.dart';

/// Implementation of the StudyRepository interface.
///
/// This class coordinates between remote and local data sources
/// following Clean Architecture principles and Single Responsibility Principle.
class StudyRepositoryImpl implements StudyRepository {
  /// Remote data source for API operations.
  final StudyRemoteDataSource _remoteDataSource;

  /// Local data source for cache operations.
  final StudyLocalDataSource _localDataSource;

  /// Network information service.
  final NetworkInfo _networkInfo;

  /// Creates a new StudyRepositoryImpl instance.
  ///
  /// [remoteDataSource] The remote data source for API calls.
  /// [localDataSource] The local data source for caching.
  /// [networkInfo] The network information service.
  StudyRepositoryImpl({
    required StudyRemoteDataSource remoteDataSource,
    required StudyLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, StudyGuide>> generateStudyGuide({
    required String input,
    required String inputType,
    required String language,
  }) async {
    try {
      // Check network connectivity
      if (!await _networkInfo.isConnected) {
        return const Left(NetworkFailure(
          message: 'No internet connection. Please check your network and try again.',
          code: 'NO_CONNECTION',
        ));
      }

      // Use remote data source to generate study guide
      final studyGuide = await _remoteDataSource.generateStudyGuide(
        input: input,
        inputType: inputType,
        language: language,
      );

      // Cache the generated study guide using local data source
      await _localDataSource.cacheStudyGuide(studyGuide);

      return Right(studyGuide);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(
        message: e.message,
        code: e.code,
        context: e.context,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        code: e.code,
        context: e.context,
      ));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(
        message: e.message,
        code: e.code,
        context: e.context,
      ));
    } on RateLimitException catch (e) {
      return Left(RateLimitFailure(
        message: e.message,
        code: e.code,
        context: e.context,
      ));
    } on ClientException catch (e) {
      return Left(ClientFailure(
        message: e.message,
        code: e.code,
        context: e.context,
      ));
    } catch (e) {
      return Left(ClientFailure(
        message: 'We couldn\'t generate a study guide. Please try again later.',
        code: 'GENERATION_FAILED',
        context: {'originalError': e.toString()},
      ));
    }
  }

  @override
  Future<List<StudyGuide>> getCachedStudyGuides() => _localDataSource.getCachedStudyGuides();

  @override
  Future<bool> cacheStudyGuide(StudyGuide studyGuide) => _localDataSource.cacheStudyGuide(studyGuide);

  @override
  Future<bool> clearCache() => _localDataSource.clearCache();
}
