import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/services/lesson_completion_refresh.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';

class MockGamificationBloc extends Mock implements GamificationBloc {}

class MockLearningPathsRepository extends Mock
    implements LearningPathsRepository {}

void main() {
  late MockGamificationBloc mockGamificationBloc;
  late MockLearningPathsRepository mockLearningPaths;

  setUpAll(() {
    registerFallbackValue(const RefreshGamificationStats());
  });

  setUp(() {
    mockGamificationBloc = MockGamificationBloc();
    mockLearningPaths = MockLearningPathsRepository();
  });

  test('a recorded lesson completion refreshes the XP and streak stats once',
      () {
    refreshAfterLessonCompletion(
      learningPaths: mockLearningPaths,
      gamification: mockGamificationBloc,
    );

    verify(() => mockGamificationBloc
        .add(any(that: isA<RefreshGamificationStats>()))).called(1);
  });

  test('a recorded lesson completion drops the cached path progress', () {
    refreshAfterLessonCompletion(
      learningPaths: mockLearningPaths,
      gamification: mockGamificationBloc,
    );

    verify(() => mockLearningPaths.clearCache()).called(1);
  });
}
