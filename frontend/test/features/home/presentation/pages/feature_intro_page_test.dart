import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/public_fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/feature_intro_content.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/feature_intro_source.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';
import 'package:disciplefy_bible_study/features/home/presentation/pages/feature_intro_page.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

import '../../../../helpers/fit_matrix.dart';
import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

class _MockLanguagePrefs extends Mock implements LanguagePreferenceService {}

LearningPath _path(String slug, String title) => LearningPath(
      id: 'id-$slug',
      slug: slug,
      title: title,
      description: '',
      iconName: 'menu_book',
      color: '',
      totalXp: 0,
      estimatedDays: 21,
      discipleLevel: 'seeker',
      isFeatured: true,
      topicsCount: 5,
    );

PublicFellowshipEntity _fellowship(String id, String name, String language,
        {int members = 5}) =>
    PublicFellowshipEntity(
      id: id,
      name: name,
      language: language,
      memberCount: members,
      maxMembers: null,
      currentStudyTitle: 'New Believer Essentials',
      isOfficial: true,
    );

class _FakeSource implements FeatureIntroSource {
  List<LearningPath> paths = [
    _path('rooted-in-christ', 'Rooted in Christ'),
    _path('understanding-the-bible', 'Understanding the Bible'),
  ];
  IntroVerse? verse = const IntroVerse(
    id: 'v1',
    text: 'The LORD is my shepherd; I shall not want.',
    reference: 'Psalm 23:1',
    language: 'en',
  );
  bool saveResult = true;
  bool joinResult = true;
  final saved = <String>[];
  final joined = <String>[];
  List<PublicFellowshipEntity> fellowships = [
    _fellowship('f-en', 'Disciplefy', 'en'),
    _fellowship('f-hi', 'Disciplefy हिन्दी', 'hi', members: 2),
    _fellowship('f-ml', 'Disciplefy മലയാളം', 'ml', members: 1),
  ];

  @override
  Future<List<LearningPath>> startPaths({
    required bool guest,
    required String language,
  }) async =>
      paths;

  @override
  Future<IntroVerse?> todaysVerse(String language) async => verse;

  @override
  Future<bool> saveVerse(IntroVerse verse) async {
    saved.add(verse.id);
    return saveResult;
  }

  @override
  Future<List<PublicFellowshipEntity>> officialFellowships() async =>
      fellowships;

  @override
  Future<bool> joinFellowship(String id) async {
    joined.add(id);
    return joinResult;
  }
}

const _titles = {
  NewForYouKind.paths: 'Grow step by step, one path at a time',
  NewForYouKind.memory: "Hide God's word in your heart, a minute a day",
  NewForYouKind.generate: 'Study any passage or question on your mind',
  NewForYouKind.discipler: 'Ask your Bible questions',
  NewForYouKind.fellowships: 'Study together with your church or friends',
};

void main() {
  late FakeTranslationService translations;
  late _FakeSource source;
  late _MockGuest guest;
  late _MockFlags flags;

  setUpAll(() async {
    await loadAppFonts();
  });

  setUp(() {
    translations = FakeTranslationService();
    source = _FakeSource();
    guest = _MockGuest();
    flags = _MockFlags();
    when(() => guest.isGuest).thenReturn(false);
    when(() => guest.hasSession).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<FeatureIntroSource>(source);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget app(NewForYouKind kind, {bool dark = false, String? language}) {
    if (language != null) {
      translations.language = AppLanguage.fromCode(language);
    }
    Widget stub(GoRouterState s) => Scaffold(body: Text('stub:${s.uri}'));
    final router = GoRouter(
      initialLocation: '/intro/${kind.name}',
      routes: [
        GoRoute(path: '/', builder: (_, s) => stub(s)),
        GoRoute(
          path: '/intro/:kind',
          builder: (_, s) => FeatureIntroPage(
            kind: newForYouKindNamed(s.pathParameters['kind'])!,
          ),
        ),
        for (final path in const [
          '/study-topics',
          '/memory-verses',
          '/generate-study',
          '/discipler',
          '/community',
          '/study-guide-v2',
          '/learning-path/:id',
        ])
          GoRoute(path: path, builder: (_, s) => stub(s)),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  Future<void> open(WidgetTester tester, NewForYouKind kind) async {
    useSurface(tester, const Size(390, 1200));
    await tester.pumpWidget(app(kind));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  for (final kind in NewForYouKind.values) {
    testWidgets('intro $kind renders 3 steps and two actions, no designer note',
        (tester) async {
      await open(tester, kind);
      expect(find.textContaining('Opened from'), findsNothing);
      expect(find.textContaining('Explore all features'), findsNothing);
      for (var n = 1; n <= 3; n++) {
        expect(find.byKey(Key('intro_step_$n')), findsOneWidget);
      }
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text(_titles[kind]!), findsOneWidget);
      expect(find.text('START WITH'), findsOneWidget);
      expect(find.textContaining('intro.'), findsNothing);
      expect(tester.getSize(find.byKey(const Key('intro_primary'))).height,
          greaterThanOrEqualTo(40));
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect((t.style?.fontSize ?? 14) >= 12, isTrue, reason: t.data);
      }
    });
  }

  testWidgets('× closes the introduction', (tester) async {
    await open(tester, NewForYouKind.paths);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('stub:/'), findsOneWidget);
  });

  group('paths', () {
    testWidgets('shows two paths; Browse paths opens Topics', (tester) async {
      await open(tester, NewForYouKind.paths);
      expect(find.text('Rooted in Christ'), findsOneWidget);
      expect(find.text('Understanding the Bible'), findsOneWidget);
      await tapKey(tester, 'intro_primary');
      expect(find.text('stub:/study-topics'), findsOneWidget);
    });

    testWidgets('a path row opens that path', (tester) async {
      await open(tester, NewForYouKind.paths);
      await tester.tap(find.text('Rooted in Christ'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/learning-path/id-rooted-in-christ?source=home'),
          findsOneWidget);
    });

    testWidgets('Maybe later closes', (tester) async {
      await open(tester, NewForYouKind.paths);
      expect(find.text('Maybe later'), findsOneWidget);
      await tapKey(tester, 'intro_secondary');
      expect(find.text('stub:/'), findsOneWidget);
    });

    testWidgets('no paths: no Start with card', (tester) async {
      source.paths = [];
      await open(tester, NewForYouKind.paths);
      expect(find.text('START WITH'), findsNothing);
    });
  });

  group('memory', () {
    testWidgets('shows today\'s verse; primary saves it and opens practice',
        (tester) async {
      await open(tester, NewForYouKind.memory);
      expect(find.text('“The LORD is my shepherd; I shall not want.”'),
          findsOneWidget);
      expect(find.text('Psalm 23:1'), findsOneWidget);
      await tapKey(tester, 'intro_primary');
      expect(source.saved, ['v1']);
      expect(find.text('stub:/memory-verses'), findsOneWidget);
    });

    testWidgets('a failed save stays and says so', (tester) async {
      source.saveResult = false;
      await open(tester, NewForYouKind.memory);
      await tapKey(tester, 'intro_primary');
      expect(find.text('stub:/memory-verses'), findsNothing);
      expect(
          find.text('Something went wrong. Please try again.'), findsOneWidget);
    });

    testWidgets('Choose my own verse opens memory verses without saving',
        (tester) async {
      await open(tester, NewForYouKind.memory);
      await tapKey(tester, 'intro_secondary');
      expect(source.saved, isEmpty);
      expect(find.text('stub:/memory-verses'), findsOneWidget);
    });

    testWidgets('a guest is asked for an account', (tester) async {
      when(() => guest.isGuest).thenReturn(true);
      await open(tester, NewForYouKind.memory);
      await tapKey(tester, 'intro_primary');
      expect(find.text('Memory verses need an account'), findsOneWidget);
      expect(source.saved, isEmpty);
    });
  });

  group('generate', () {
    testWidgets('Start a study opens Generate with Romans 8', (tester) async {
      await open(tester, NewForYouKind.generate);
      await tapKey(tester, 'intro_primary');
      expect(
          find.text('stub:/generate-study?prefill=Romans%208'), findsOneWidget);
    });

    testWidgets('See an example opens the Romans 8 Quick Read', (tester) async {
      await open(tester, NewForYouKind.generate);
      await tapKey(tester, 'intro_secondary');
      expect(
          find.text('stub:/study-guide-v2?input=Romans+8&type=scripture'
              '&language=en&mode=quick&source=home'),
          findsOneWidget);
    });

    testWidgets('See an example follows a saved default study mode',
        (tester) async {
      final prefs = _MockLanguagePrefs();
      when(prefs.peekStudyModePreferenceRaw).thenReturn('deep');
      sl.registerSingleton<LanguagePreferenceService>(prefs);
      await open(tester, NewForYouKind.generate);
      await tapKey(tester, 'intro_secondary');
      expect(
          find.text('stub:/study-guide-v2?input=Romans+8&type=scripture'
              '&language=en&mode=deep&source=home'),
          findsOneWidget);
    });

    testWidgets('See an example stays Quick Read for "recommended"',
        (tester) async {
      final prefs = _MockLanguagePrefs();
      when(prefs.peekStudyModePreferenceRaw).thenReturn('recommended');
      sl.registerSingleton<LanguagePreferenceService>(prefs);
      await open(tester, NewForYouKind.generate);
      await tapKey(tester, 'intro_secondary');
      expect(find.textContaining('mode=quick'), findsOneWidget);
    });

    testWidgets('an example chip prefills Generate', (tester) async {
      await open(tester, NewForYouKind.generate);
      await tester.tap(find.text('Forgiveness'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/generate-study?prefill=Forgiveness'),
          findsOneWidget);
    });
  });

  group('discipler', () {
    testWidgets('Ask a question opens Discipler with the question',
        (tester) async {
      await open(tester, NewForYouKind.discipler);
      expect(find.text('Why did Jesus have to die?'), findsOneWidget);
      await tapKey(tester, 'intro_primary');
      expect(
          find.text('stub:/discipler?prefill='
              '${Uri.encodeComponent('Why did Jesus have to die?')}'),
          findsOneWidget);
    });

    testWidgets('guest discipler intro asks for an account', (tester) async {
      when(() => guest.isGuest).thenReturn(true);
      await open(tester, NewForYouKind.discipler);
      await tapKey(tester, 'intro_primary');
      expect(find.text('Discipler needs an account'), findsOneWidget);
      expect(find.textContaining('stub:/discipler'), findsNothing);
    });

    testWidgets('Not now closes', (tester) async {
      await open(tester, NewForYouKind.discipler);
      await tapKey(tester, 'intro_secondary');
      expect(find.text('stub:/'), findsOneWidget);
    });
  });

  group('fellowships', () {
    testWidgets('official card, other languages, join opens community',
        (tester) async {
      await open(tester, NewForYouKind.fellowships);
      expect(find.text('Disciplefy'), findsOneWidget);
      expect(find.text('5 members · Open'), findsOneWidget);
      expect(find.text('Disciplefy हिन्दी'), findsOneWidget);
      expect(find.text('Disciplefy മലയാളം'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
      expect(find.text('1 member'), findsOneWidget);
      expect(find.text('Join Disciplefy'), findsOneWidget);
      await tapKey(tester, 'intro_primary');
      expect(source.joined, ['f-en']);
      expect(find.text('stub:/community'), findsOneWidget);
    });

    testWidgets('a failed join stays and says so', (tester) async {
      source.joinResult = false;
      await open(tester, NewForYouKind.fellowships);
      await tapKey(tester, 'intro_primary');
      expect(find.text('Could not join. Try again.'), findsOneWidget);
      expect(find.text('stub:/community'), findsNothing);
    });

    testWidgets('Find or create a group opens community', (tester) async {
      await open(tester, NewForYouKind.fellowships);
      await tapKey(tester, 'intro_secondary');
      expect(source.joined, isEmpty);
      expect(find.text('stub:/community'), findsOneWidget);
    });

    testWidgets('a guest is asked for an account before joining',
        (tester) async {
      when(() => guest.isGuest).thenReturn(true);
      await open(tester, NewForYouKind.fellowships);
      await tapKey(tester, 'intro_primary');
      expect(find.text('Groups need an account'), findsOneWidget);
      expect(source.joined, isEmpty);
    });
  });

  test('kinds are found by their route name', () {
    for (final kind in NewForYouKind.values) {
      expect(newForYouKindNamed(kind.name), kind);
    }
    expect(newForYouKindNamed('nope'), isNull);
    expect(newForYouKindNamed(null), isNull);
  });

  for (final c in fitCases()) {
    final language = c.lang;
    final dark = c.dark;
    for (final kind in NewForYouKind.values) {
      testWidgets(
          '$language ${c.width.toInt()}px $kind intro fits (dark: $dark)',
          (tester) async {
        useSurface(tester, c.size(700));
        await tester.pumpWidget(app(kind, dark: dark, language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        expect(find.textContaining('intro.'), findsNothing);
      });
    }
  }
}
