import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_event.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/review_statistics_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/memory_verses_home_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_header_line.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_verse_list_item.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

import '../../../helpers/text_fit.dart';
import '../../../helpers/welcome_test_harness.dart';

class _MockMemoryVerseBloc extends MockBloc<MemoryVerseEvent, MemoryVerseState>
    implements MemoryVerseBloc {}

class _MockDailyVerseBloc extends MockBloc<DailyVerseEvent, DailyVerseState>
    implements DailyVerseBloc {}

class _MockGamificationBloc
    extends MockBloc<GamificationEvent, GamificationState>
    implements GamificationBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _SeenWalkthroughs extends Fake implements WalkthroughRepository {
  @override
  Future<bool> hasSeen(WalkthroughScreen screen) async => true;

  @override
  Future<void> markSeen(WalkthroughScreen screen) async {}
}

final _now = DateTime.now();

MemoryVerseEntity _verse({
  String id = 'v1',
  String reference = 'Philippians 4:13',
  int daysOverdue = 0,
  double ease = 2.5,
  String language = 'en',
}) =>
    MemoryVerseEntity(
      id: id,
      verseReference: reference,
      verseText: 'I can do all things through him who strengthens me.',
      language: language,
      sourceType: 'manual',
      easeFactor: ease,
      intervalDays: 3,
      repetitions: 2,
      nextReviewDate:
          DateTime(_now.year, _now.month, _now.day - daysOverdue, 0, 1),
      addedDate: DateTime(2026, 9, 2),
      totalReviews: 4,
      createdAt: DateTime(2026, 9, 2),
    );

final _dailyVerse = DailyVerseEntity(
  id: 'dv1',
  reference: 'Psalm 23:1',
  referenceTranslations: const ReferenceTranslations(
      en: 'Psalm 23:1', hi: 'भजन संहिता 23:1', ml: 'സങ്കീർത്തനം 23:1'),
  translations: const DailyVerseTranslations(
    esv: 'The LORD is my shepherd; I shall not want.',
    hindi: 'यहोवा मेरा चरवाहा है, मुझे कुछ घटी न होगी।',
    malayalam: 'യഹോവ എന്റെ ഇടയനാകുന്നു; എനിക്കു മുട്ടു വരികയില്ല.',
  ),
  date: DateTime(_now.year, _now.month, _now.day),
);

void main() {
  late FakeTranslationService translations;
  late _MockMemoryVerseBloc bloc;
  late _MockDailyVerseBloc dailyVerse;
  late _MockConnectivityBloc connectivity;
  late List<String> visited;

  setUpAll(() async {
    registerFallbackValue(const LoadMemoryStatisticsEvent());
    await loadAppFonts();
  });

  setUp(() {
    translations = FakeTranslationService();
    bloc = _MockMemoryVerseBloc();
    dailyVerse = _MockDailyVerseBloc();
    connectivity = _MockConnectivityBloc();
    visited = [];
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<WalkthroughRepository>(_SeenWalkthroughs());
    sl.registerSingleton<GamificationBloc>(_MockGamificationBloc());
    sl.registerFactory<MemoryVerseBloc>(() => bloc);
    whenListen<ConnectivityState>(
      connectivity,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityOnline(),
    );
  });

  tearDown(() async => sl.reset());

  Future<void> pumpMemoryHome(
    WidgetTester tester, {
    required List<MemoryVerseEntity> verses,
    int? streak,
    bool dark = true,
    Size size = const Size(390, 844),
  }) async {
    whenListen<MemoryVerseState>(
      bloc,
      Stream<MemoryVerseState>.fromIterable([
        if (streak != null)
          MemoryStreakLoaded(
            currentStreak: streak,
            longestStreak: streak,
            totalPracticeDays: streak,
            freezeDaysAvailable: 0,
            freezeDaysUsed: 0,
            milestones: const {},
          ),
      ]),
      initialState: DueVersesLoaded(
        verses: verses,
        statistics: ReviewStatisticsEntity(
          totalVerses: verses.length,
          dueVerses: verses.where((v) => v.isDue).length,
          reviewedToday: 0,
          upcomingReviews: 0,
          masteredVerses: 0,
          fullyMasteredVerses: 0,
        ),
        hasMore: false,
      ),
    );
    whenListen<DailyVerseState>(
      dailyVerse,
      const Stream<DailyVerseState>.empty(),
      initialState: DailyVerseLoaded(
        verse: _dailyVerse,
        currentLanguage: switch (translations.language) {
          AppLanguage.hindi => VerseLanguage.hindi,
          AppLanguage.malayalam => VerseLanguage.malayalam,
          _ => VerseLanguage.english,
        },
        preferredLanguage: VerseLanguage.english,
      ),
    );
    GoRoute stub(String route) => GoRoute(
          path: route,
          builder: (_, state) {
            visited.add(state.uri.toString());
            return Scaffold(body: Text('stub:$route'));
          },
        );
    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(
            path: '/page', builder: (_, __) => const MemoryVersesHomePage()),
        stub('/memory-verses/champions'),
        stub('/memory-verses/stats'),
        stub('/memory-verses/practice/:id'),
        stub('/'),
      ],
    );
    useSurface(tester, size);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<MemoryVerseBloc>.value(value: bloc),
        BlocProvider<DailyVerseBloc>.value(value: dailyVerse),
        BlocProvider<ConnectivityBloc>.value(value: connectivity),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
  }

  String tr(String key, [Map<String, dynamic>? args]) =>
      translations.getTranslation(key, args);

  testWidgets("empty: Save today's verse is the primary action",
      (tester) async {
    await pumpMemoryHome(tester, verses: []);
    expect(find.widgetWithText(FilledButton, "Save today's verse"),
        findsOneWidget);
    expect(find.text('Add a verse'), findsOneWidget);
    expect(find.textContaining('The LORD is my shepherd; I shall not want.'),
        findsOneWidget);
    expect(
        find.text(
            'Saved verses come back for a short review when they are due.'),
        findsOneWidget);
  });

  testWidgets("empty: Save today's verse adds the daily verse", (tester) async {
    await pumpMemoryHome(tester, verses: []);
    await tester.tap(find.text("Save today's verse"));
    await tester.pump();
    verify(() => bloc.add(const AddVerseFromDaily('dv1', language: 'en')))
        .called(1);
  });

  testWidgets('empty: Add a verse opens the add-verse sheet', (tester) async {
    await pumpMemoryHome(tester, verses: []);
    await tester.tap(find.text('Add a verse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Suggested'), findsOneWidget);
  });

  testWidgets('overdue verse: neutral Due, no red, no days, no difficulty',
      (tester) async {
    await pumpMemoryHome(tester,
        verses: [_verse(daysOverdue: 30, ease: 1.8)], streak: 1);
    final due = tester.widget<Text>(find.text('Due'));
    expect(due.style?.color, isNot(AppColors.error));
    expect(find.textContaining('overdue'), findsNothing);
    expect(find.textContaining('30'), findsNothing);
    expect(find.text('Hard'), findsNothing);
    expect(find.text('Easy'), findsNothing);
  });

  testWidgets('stats one line; Statistics and Champions only in the menu',
      (tester) async {
    await pumpMemoryHome(tester, verses: [_verse()], streak: 1);
    expect(find.text('1-day streak · 1 verse'), findsOneWidget);
    expect(find.text('Champions'), findsNothing);
    expect(find.text('Statistics'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Champions'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Add a verse'), findsOneWidget);

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    expect(visited.last, '/memory-verses/stats');
  });

  testWidgets('header line uses the plural for several verses', (tester) async {
    await pumpMemoryHome(tester,
        verses: [_verse(), _verse(id: 'v2', reference: 'John 3:16')],
        streak: 4);
    expect(find.text('4-day streak · 2 verses'), findsOneWidget);
  });

  testWidgets('menu Champions opens the champions page', (tester) async {
    await pumpMemoryHome(tester, verses: [_verse()], streak: 1);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Champions'));
    await tester.pumpAndSettle();
    expect(visited.last, '/memory-verses/champions');
  });

  testWidgets('language filter only with verses in two languages',
      (tester) async {
    await pumpMemoryHome(tester, verses: [_verse()]);
    expect(find.text(VerseLanguage.hindi.displayName), findsNothing);
  });

  testWidgets('language filter shows with verses in two languages',
      (tester) async {
    await pumpMemoryHome(tester, verses: [
      _verse(),
      _verse(id: 'v2', reference: 'यूहन्ना 3:16', language: 'hi'),
    ]);
    expect(find.text(VerseLanguage.hindi.displayName), findsOneWidget);
  });

  testWidgets('tapping a verse still opens the practice mode chooser',
      (tester) async {
    await pumpMemoryHome(tester, verses: [_verse()], streak: 1);
    await tester.tap(find.text('Philippians 4:13'));
    await tester.pumpAndSettle();
    expect(visited, contains('/memory-verses/practice/v1'));
  });

  for (final dark in [true, false]) {
    for (final language in AppLanguage.values) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('320 $mode ${language.code}: empty state fits',
          (tester) async {
        translations.language = language;
        await pumpMemoryHome(tester,
            verses: [], dark: dark, size: const Size(320, 640));
        expect(find.text(tr(TranslationKeys.memorySaveTodaysVerse)),
            findsOneWidget);
        expectNoTruncatedText(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('320 $mode ${language.code}: header line and row fit',
          (tester) async {
        translations.language = language;
        await pumpMemoryHome(tester,
            verses: [_verse(daysOverdue: 3)],
            streak: 12,
            dark: dark,
            size: const Size(320, 640));
        expect(find.byType(MemoryHeaderLine), findsOneWidget);
        expect(find.byType(MemoryVerseListItem), findsOneWidget);
        expect(find.text(tr(TranslationKeys.memoryDue)), findsOneWidget);
        expectNoTruncatedText(tester,
            allow: {'I can do all things', 'Philippians'});
        expect(tester.takeException(), isNull);
      });
    }
  }
}
