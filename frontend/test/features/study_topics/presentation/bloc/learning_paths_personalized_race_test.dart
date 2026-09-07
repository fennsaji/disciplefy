import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/usecases/reset_learning_progress.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'learning_paths_personalized_race_test.mocks.dart';

LearningPath _path(String id, {bool featured = false, int progress = 0}) =>
    LearningPath(
      id: id,
      slug: id,
      title: id,
      description: '',
      iconName: 'star',
      color: '#000000',
      totalXp: 100,
      estimatedDays: 7,
      discipleLevel: 'seeker',
      isFeatured: featured,
      topicsCount: 8,
      isEnrolled: progress > 0,
      progressPercentage: progress,
    );

final _categories = LearningPathCategoriesResult(
  categories: [
    LearningPathCategory(
      name: 'Foundations',
      paths: [_path('completed-featured', featured: true, progress: 100)],
      totalInCategory: 1,
    ),
  ],
);

final _personalized = [_path('personalized-1')];

@GenerateMocks([LearningPathsRepository])
void main() {
  late MockLearningPathsRepository repository;

  setUp(() {
    repository = MockLearningPathsRepository();
  });

  LearningPathsBloc buildBloc() => LearningPathsBloc(
        repository: repository,
        resetLearningProgress: ResetLearningProgress(repository),
      );

  blocTest<LearningPathsBloc, LearningPathsState>(
    'personalized paths that arrive before the listing are not dropped',
    build: () {
      // The listing is the heavier call, so it finishes last — the ordering
      // the Topics tab actually hits on first open.
      when(repository.getLearningPathCategories(
        language: anyNamed('language'),
        includeEnrolled: anyNamed('includeEnrolled'),
        forceRefresh: anyNamed('forceRefresh'),
      )).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return Right(_categories);
      });
      when(repository.getPersonalizedPaths(
        language: anyNamed('language'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => Right(_personalized));
      return buildBloc();
    },
    act: (bloc) {
      bloc.add(const LoadLearningPaths(language: 'ml', forceRefresh: true));
      bloc.add(const LoadPersonalizedPaths(language: 'ml'));
    },
    wait: const Duration(milliseconds: 100),
    verify: (bloc) {
      final state = bloc.state as LearningPathsLoaded;
      expect(state.personalizedPaths, _personalized,
          reason: 'a personalized result that lands during the initial load '
              'must survive into the loaded state');
    },
  );

  blocTest<LearningPathsBloc, LearningPathsState>(
    'personalized paths for another language are not reused',
    build: () {
      when(repository.getLearningPathCategories(
        language: anyNamed('language'),
        includeEnrolled: anyNamed('includeEnrolled'),
        forceRefresh: anyNamed('forceRefresh'),
      )).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return Right(_categories);
      });
      when(repository.getPersonalizedPaths(
        language: anyNamed('language'),
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => Right(_personalized));
      return buildBloc();
    },
    act: (bloc) {
      bloc.add(const LoadPersonalizedPaths(language: 'hi'));
      bloc.add(const LoadLearningPaths(language: 'ml', forceRefresh: true));
    },
    wait: const Duration(milliseconds: 100),
    verify: (bloc) {
      final state = bloc.state as LearningPathsLoaded;
      expect(state.personalizedPaths, isEmpty,
          reason:
              'Hindi personalization must not leak into a Malayalam listing');
    },
  );
}
