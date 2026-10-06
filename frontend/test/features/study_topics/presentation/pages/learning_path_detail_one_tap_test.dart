import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/learning_path_detail_page.dart';

import '../../../../helpers/welcome_test_harness.dart';
import '../../../settings/text_fit.dart';

class _MockPathsBloc extends MockBloc<LearningPathsEvent, LearningPathsState>
    implements LearningPathsBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _FakeDownloads extends Fake implements LearningPathDownloadService {
  @override
  Stream<LearningPathDownloadModel> watchDownload(String learningPathId) =>
      const Stream.empty();

  @override
  LearningPathDownloadModel? getDownload(String learningPathId) => null;
}

class _FakeAuth extends Fake implements AuthStateProvider {}

class _FakePrefs extends Fake implements LanguagePreferenceService {
  @override
  Future<AppLanguage> getStudyContentLanguage() async => AppLanguage.english;

  @override
  String? getLearningPathStudyModePreferenceRaw() => 'recommended';
}

LearningPathTopic _topic(int pos) => LearningPathTopic(
      position: pos,
      isMilestone: false,
      topicId: 't$pos',
      title: 'Topic $pos',
      description: '',
      category: 'c',
      xpValue: 50,
    );

void main() {
  late FakeTranslationService translations;
  late _MockPathsBloc bloc;
  late _MockConnectivityBloc connectivity;
  late StreamController<LearningPathsState> states;

  setUpAll(() {
    registerFallbackValue(const EnrollInLearningPath(pathId: 'x'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<LearningPathDownloadService>(_FakeDownloads());
    sl.registerSingleton<LanguagePreferenceService>(_FakePrefs());
    sl.registerSingleton<AuthStateProvider>(_FakeAuth());
    bloc = _MockPathsBloc();
    connectivity = _MockConnectivityBloc();
    when(() => connectivity.state).thenReturn(ConnectivityOnline());
    states = StreamController<LearningPathsState>.broadcast();
  });
  tearDown(() async {
    await states.close();
    await sl.reset();
  });

  testWidgets('one tap on Start enrols and opens lesson 1', (tester) async {
    useSurface(tester, const Size(400, 900));
    final path = LearningPathDetail(
      id: 'path-1',
      slug: 's',
      title: 'Path One',
      description: '',
      iconName: '',
      color: '',
      totalXp: 0,
      estimatedDays: 0,
      discipleLevel: 'seeker',
      topicsCount: 2,
      topics: [_topic(1), _topic(2)],
    );
    final loaded = LearningPathDetailLoaded(pathDetail: path);
    whenListen(bloc, states.stream, initialState: loaded);
    when(() => bloc.state).thenReturn(loaded);

    Uri? opened;
    final router = GoRouter(
      initialLocation: '/learning-path/path-1',
      routes: [
        GoRoute(
          path: '/learning-path/:pathId',
          builder: (_, s) =>
              LearningPathDetailPage(pathId: s.pathParameters['pathId']!),
        ),
        GoRoute(
          path: '/study-guide-v2',
          builder: (_, s) {
            opened = s.uri;
            return const Text('guide');
          },
        ),
      ],
    );
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<LearningPathsBloc>.value(value: bloc),
        BlocProvider<ConnectivityBloc>.value(value: connectivity),
      ],
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    final label = translations
        .getTranslation(TranslationKeys.learningPathsStartLesson, {'n': 1});
    await tester.tap(find.text(label));
    await tester.pump();
    verify(() => bloc.add(const EnrollInLearningPath(pathId: 'path-1')))
        .called(1);

    states.add(const LearningPathEnrolling(pathId: 'path-1'));
    await tester.pump();
    states.add(LearningPathEnrolled(
      enrollment: EnrollmentResult(
        id: 'e',
        learningPathId: 'path-1',
        enrolledAt: DateTime(2026),
        startedAt: DateTime(2026),
      ),
    ));
    // The page shows a spinner until the guide route covers it.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(opened?.path, '/study-guide-v2');
    expect(opened?.queryParameters['lesson_number'], '1');
    expect(find.text('guide'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // No second enrol request from the navigation helper.
    verifyNever(() => bloc.add(const EnrollInLearningPath(pathId: 'path-1')));
  });
}
