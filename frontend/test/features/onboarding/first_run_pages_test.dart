import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_cubit.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/pages/first_run_language_page.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/pages/growth_goal_page.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/widgets/first_run_choice_row.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';

import '../../helpers/mock_activation_analytics.dart';
import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockPaths extends Mock implements LearningPathsRepository {}

class _MockFlags extends Mock implements RolloutFlags {}

class _FakeWalkthrough extends Fake implements WalkthroughRepository {
  @override
  Future<void> markSeen(WalkthroughScreen screen) async {}
}

/// In-memory `app_settings`: real Hive writes do file I/O that never
/// completes inside a widget test's fake async zone.
class _MemoryBox extends Fake implements Box<dynamic> {
  final Map<dynamic, dynamic> _values = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _values.containsKey(key) ? _values[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _values[key] = value;

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async =>
      _values.addAll(entries);

  @override
  Future<void> delete(dynamic key) async => _values.remove(key);

  @override
  bool containsKey(dynamic key) => _values.containsKey(key);
}

const _titles = {
  'new-believer-essentials': ('New Believer Essentials', 8),
  'sin-repentance-and-grace': ('Sin, Repentance & the Grace of God', 8),
  'growing-in-discipleship': ('Growing in Discipleship', 12),
  'theology-of-suffering': ('The Theology of Suffering', 7),
  'gospel-of-mark': ('The Gospel of Mark', 22),
  'romans-gospel-unfolded': ('Romans: The Gospel Unfolded', 16),
};

LearningPath _listed(String slug) => LearningPath(
      id: slug,
      slug: slug,
      title: _titles[slug]!.$1,
      description: '',
      iconName: '',
      color: '',
      totalXp: 0,
      estimatedDays: 0,
      discipleLevel: '',
      topicsCount: _titles[slug]!.$2,
    );

LearningPathDetail _detail() => LearningPathDetail.forTest(
      id: 'p1',
      title: 'New Believer Essentials',
      description: 'Start here',
      topics: const [
        LearningPathTopic(
          position: 1,
          isMilestone: false,
          topicId: 't1',
          title: 'Who is Jesus Christ?',
          description: '',
          category: 'Foundations',
          xpValue: 10,
        ),
      ],
    );

void main() {
  late _MemoryBox settings;
  late FakeTranslationService translations;
  late FakeLanguagePreferenceService languageService;
  late _MockGuest guest;
  late _MockPaths paths;
  late _MockFlags flags;
  late MockActivationAnalytics analytics;

  setUp(() async {
    analytics = registerMockAnalytics();
    settings = _MemoryBox();
    translations = FakeTranslationService();
    languageService = FakeLanguagePreferenceService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<LanguagePreferenceService>(languageService);

    guest = _MockGuest();
    paths = _MockPaths();
    flags = _MockFlags();
    when(() => flags.guestMode).thenReturn(true);
    when(() => guest.hasSession).thenReturn(false);
    when(() => guest.isGuest).thenReturn(false);
    when(() => guest.startGuest()).thenAnswer((_) async {});
    when(() => paths.getLearningPaths(
          language: any(named: 'language'),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => Right(LearningPathsResult(
          paths: _titles.keys.map(_listed).toList(),
          total: 50,
        )));
    when(() => paths.enrollInPathBySlug(any()))
        .thenAnswer((_) async => Right(EnrollmentResult(
              id: 'e1',
              learningPathId: 'p1',
              enrolledAt: DateTime(2026),
              startedAt: DateTime(2026),
            )));
    when(() => paths.getLearningPathDetails(
          pathId: any(named: 'pathId'),
          language: any(named: 'language'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => Right(_detail()));
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget app({required String initial, bool dark = true}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: AppRoutes.welcome,
          builder: (_, __) => const FirstRunLanguagePage(),
          routes: [
            GoRoute(
              path: 'goal',
              builder: (_, __) => BlocProvider(
                create: (_) => FirstRunCubit(
                  guest: guest,
                  paths: paths,
                  flags: flags,
                  language: languageService,
                  settings: settings,
                  walkthrough: _FakeWalkthrough(),
                ),
                child: const GrowthGoalPage(),
              ),
            ),
          ],
        ),
        for (final stub in [
          AppRoutes.home,
          AppRoutes.login,
          AppRoutes.studyGuideV2,
        ])
          GoRoute(
            path: stub,
            builder: (_, state) => Scaffold(body: Text('stub:${state.uri}')),
          ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  FirstRunChoiceRow row(WidgetTester tester, String key) =>
      tester.widget<FirstRunChoiceRow>(find.byKey(Key(key)));

  group('language page', () {
    for (final dark in [true, false]) {
      testWidgets(
          '${dark ? 'dark' : 'light'}: welcome copy, three scripts, '
          'two log-in links', (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(initial: AppRoutes.welcome, dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('WELCOME'), findsOneWidget);
        expect(find.text("Grow in God's Word every day"), findsOneWidget);
        expect(find.text('A daily verse and a short lesson, in your language.'),
            findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Berean Standard Bible'), findsOneWidget);
        expect(row(tester, 'first_run_language_en').subtitle,
            'Berean Standard Bible');
        expect(find.text('Hindi'), findsOneWidget);
        expect(find.text('Malayalam'), findsOneWidget);
        expect(find.text('हिन्दी'), findsOneWidget);
        expect(find.text('മലയാളം'), findsOneWidget);
        expect(find.byKey(const Key('first_run_log_in_top')), findsOneWidget);
        expect(find.text('Already have an account?'), findsOneWidget);
        expect(row(tester, 'first_run_language_en').isSelected, isTrue);
        expect(
            tester
                .getSize(find.byKey(const Key('first_run_language_en')))
                .height,
            greaterThanOrEqualTo(56));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('picking Malayalam and Continue saves it and opens the goals',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(initial: AppRoutes.welcome));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('first_run_language_ml')));
      await tester.pump();
      expect(row(tester, 'first_run_language_ml').isSelected, isTrue);
      expect(row(tester, 'first_run_language_en').isSelected, isFalse);

      await tester.tap(find.byKey(const Key('first_run_language_continue')));
      await tester.pumpAndSettle();

      expect(languageService.saved, [AppLanguage.malayalam]);
      expect(find.byType(GrowthGoalPage), findsOneWidget);
      verify(() =>
              analytics.track(NuxEvent.languageSelected, {'language': 'ml'}))
          .called(1);
    });

    for (final key in ['first_run_log_in_top', 'first_run_log_in_bottom']) {
      testWidgets('$key goes to the login screen', (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(initial: AppRoutes.welcome));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();

        expect(find.text('stub:/login'), findsOneWidget);
      });
    }
  });

  group('goal page', () {
    Future<void> pumpGoal(WidgetTester tester, {bool dark = true}) async {
      await tester.pumpWidget(app(initial: AppRoutes.welcomeGoal, dark: dark));
      await tester.pumpAndSettle();
    }

    testWidgets('six goals in order with path names; first one picked',
        (tester) async {
      useSurface(tester, const Size(390, 900));
      await pumpGoal(tester);

      expect(find.text('What would you like to grow in?'), findsOneWidget);
      final rows = tester
          .widgetList<FirstRunChoiceRow>(find.byType(FirstRunChoiceRow))
          .toList();
      expect(rows.map((r) => r.title).toList(), [
        "I'm new to faith",
        'Forgiveness and a fresh start',
        'Walking with God daily',
        'Hope in hard times',
        'Reading a Gospel',
        'Understanding the gospel',
      ]);
      expect(rows.first.subtitle,
          'New Believer Essentials\u00A0·\u00A08\u00A0lessons');
      expect(rows.last.subtitle,
          'Romans: The Gospel Unfolded\u00A0·\u00A016\u00A0lessons');
      expect(rows.first.isSelected, isTrue);
      expect(rows.skip(1).every((r) => !r.isSelected), isTrue);
      expect(
          find.text('Pick one to start. Create a free account later to '
              'unlock all 50 paths.'),
          findsOneWidget);
      expect(
          find.text('By continuing you agree to our Terms and Privacy Policy.'),
          findsOneWidget);
      expect(
          tester
              .getSize(find.byKey(const Key('first_run_start_lesson')))
              .height,
          40);
      expect(tester.takeException(), isNull);
    });

    testWidgets('path list unavailable: no sub-label, plain guest helper',
        (tester) async {
      when(() => paths.getLearningPaths(
                language: any(named: 'language'),
                offset: any(named: 'offset'),
                limit: any(named: 'limit'),
              ))
          .thenAnswer((_) async => const Left(NetworkFailure(message: 'off')));
      useSurface(tester, const Size(390, 900));
      await pumpGoal(tester);

      final rows =
          tester.widgetList<FirstRunChoiceRow>(find.byType(FirstRunChoiceRow));
      expect(rows.every((r) => r.subtitle == null), isTrue);
      expect(
          find.text('Pick one to start. Create a free account later to '
              'unlock every path.'),
          findsOneWidget);
    });

    testWidgets('signed-in account: the plain helper', (tester) async {
      when(() => guest.hasSession).thenReturn(true);
      useSurface(tester, const Size(390, 900));
      await pumpGoal(tester);

      expect(
          find.text(
              'Pick one. It sets your first learning path; switch any time.'),
          findsOneWidget);
    });

    testWidgets('Start lesson 1 opens lesson 1 of the picked goal',
        (tester) async {
      useSurface(tester, const Size(390, 900));
      await pumpGoal(tester);

      await tester.tap(find.byKey(const Key('first_run_goal_readGospel')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('first_run_start_lesson')));
      await tester.pumpAndSettle();

      verify(() => guest.startGuest()).called(1);
      verify(() => paths.enrollInPathBySlug('gospel-of-mark')).called(1);
      expect(settings.get('first_run_goal'), 'readGospel');
      final stub = find.textContaining('stub:${AppRoutes.studyGuideV2}');
      expect(stub, findsOneWidget);
      final location = tester.widget<Text>(stub).data!.substring(5);
      final query = Uri.parse(location).queryParameters;
      expect(query['mode'], 'quick');
      expect(query['lesson_number'], '1');
      expect(query['first_run'], '1');
      verify(() =>
              analytics.track(NuxEvent.goalSelected, {'goal': 'readGospel'}))
          .called(1);
    });

    testWidgets('an enrol failure shows a short message; Try again recovers',
        (tester) async {
      var calls = 0;
      when(() => paths.enrollInPathBySlug(any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) return const Left(NetworkFailure(message: 'off'));
        return Right(EnrollmentResult(
          id: 'e1',
          learningPathId: 'p1',
          enrolledAt: DateTime(2026),
          startedAt: DateTime(2026),
        ));
      });
      useSurface(tester, const Size(390, 900));
      await pumpGoal(tester);

      await tester.tap(find.byKey(const Key('first_run_start_lesson')));
      await tester.pumpAndSettle();

      expect(find.byType(GrowthGoalPage), findsOneWidget);
      expect(
          find.text("Couldn't start the lesson. Check your connection and "
              'try again.'),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.byKey(const Key('first_run_goal_error_action')));
      await tester.pumpAndSettle();

      expect(find.textContaining('stub:${AppRoutes.studyGuideV2}'),
          findsOneWidget);
    });

    testWidgets('a guest who already holds a path is offered Home',
        (tester) async {
      when(() => paths.enrollInPathBySlug(any())).thenAnswer((_) async =>
          const Left(AccountRequiredFailure(reason: 'other_path')));
      useSurface(tester, const Size(390, 900));
      await pumpGoal(tester);

      await tester.tap(find.byKey(const Key('first_run_start_lesson')));
      await tester.pumpAndSettle();
      expect(find.text('You already have a path. Continue it from Home.'),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('first_run_goal_error_action')));
      await tester.pumpAndSettle();
      expect(find.text('stub:/'), findsOneWidget);
    });

    testWidgets('guest mode off and signed out: goes to the login screen',
        (tester) async {
      when(() => flags.guestMode).thenReturn(false);
      useSurface(tester, const Size(390, 900));
      await pumpGoal(tester);

      await tester.tap(find.byKey(const Key('first_run_start_lesson')));
      await tester.pumpAndSettle();

      expect(find.text('stub:/login'), findsOneWidget);
      verifyNever(() => guest.startGuest());
    });

    testWidgets('Skip goes Home with no goal', (tester) async {
      await settings.put('first_run_goal', 'newToFaith');
      useSurface(tester, const Size(390, 900));
      await pumpGoal(tester);

      await tester.tap(find.byKey(const Key('first_run_goal_skip')));
      await tester.pumpAndSettle();

      expect(find.text('stub:/'), findsOneWidget);
      expect(settings.get('first_run_goal'), isNull);
      verifyNever(() => guest.startGuest());
      verifyNever(() => paths.enrollInPathBySlug(any()));
    });

    testWidgets('rows, back and the step dashes are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      useSurface(tester, const Size(390, 900));
      await pumpGoal(tester);

      expect(find.bySemanticsLabel(RegExp('Step 2 of 3')), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      final first = tester
          .getSemantics(find.bySemanticsLabel(RegExp("^I'm new to faith")));
      final data = first.getSemanticsData();
      expect(data.label, contains('New Believer Essentials\u00A0·'));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(data.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      final second = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Forgiveness and a fresh start')));
      expect(
          second.getSemanticsData().flagsCollection.isSelected.toBoolOrNull(),
          isFalse);
      handle.dispose();
    });
  });

  group('no cut-off text at 320px', () {
    setUpAll(loadAppFonts);
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        final theme = dark ? 'dark' : 'light';
        testWidgets('language page ${language.code} $theme', (tester) async {
          useSurface(tester, const Size(320, 1000));
          translations.language = language;
          await tester.pumpWidget(app(initial: AppRoutes.welcome, dark: dark));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });

        testWidgets('goal page ${language.code} $theme', (tester) async {
          useSurface(tester, const Size(320, 1100));
          translations.language = language;
          await tester
              .pumpWidget(app(initial: AppRoutes.welcomeGoal, dark: dark));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }

    testWidgets('goal page error state fits in Malayalam', (tester) async {
      when(() => paths.enrollInPathBySlug(any()))
          .thenAnswer((_) async => const Left(NetworkFailure(message: 'off')));
      useSurface(tester, const Size(320, 1100));
      translations.language = AppLanguage.malayalam;
      await tester.pumpWidget(app(initial: AppRoutes.welcomeGoal));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('first_run_start_lesson')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('first_run_goal_error')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(tester);
    });
  });
}
