import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/usecases/reset_learning_progress.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'learning_paths_reset_test.mocks.dart';

@GenerateMocks([LearningPathsRepository])
void main() {
  late MockLearningPathsRepository repository;

  setUp(() {
    repository = MockLearningPathsRepository();
  });

  const resetResult = ResetProgressResult(
    scope: 'learning_paths',
    counts: {'paths_reset': 3, 'topics_reset': 27},
  );

  LearningPathsBloc buildBloc() => LearningPathsBloc(
        repository: repository,
        resetLearningProgress: ResetLearningProgress(repository),
      );

  blocTest<LearningPathsBloc, LearningPathsState>(
    'emits [Resetting, ResetSuccess] when the reset succeeds',
    build: () {
      when(repository.resetLearningProgress())
          .thenAnswer((_) async => const Right(resetResult));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ResetLearningProgressRequested()),
    expect: () => [
      const LearningPathsResetting(),
      const LearningPathsResetSuccess(result: resetResult),
    ],
    verify: (_) {
      verify(repository.resetLearningProgress()).called(1);
    },
  );

  blocTest<LearningPathsBloc, LearningPathsState>(
    'emits [Resetting, ResetError] — NOT the shared LearningPathsError — '
    'when the reset fails',
    build: () {
      when(repository.resetLearningProgress()).thenAnswer(
        (_) async => const Left(
          RateLimitFailure(message: 'Slow down', code: 'RATE_LIMIT_EXCEEDED'),
        ),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ResetLearningProgressRequested()),
    // LearningPathsError is the same state every LoadLearningPaths /
    // RefreshLearningPaths failure emits, and LearningPathsSection /
    // ForYouLearningPathsSection render it as a full-width error panel (or
    // collapse to nothing) — wrong for a failed *reset*, where nothing
    // changed server-side. A dedicated LearningPathsResetError state (mirrors
    // MemoryProgressResetError) keeps a failed reset from destroying the
    // on-screen list.
    expect: () => [
      const LearningPathsResetting(),
      isA<LearningPathsResetError>()
          .having((s) => s.message, 'message', 'Slow down')
          .having((s) => s.code, 'code', 'RATE_LIMIT_EXCEEDED'),
    ],
    verify: (bloc) {
      expect(bloc.state, isNot(isA<LearningPathsError>()));
    },
  );
}
