import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/repositories/memory_verse_repository.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/reset_memory_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'reset_memory_progress_test.mocks.dart';

@GenerateMocks([MemoryVerseRepository])
void main() {
  late MockMemoryVerseRepository repository;
  late ResetMemoryProgress useCase;

  setUp(() {
    repository = MockMemoryVerseRepository();
    useCase = ResetMemoryProgress(repository);
  });

  const result = ResetProgressResult(
    scope: 'memory_verses',
    counts: {'verses_deleted': 42},
  );

  test('returns the repository result on success', () async {
    when(repository.resetMemoryProgress())
        .thenAnswer((_) async => const Right(result));

    final actual = await useCase();

    expect(actual, const Right<Failure, ResetProgressResult>(result));
    verify(repository.resetMemoryProgress()).called(1);
  });

  test('propagates the failure on error', () async {
    const failure = NetworkFailure(message: 'offline');
    when(repository.resetMemoryProgress())
        .thenAnswer((_) async => const Left(failure));

    final actual = await useCase();

    expect(actual, const Left<Failure, ResetProgressResult>(failure));
  });
}
