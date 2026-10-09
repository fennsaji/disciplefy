import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/exceptions.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/repositories/learning_paths_repository_impl.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'learning_paths_reset_failure_test.mocks.dart';

void main() {
  late MockLearningPathsRemoteDataSource remoteDataSource;
  late LearningPathsRepositoryImpl repository;

  final enrolment = EnrollmentResultModel(
    id: 'prog-1',
    learningPathId: 'path-1',
    enrolledAt: DateTime.utc(2026, 10, 7),
    startedAt: DateTime.utc(2026, 10, 7),
  );

  setUp(() {
    remoteDataSource = MockLearningPathsRemoteDataSource();
    repository =
        LearningPathsRepositoryImpl(remoteDataSource: remoteDataSource);
  });

  group('enrollInPathBySlug', () {
    test('enrols by slug and returns the resolved learningPathId', () async {
      when(remoteDataSource.enrollInPath(slug: 'rooted-in-christ'))
          .thenAnswer((_) async => enrolment);

      final result = await repository.enrollInPathBySlug('rooted-in-christ');

      expect(result, Right<Failure, EnrollmentResult>(enrolment));
      expect(result.getOrElse(() => throw StateError('left')).learningPathId,
          'path-1');
      verify(remoteDataSource.enrollInPath(slug: 'rooted-in-christ')).called(1);
    });

    test('maps AccountRequiredException to AccountRequiredFailure with reason',
        () async {
      when(remoteDataSource.enrollInPath(slug: 'faith-and-reason')).thenThrow(
        const AccountRequiredException(
          message: 'Create an account to start another path.',
          reason: 'second_path',
        ),
      );

      final result = await repository.enrollInPathBySlug('faith-and-reason');

      expect(
        result,
        const Left<Failure, EnrollmentResult>(AccountRequiredFailure(
          message: 'Create an account to start another path.',
          reason: 'second_path',
        )),
      );
    });

    test('maps a ServerException to ServerFailure', () async {
      when(remoteDataSource.enrollInPath(slug: 'x')).thenThrow(
          const ServerException(message: 'boom', code: 'ENROLLMENT_API_ERROR'));

      final result = await repository.enrollInPathBySlug('x');

      expect(result.fold((f) => f, (_) => null), isA<ServerFailure>());
    });
  });

  group('enrollInPath', () {
    test('still enrols by pathId', () async {
      when(remoteDataSource.enrollInPath(pathId: 'path-1'))
          .thenAnswer((_) async => enrolment);

      final result = await repository.enrollInPath(pathId: 'path-1');

      expect(result, Right<Failure, EnrollmentResult>(enrolment));
    });

    test('maps AccountRequiredException to AccountRequiredFailure', () async {
      when(remoteDataSource.enrollInPath(pathId: 'path-2'))
          .thenThrow(const AccountRequiredException(reason: 'second_path'));

      final result = await repository.enrollInPath(pathId: 'path-2');

      expect(
        result.fold((f) => f, (_) => null),
        isA<AccountRequiredFailure>()
            .having((f) => f.reason, 'reason', 'second_path'),
      );
    });
  });
}
