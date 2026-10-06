import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/lesson_complete_page.dart';

import '../../../../helpers/welcome_test_harness.dart';

class _MockRepo extends Mock implements LearningPathsRepository {}

class _FakePrefs extends Fake implements LanguagePreferenceService {
  @override
  String? getLearningPathStudyModePreferenceRaw() => 'recommended';
}

LearningPathTopic _topic(int pos, String title) => LearningPathTopic(
      position: pos,
      isMilestone: false,
      topicId: 't$pos',
      title: title,
      description: '',
      category: 'c',
      xpValue: 50,
    );

final _titles = [
  'Who is Jesus Christ?',
  'One God, Three Persons',
  'Why Read the Bible?',
  'Prayer',
  'T5',
  'T6',
  'T7',
  'T8',
];

LearningPathDetail _path() => LearningPathDetail(
      id: 'p',
      slug: 's',
      title: 'NBE',
      description: '',
      iconName: '',
      color: '',
      totalXp: 0,
      estimatedDays: 0,
      discipleLevel: 'seeker',
      topicsCount: 8,
      topics: [for (var i = 0; i < 8; i++) _topic(i + 1, _titles[i])],
    );

void main() {
  late _MockRepo repo;
  late GoRouter router;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getLearningPathDetails(
          pathId: any(named: 'pathId'),
          language: any(named: 'language'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => Right(_path()));
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    sl.registerSingleton<LearningPathsRepository>(repo);
    sl.registerSingleton<LanguagePreferenceService>(_FakePrefs());
  });
  tearDown(() => sl.reset());

  Future<void> pumpPage(WidgetTester tester, int n, {ThemeData? theme}) async {
    useSurface(tester, const Size(400, 800));
    router = GoRouter(
      initialLocation: '/lesson-complete',
      routes: [
        GoRoute(
          path: '/lesson-complete',
          builder: (_, __) => LessonCompletePage(
            args: LessonCompleteArgs(
              lesson: LessonRef(
                  pathId: 'p',
                  pathTitle: 'NBE',
                  lessonNumber: n,
                  lessonTotal: 8),
              lessonTitle: _titles[n - 1],
              mode: StudyMode.quick,
              language: 'en',
            ),
          ),
        ),
        GoRoute(
            path: '/study-guide-v2', builder: (_, __) => const Text('guide')),
        GoRoute(path: '/', builder: (_, __) => const Text('home')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      theme: theme ?? AppTheme.darkTheme,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
  }

  Map<String, String> opened() =>
      router.routeInformationProvider.value.uri.queryParameters;

  testWidgets('shows next lesson, Continue opens it immediately (no day gate)',
      (tester) async {
    await pumpPage(tester, 1);
    expect(find.text('Lesson 1 complete'), findsOneWidget);
    expect(find.text('Up next'.toUpperCase()), findsOneWidget);
    expect(find.text('Tomorrow'), findsNothing);
    expect(find.text('Continue to lesson 2'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
    await tester.tap(find.text('Continue to lesson 2'));
    await tester.pumpAndSettle();
    expect(opened()['lesson_number'], '2');
    expect(opened()['mode'], 'standard');
  });

  testWidgets('next-lesson row is tappable', (tester) async {
    await pumpPage(tester, 1);
    await tester.tap(find.text('One God, Three Persons'));
    await tester.pumpAndSettle();
    expect(opened()['lesson_number'], '2');
  });

  testWidgets('Back to Home goes home', (tester) async {
    await pumpPage(tester, 1);
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('last lesson: finished title, only Back to Home', (tester) async {
    await pumpPage(tester, 8);
    expect(find.text('You finished NBE'), findsOneWidget);
    expect(find.textContaining('Continue to lesson'), findsNothing);
    expect(find.text('Back to Home'), findsOneWidget);
  });

  testWidgets('primary fill is white on dark and gold on light',
      (tester) async {
    Color? fill() => tester
        .widget<FilledButton>(find.byType(FilledButton))
        .style!
        .backgroundColor!
        .resolve({});
    await pumpPage(tester, 1);
    expect(fill(), Colors.white);
    await pumpPage(tester, 1, theme: AppTheme.lightTheme);
    expect(fill(), AppColors.brandGoldDeep);
  });
}
