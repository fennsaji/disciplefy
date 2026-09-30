import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/topic_progress.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/topic_progress_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/usecases/reset_learning_progress.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/continue_learning_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/continue_learning_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/continue_learning_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements LearningPathsRepository {}

class _MockProgressRepository extends Mock implements TopicProgressRepository {}

LearningPathCategoriesResult _listing(String id, int progress) =>
    LearningPathCategoriesResult(
      categories: [
        LearningPathCategory(
          name: 'Foundations',
          paths: [
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
              topicsCount: 8,
              isEnrolled: progress > 0,
              progressPercentage: progress,
            ),
          ],
          totalInCategory: 1,
        ),
      ],
    );

Matcher _loaded(String id, int progress) => isA<LearningPathsLoaded>()
    .having((s) => s.categories.single.paths.single.id, 'id', id)
    .having((s) => s.categories.single.paths.single.progressPercentage,
        'progress', progress);

InProgressTopic _topic(String id) => InProgressTopic(
      topicId: id,
      title: id,
      description: '',
      category: '',
      startedAt: DateTime(2026, 9),
    );

void main() {
  group('LearningPathsBloc listing', () {
    late _MockRepository repository;

    setUp(() {
      repository = _MockRepository();
      when(() => repository.getCachedLearningPathCategories(
          language: any(named: 'language'))).thenAnswer((_) async => null);
    });

    LearningPathsBloc build() => LearningPathsBloc(
          repository: repository,
          resetLearningProgress: ResetLearningProgress(repository),
        );

    void stubFresh(String language, LearningPathCategoriesResult result) =>
        when(() => repository.getLearningPathCategories(
              language: language,
              includeEnrolled: any(named: 'includeEnrolled'),
              forceRefresh: any(named: 'forceRefresh'),
            )).thenAnswer((_) async => Right(result));

    blocTest<LearningPathsBloc, LearningPathsState>(
      'cold start shows the cached listing at once, then the fresh one',
      build: () {
        when(() => repository.getCachedLearningPathCategories())
            .thenAnswer((_) async => _listing('p1', 25));
        stubFresh('en', _listing('p1', 50));
        return build();
      },
      act: (bloc) => bloc.add(const LoadLearningPaths(forceRefresh: true)),
      expect: () => [_loaded('p1', 25), _loaded('p1', 50)],
    );

    blocTest<LearningPathsBloc, LearningPathsState>(
      'without a cache the loading state is shown as before',
      build: () {
        stubFresh('en', _listing('p1', 50));
        return build();
      },
      act: (bloc) => bloc.add(const LoadLearningPaths(forceRefresh: true)),
      expect: () => [isA<LearningPathsLoading>(), _loaded('p1', 50)],
    );

    blocTest<LearningPathsBloc, LearningPathsState>(
      'a forced refresh keeps the listing on screen (no spinner) and swaps '
      'in the new progress',
      build: () {
        stubFresh('en', _listing('p1', 25));
        return build();
      },
      act: (bloc) async {
        bloc.add(const LoadLearningPaths(forceRefresh: true));
        await Future<void>.delayed(Duration.zero);
        stubFresh('en', _listing('p1', 75));
        bloc.add(const LoadLearningPaths(forceRefresh: true));
      },
      expect: () => [
        isA<LearningPathsLoading>(),
        _loaded('p1', 25),
        _loaded('p1', 75),
      ],
    );

    blocTest<LearningPathsBloc, LearningPathsState>(
      'a failed background refresh keeps the listing',
      build: () {
        stubFresh('en', _listing('p1', 25));
        return build();
      },
      act: (bloc) async {
        bloc.add(const LoadLearningPaths(forceRefresh: true));
        await Future<void>.delayed(Duration.zero);
        when(() => repository.getLearningPathCategories(
                  includeEnrolled: any(named: 'includeEnrolled'),
                  forceRefresh: any(named: 'forceRefresh'),
                ))
            .thenAnswer(
                (_) async => const Left(ServerFailure(message: 'down')));
        bloc.add(const LoadLearningPaths(forceRefresh: true));
      },
      expect: () => [isA<LearningPathsLoading>(), _loaded('p1', 25)],
    );

    blocTest<LearningPathsBloc, LearningPathsState>(
      'a language switch never keeps the listing in the old language',
      build: () {
        stubFresh('en', _listing('en-path', 25));
        stubFresh('hi', _listing('hi-path', 25));
        return build();
      },
      act: (bloc) async {
        bloc.add(const LoadLearningPaths(forceRefresh: true));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const RefreshLearningPaths(language: 'hi'));
      },
      expect: () => [
        isA<LearningPathsLoading>(),
        _loaded('en-path', 25),
        isA<LearningPathsLoading>(),
        _loaded('hi-path', 25),
      ],
    );
  });

  group('ContinueLearningBloc', () {
    late _MockProgressRepository repository;

    setUp(() => repository = _MockProgressRepository());

    void stubTopics(String language, List<InProgressTopic> topics) =>
        when(() => repository.getInProgressTopics(
              language: language,
              limit: any(named: 'limit'),
            )).thenAnswer((_) async => Right(topics));

    blocTest<ContinueLearningBloc, ContinueLearningState>(
      'a forced reload in the same language refreshes without a spinner',
      build: () {
        stubTopics('en', [_topic('t1')]);
        return ContinueLearningBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const LoadContinueLearning());
        await Future<void>.delayed(Duration.zero);
        stubTopics('en', [_topic('t2')]);
        bloc.add(const LoadContinueLearning(forceRefresh: true));
      },
      expect: () => [
        isA<ContinueLearningLoading>(),
        isA<ContinueLearningLoaded>()
            .having((s) => s.topics.single.topicId, 'topic', 't1'),
        isA<ContinueLearningLoaded>()
            .having((s) => s.topics.single.topicId, 'topic', 't2'),
      ],
    );

    blocTest<ContinueLearningBloc, ContinueLearningState>(
      'a language switch shows the loading state, not old-language topics',
      build: () {
        stubTopics('en', [_topic('en-topic')]);
        stubTopics('ml', [_topic('ml-topic')]);
        return ContinueLearningBloc(repository: repository);
      },
      act: (bloc) async {
        bloc.add(const LoadContinueLearning());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const RefreshContinueLearning(language: 'ml'));
      },
      expect: () => [
        isA<ContinueLearningLoading>(),
        isA<ContinueLearningLoaded>(),
        isA<ContinueLearningLoading>(),
        isA<ContinueLearningLoaded>()
            .having((s) => s.topics.single.topicId, 'topic', 'ml-topic'),
      ],
    );
  });
}
