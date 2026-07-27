import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/exceptions.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/datasources/learning_paths_remote_datasource.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/repositories/learning_paths_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'learning_paths_reset_failure_test.mocks.dart';

@GenerateMocks([LearningPathsRemoteDataSource])
void main() {
  late MockLearningPathsRemoteDataSource remoteDataSource;
  late LearningPathsRepositoryImpl repository;

  setUp(() {
    remoteDataSource = MockLearningPathsRemoteDataSource();
    repository =
        LearningPathsRepositoryImpl(remoteDataSource: remoteDataSource);
  });

  group('resetLearningProgress', () {
    test('returns Right(ResetProgressResult) on success', () async {
      const result = ResetProgressResult(
        scope: 'learning_paths',
        counts: {'paths_reset': 3, 'topics_reset': 27},
      );
      when(remoteDataSource.resetLearningProgress())
          .thenAnswer((_) async => result);

      final actual = await repository.resetLearningProgress();

      expect(actual, const Right<Failure, ResetProgressResult>(result));
    });

    test('returns Left(RateLimitFailure) when RateLimitException is thrown',
        () async {
      when(remoteDataSource.resetLearningProgress()).thenThrow(
        const RateLimitException(
          message: 'You have reached the reset limit.',
          code: 'RATE_LIMIT_EXCEEDED',
        ),
      );

      final actual = await repository.resetLearningProgress();

      expect(actual.isLeft(), isTrue);
      actual.fold(
        (failure) => expect(failure, isA<RateLimitFailure>()),
        (_) => fail('expected a Left(RateLimitFailure)'),
      );
    });

    test(
        'returns Left(AuthenticationFailure) when AuthenticationException is thrown',
        () async {
      when(remoteDataSource.resetLearningProgress()).thenThrow(
        const AuthenticationException(
          message: 'Authentication required.',
          code: 'UNAUTHORIZED',
        ),
      );

      final actual = await repository.resetLearningProgress();

      expect(actual.isLeft(), isTrue);
      actual.fold(
        (failure) => expect(failure, isA<AuthenticationFailure>()),
        (_) => fail('expected a Left(AuthenticationFailure)'),
      );
    });

    test('returns Left(NetworkFailure) when NetworkException is thrown',
        () async {
      when(remoteDataSource.resetLearningProgress()).thenThrow(
        const NetworkException(
          message: 'Offline.',
          code: 'NETWORK_ERROR',
        ),
      );

      final actual = await repository.resetLearningProgress();

      expect(actual.isLeft(), isTrue);
      actual.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected a Left(NetworkFailure)'),
      );
    });

    test(
        'returns Left(ServerFailure) when an unrecognised non-AppException error is thrown',
        () async {
      when(remoteDataSource.resetLearningProgress())
          .thenThrow(FormatException('unexpected'));

      final actual = await repository.resetLearningProgress();

      expect(actual.isLeft(), isTrue);
      actual.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected a Left(ServerFailure)'),
      );
    });
  });
}
