import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/usecases/reset_learning_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'reset_learning_progress_test.mocks.dart';

@GenerateMocks([LearningPathsRepository])
void main() {
  late MockLearningPathsRepository repository;
  late ResetLearningProgress useCase;

  setUp(() {
    repository = MockLearningPathsRepository();
    useCase = ResetLearningProgress(repository);
  });

  const result = ResetProgressResult(
    scope: 'learning_paths',
    counts: {'paths_reset': 3, 'topics_reset': 27},
  );

  test('returns the repository result on success', () async {
    when(repository.resetLearningProgress())
        .thenAnswer((_) async => const Right(result));

    final actual = await useCase();

    expect(actual, const Right<Failure, ResetProgressResult>(result));
    verify(repository.resetLearningProgress()).called(1);
  });

  test('propagates the failure on error', () async {
    const failure = ServerFailure(message: 'boom');
    when(repository.resetLearningProgress())
        .thenAnswer((_) async => const Left(failure));

    final actual = await useCase();

    expect(actual, const Left<Failure, ResetProgressResult>(failure));
  });
}
