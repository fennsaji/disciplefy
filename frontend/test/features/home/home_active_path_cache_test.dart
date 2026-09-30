import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_event.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_state.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_study_generation_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_study_generation_event.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_study_generation_state.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/recommended_topics_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/recommended_topics_event.dart'
    as topics_events;
import 'package:disciplefy_bible_study/features/home/presentation/bloc/recommended_topics_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_cache_scope.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTopicsBloc extends MockBloc<topics_events.RecommendedTopicsEvent,
    RecommendedTopicsState> implements RecommendedTopicsBloc {}

class _MockGenerationBloc
    extends MockBloc<HomeStudyGenerationEvent, HomeStudyGenerationState>
    implements HomeStudyGenerationBloc {}

class _MockLanguageService extends Mock implements LanguagePreferenceService {}

class _MockRepository extends Mock implements LearningPathsRepository {}

class _MockDownloadService extends Mock
    implements LearningPathDownloadService {}

LearningPath _path(String id, int progress) => LearningPath(
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
      isEnrolled: true,
      progressPercentage: progress,
    );

RecommendedPathResult _rec(String id, int progress) => RecommendedPathResult(
      path: _path(id, progress),
      reason: LearningPathRecommendationReason.active,
    );

void main() {
  late _MockLanguageService languageService;
  late _MockRepository repository;
  late StreamController<AppLanguage> appLanguage;
  late StreamController<AppLanguage> contentLanguage;
  late HomeBloc bloc;
  var contentCode = AppLanguage.english;
  var user = 'user-a';

  setUpAll(() {
    registerFallbackValue(const topics_events.LoadForYouTopics());
  });

  setUp(() {
    user = 'user-a';
    contentCode = AppLanguage.english;
    LearningCacheScope.resolver = () => user;
    appLanguage = StreamController<AppLanguage>.broadcast();
    contentLanguage = StreamController<AppLanguage>.broadcast();
    languageService = _MockLanguageService();
    when(() => languageService.languageChanges)
        .thenAnswer((_) => appLanguage.stream);
    when(() => languageService.studyContentLanguageChanges)
        .thenAnswer((_) => contentLanguage.stream);
    when(() => languageService.getStudyContentLanguage())
        .thenAnswer((_) async => contentCode);

    repository = _MockRepository();
    final downloads = _MockDownloadService();
    when(() => downloads.cachedDownloads).thenReturn(const []);

    bloc = HomeBloc(
      topicsBloc: _MockTopicsBloc(),
      studyGenerationBloc: _MockGenerationBloc(),
      languagePreferenceService: languageService,
      learningPathsRepository: repository,
      downloadService: downloads,
    );
  });

  tearDown(() async {
    LearningCacheScope.resolver = null;
    await bloc.close();
    await appLanguage.close();
    await contentLanguage.close();
  });

  void stubCached(String language, RecommendedPathResult? result) =>
      when(() => repository.getCachedRecommendedPath(language: language))
          .thenAnswer((_) async => result);

  void stubFresh(String language, RecommendedPathResult result) =>
      when(() => repository.getRecommendedPath(
              language: language, forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => Right(result));

  Matcher pathState(String? id, int? progress, {required bool loading}) =>
      isA<HomeCombinedState>()
          .having((s) => s.activeLearningPath?.id, 'path id', id)
          .having((s) => s.activeLearningPath?.progressPercentage, 'progress',
              progress)
          .having((s) => s.isLoadingActivePath, 'loading', loading);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('cold start shows the persisted path at once, then the fresh progress',
      () async {
    stubCached('en', _rec('p1', 40));
    stubFresh('en', _rec('p1', 60));

    final states = <HomeState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const LoadActiveLearningPath());
    await settle();
    await settle();
    await sub.cancel();

    expect(states, [
      pathState('p1', 40, loading: true),
      pathState('p1', 60, loading: false),
    ]);
    // Always a fresh fetch, even though the event did not ask for one.
    verify(() => repository.getRecommendedPath(forceRefresh: true)).called(1);
  });

  test('a path already shown for this user and language stays on screen',
      () async {
    stubCached('en', null);
    stubFresh('en', _rec('p1', 40));
    bloc.add(const LoadActiveLearningPath());
    await settle();
    await settle();

    stubFresh('en', _rec('p1', 80));
    final states = <HomeState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const LoadActiveLearningPath(forceRefresh: true));
    await settle();
    await settle();
    await sub.cancel();

    expect(states, [
      pathState('p1', 40, loading: true),
      pathState('p1', 80, loading: false),
    ]);
  });

  test('another account never sees the previous user\'s path', () async {
    stubCached('en', null);
    stubFresh('en', _rec('a-path', 40));
    bloc.add(const LoadActiveLearningPath());
    await settle();
    await settle();

    user = 'user-b';
    stubFresh('en', _rec('b-path', 10));
    final states = <HomeState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const LoadActiveLearningPath());
    await settle();
    await settle();
    await sub.cancel();

    expect(states, [
      pathState(null, null, loading: true),
      pathState('b-path', 10, loading: false),
    ]);
  });

  test('a content-language switch never keeps the old-language path', () async {
    stubCached('en', null);
    stubFresh('en', _rec('p1', 40));
    bloc.add(const LoadActiveLearningPath());
    await settle();
    await settle();

    contentCode = AppLanguage.hindi;
    stubCached('hi', _rec('p1', 40));
    stubFresh('hi', _rec('p1', 45));
    final states = <HomeState>[];
    final sub = bloc.stream.listen(states.add);
    // Both streams fire for one change; the path reloads once.
    appLanguage.add(AppLanguage.hindi);
    contentLanguage.add(AppLanguage.hindi);
    for (var i = 0; i < 6; i++) {
      await settle();
    }
    await sub.cancel();

    final pathStates = states.whereType<HomeCombinedState>().toList();
    expect(pathStates.first, pathState('p1', 40, loading: true));
    expect(pathStates.last, pathState('p1', 45, loading: false));
    verify(() =>
            repository.getRecommendedPath(language: 'hi', forceRefresh: true))
        .called(1);
  });
}
