import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
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
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
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

LearningPath _path(String id) => LearningPath(
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
      progressPercentage: 40,
    );

ActivePathSummary _summary(String id) => ActivePathSummary(
      pathId: id,
      title: id,
      description: '',
      discipleLevel: 'seeker',
      lessonTotal: 8,
      lessonsCompleted: 3,
    );

RecommendedPathResult _rec(String id, {bool withSummary = true}) =>
    RecommendedPathResult(
      path: _path(id),
      reason: LearningPathRecommendationReason.active,
      summary: withSummary ? _summary(id) : null,
    );

void main() {
  late _MockLanguageService languageService;
  late _MockRepository repository;
  late _MockDownloadService downloads;
  late StreamController<AppLanguage> appLanguage;
  late StreamController<AppLanguage> contentLanguage;
  late HomeBloc bloc;

  setUpAll(() {
    registerFallbackValue(const topics_events.LoadRecommendedTopics());
  });

  setUp(() {
    LearningCacheScope.resolver = () => 'user-a';
    appLanguage = StreamController<AppLanguage>.broadcast();
    contentLanguage = StreamController<AppLanguage>.broadcast();
    languageService = _MockLanguageService();
    when(() => languageService.languageChanges)
        .thenAnswer((_) => appLanguage.stream);
    when(() => languageService.studyContentLanguageChanges)
        .thenAnswer((_) => contentLanguage.stream);
    when(() => languageService.getStudyContentLanguage())
        .thenAnswer((_) async => AppLanguage.english);

    repository = _MockRepository();
    downloads = _MockDownloadService();
    when(() => downloads.cachedDownloads).thenReturn(const []);
    when(() => repository.getCachedRecommendedPath())
        .thenAnswer((_) async => null);

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

  void stubFresh(RecommendedPathResult result) => when(() => repository
          .getRecommendedPath(forceRefresh: any(named: 'forceRefresh')))
      .thenAnswer((_) async => Right(result));

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> load() async {
    bloc.add(const LoadActiveLearningPath());
    await settle();
  }

  HomeCombinedState combined() => bloc.state as HomeCombinedState;

  test('fresh recommended result sets the summary', () async {
    stubFresh(_rec('p1'));
    await load();
    expect(combined().activePathSummary, _summary('p1'));
  });

  test('cached result shows its summary on first paint', () async {
    when(() => repository.getCachedRecommendedPath())
        .thenAnswer((_) async => _rec('p1'));
    final fresh = Completer<Either<Failure, RecommendedPathResult>>();
    when(() => repository.getRecommendedPath(
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) => fresh.future);

    bloc.add(const LoadActiveLearningPath());
    await settle();
    expect(combined().isLoadingActivePath, isTrue);
    expect(combined().activePathSummary, _summary('p1'));
    fresh.complete(Right(_rec('p1')));
    await settle();
  });

  test('a result without a summary clears the previous one', () async {
    stubFresh(_rec('p1'));
    await load();
    stubFresh(_rec('p1', withSummary: false));
    await load();
    expect(combined().activePathSummary, isNull);
    expect(combined().activeLearningPath?.id, 'p1');
  });

  test('offline fallback path (nothing shown yet) has no summary', () async {
    when(() => repository.getRecommendedPath(
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    when(() => downloads.cachedDownloads).thenReturn([
      LearningPathDownloadModel(
        learningPathId: 'off',
        learningPathTitle: 'off',
        language: 'en',
        topics: const [
          LearningPathTopicDownload(
            topicId: 't',
            topicTitle: 't',
            inputType: 'topic',
            description: '',
            studyMode: 'standard',
            status: TopicDownloadStatus.done,
          ),
        ],
        status: PathDownloadStatus.completed,
        queuedAt: DateTime(2026),
        completedCount: 1,
        totalCount: 1,
      ),
    ]);
    when(() => repository.getLearningPathCategories())
        .thenAnswer((_) async => Right(LearningPathCategoriesResult(
              categories: [
                LearningPathCategory(name: 'c', paths: [_path('off')]),
              ],
            )));

    await load();
    expect(combined().activeLearningPath?.id, 'off');
    expect(combined().learningPathReason,
        LearningPathRecommendationReason.offlineAvailable);
    expect(combined().activePathSummary, isNull);
  });

  test('failure with nothing shown and nothing offline shows no path',
      () async {
    when(() => repository.getRecommendedPath(
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    await load();
    expect(combined().activeLearningPath, isNull);
    expect(combined().activePathSummary, isNull);
    expect(combined().isLoadingActivePath, isFalse);
  });

  test('a failed refresh keeps the enrolled path and summary on screen',
      () async {
    stubFresh(_rec('p1'));
    await load();
    when(() => repository.getRecommendedPath(
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    await load();
    expect(combined().activeLearningPath?.id, 'p1');
    expect(combined().activePathSummary, _summary('p1'));
    expect(
        combined().learningPathReason, LearningPathRecommendationReason.active);
    expect(combined().isLoadingActivePath, isFalse);
  });

  test('a failed cold start keeps the persisted path and summary', () async {
    when(() => repository.getCachedRecommendedPath())
        .thenAnswer((_) async => _rec('p1'));
    when(() => repository.getRecommendedPath(
            forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    await load();
    expect(combined().activeLearningPath?.id, 'p1');
    expect(combined().activePathSummary, _summary('p1'));
    expect(combined().isLoadingActivePath, isFalse);
  });

  test('summary survives the generated-guide state rebuild', () async {
    stubFresh(_rec('p1'));
    await load();
    bloc.add(StudyGenerationStateChangedEvent(HomeStudyGenerationSuccess(
      studyGuide: StudyGuide(
        id: 'g',
        input: 'John 3:16',
        inputType: 'scripture',
        summary: '',
        interpretation: '',
        context: '',
        relatedVerses: const [],
        reflectionQuestions: const [],
        prayerPoints: const [],
        language: 'en',
        createdAt: DateTime(2026),
      ),
    )));
    await settle();
    expect(bloc.state, isA<HomeStudyGuideGeneratedCombined>());
    expect(combined().activePathSummary, _summary('p1'));
  });

  test('copyWith clearActiveLearningPath also clears the summary', () {
    final s = HomeCombinedState(
      activeLearningPath: _path('p1'),
      activePathSummary: _summary('p1'),
    );
    expect(s.copyWith(clearActiveLearningPath: true).activePathSummary, isNull);
    expect(s.copyWith(isLoadingTopics: true).activePathSummary, _summary('p1'));
  });
}
