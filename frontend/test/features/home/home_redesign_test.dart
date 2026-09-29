import 'dart:io';
import 'dart:math' as math;

import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/app_translations.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_streak.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_sections.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_verse_hero.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/review_statistics_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/widgets/personalization_prompt_card.dart';
import 'package:flutter/rendering.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/fellowship_changes.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_community_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'home_redesign_test.mocks.dart';

class _MockMemoryVerseBloc extends MockBloc<MemoryVerseEvent, MemoryVerseState>
    implements MemoryVerseBloc {}

/// Resolves keys against the real English table, so a missing key shows up
/// as the raw key in the rendered text and fails the assertions below.
String _english(String key, Map<String, dynamic>? args) {
  dynamic node = AppTranslations.translations[AppLanguage.english];
  for (final part in key.split('.')) {
    if (node is Map && node.containsKey(part)) {
      node = node[part];
    } else {
      return key;
    }
  }
  var text = node is String ? node : key;
  args?.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
  return text;
}

const _shortVerse = 'I can do all things through him who strengthens me.';
const _longVerse =
    'For I am persuaded, that neither death, nor life, nor angels, nor '
    'principalities, nor powers, nor things present, nor things to come, '
    'nor height, nor depth, nor any other creature, shall be able to '
    'separate us from the love of God, which is in Christ Jesus our Lord.';

DailyVerseEntity _verse(String text, {String ref = 'Philippians 4:13'}) =>
    DailyVerseEntity(
      id: 'v1',
      reference: ref,
      referenceTranslations: ReferenceTranslations(en: ref, hi: ref, ml: ref),
      translations:
          DailyVerseTranslations(esv: text, hindi: text, malayalam: text),
      date: DateTime(2026, 9, 29),
    );

DailyVerseLoaded _loaded(String text, {int streak = 0}) => DailyVerseLoaded(
      verse: _verse(text),
      currentLanguage: VerseLanguage.english,
      preferredLanguage: VerseLanguage.english,
      streak: streak == 0
          ? null
          : DailyVerseStreak(
              userId: 'u1',
              currentStreak: streak,
              longestStreak: streak,
              totalViews: streak,
              createdAt: DateTime(2026, 9),
              updatedAt: DateTime(2026, 9, 29),
            ),
    );

@GenerateMocks(
    [TranslationService, CommunityRepository, LanguagePreferenceService])
void main() {
  late _MockMemoryVerseBloc memoryBloc;

  setUpAll(() async {
    // Real app fonts, not the square test glyphs: the "never cut" checks
    // below measure text, and the test font is ~1.8x wider than Inter.
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        final bytes = File('assets/fonts/$f').readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
    }

    await load('Inter', [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
    ]);
    await load('Poppins', [
      'Poppins-Regular.ttf',
      'Poppins-Medium.ttf',
      'Poppins-SemiBold.ttf',
    ]);

    final translations = MockTranslationService();
    when(translations.getTranslation(any, any)).thenAnswer((i) => _english(
        i.positionalArguments[0] as String,
        i.positionalArguments.length > 1
            ? i.positionalArguments[1] as Map<String, dynamic>?
            : null));
    when(translations.getTranslation(any))
        .thenAnswer((i) => _english(i.positionalArguments[0] as String, null));
    sl.registerLazySingleton<TranslationService>(() => translations);
  });

  tearDownAll(() => sl.reset());

  setUp(() {
    memoryBloc = _MockMemoryVerseBloc();
    whenListen<MemoryVerseState>(
        memoryBloc, const Stream<MemoryVerseState>.empty(),
        initialState: const MemoryVerseInitial());
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
    double width = 390,
    double height = 900,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BlocProvider<MemoryVerseBloc>.value(
      value: memoryBloc,
      child: MaterialApp(
        theme: theme ?? AppTheme.darkTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ));
    await tester.pump();
  }

  Widget hero(DailyVerseState state,
          {VoidCallback? onStudy,
          VoidCallback? onRetry,
          String name = 'Fenn'}) =>
      HomeVerseHero(
        imageAsset: homeHeroImages.first,
        greeting: _english(TranslationKeys.homeGoodEvening, {'name': name}),
        subtitle: _english(TranslationKeys.homeContinueJourney, null),
        verse: HomeDailyVerseView(
          state: state,
          onStudy: onStudy,
          onRetry: onRetry ?? () {},
        ),
      );

  group('pure helpers', () {
    test('greeting follows the time of day', () {
      expect(homeGreetingKeyFor(0), TranslationKeys.homeGoodEvening);
      expect(homeGreetingKeyFor(4), TranslationKeys.homeGoodEvening);
      expect(homeGreetingKeyFor(5), TranslationKeys.homeGoodMorning);
      expect(homeGreetingKeyFor(11), TranslationKeys.homeGoodMorning);
      expect(homeGreetingKeyFor(12), TranslationKeys.homeGoodAfternoon);
      expect(homeGreetingKeyFor(16), TranslationKeys.homeGoodAfternoon);
      expect(homeGreetingKeyFor(17), TranslationKeys.homeGoodEvening);
      expect(homeGreetingKeyFor(23), TranslationKeys.homeGoodEvening);
    });

    test('verse size steps down with length', () {
      expect(homeVerseFontSize(_shortVerse), 27);
      expect(homeVerseFontSize('x' * 60), 27);
      expect(homeVerseFontSize('x' * 61), 22);
      expect(homeVerseFontSize('x' * 120), 22);
      expect(homeVerseFontSize(_longVerse), 18);
    });

    test('hero image is stable within a day and rotates across days', () {
      final morning = homeHeroImageFor(DateTime(2026, 9, 29, 6));
      final night = homeHeroImageFor(DateTime(2026, 9, 29, 23, 59));
      final nextDay = homeHeroImageFor(DateTime(2026, 9, 30, 6));
      expect(morning, night);
      expect(nextDay, isNot(morning));
      expect(homeHeroImages, contains(morning));
    });

    test('every new home key exists in all three languages', () {
      const keys = [
        TranslationKeys.homeGoodMorning,
        TranslationKeys.homeGoodAfternoon,
        TranslationKeys.homeGoodEvening,
        TranslationKeys.homeStudyNow,
        TranslationKeys.homeContinueLearning,
        TranslationKeys.homeAllPaths,
        TranslationKeys.homeBrowsePaths,
        TranslationKeys.homeBrowsePathsHint,
        TranslationKeys.homeTopicsProgress,
        TranslationKeys.homeStartHere,
        TranslationKeys.homeDayStreak,
        TranslationKeys.homeKeepItAlive,
        TranslationKeys.homeNoStreakYet,
        TranslationKeys.homeStartStreakHint,
        TranslationKeys.homeToReview,
        TranslationKeys.homeAllCaughtUp,
        TranslationKeys.homeNothingDue,
        TranslationKeys.homeReviewMore,
        TranslationKeys.homeMeetingToday,
        TranslationKeys.homeMeetingTodayAt,
        TranslationKeys.homeMeetingNowEnds,
        TranslationKeys.homeMeetingLive,
      ];
      for (final lang in AppLanguage.values) {
        final home = AppTranslations.translations[lang]!['home'] as Map;
        for (final key in keys) {
          expect(home[key.split('.').last], isA<String>(),
              reason: '$key missing for $lang');
        }
      }
    });
  });

  group('verse hero', () {
    testWidgets('loaded: greeting, verse, Study now and the three actions',
        (tester) async {
      var studied = 0;
      await pump(tester, hero(_loaded(_shortVerse), onStudy: () => studied++));

      expect(find.text('Good evening, Fenn'), findsOneWidget);
      expect(find.text(_shortVerse), findsOneWidget);
      expect(find.text('Philippians 4:13 · KJV'), findsOneWidget);
      expect(find.text('VERSE OF THE DAY'), findsOneWidget);
      expect(find.text('· SEPTEMBER 29, 2026'), findsOneWidget);
      expect(find.text('Study now'), findsOneWidget);

      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      // Refresh belongs to the error state only.
      expect(find.byIcon(Icons.refresh), findsNothing);

      await tester.tap(find.text('Study now'));
      await tester.tap(find.text(_shortVerse));
      expect(studied, 2);
    });

    testWidgets('error: offers a retry and nothing else', (tester) async {
      var retried = 0;
      await pump(
          tester,
          hero(const DailyVerseError(message: 'boom'),
              onRetry: () => retried++));

      expect(find.text('Unable to Load Verse'), findsOneWidget);
      expect(find.text('Study now'), findsNothing);
      expect(find.byIcon(Icons.copy_outlined), findsNothing);

      await tester.tap(find.byIcon(Icons.refresh));
      expect(retried, 1);
    });

    testWidgets('loading: shows placeholders, no actions', (tester) async {
      await pump(tester, hero(const DailyVerseLoading()));
      expect(find.byKey(const Key('home_verse_loading')), findsOneWidget);
      expect(find.text('Study now'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('offline: shows the cached verse without actions',
        (tester) async {
      await pump(
          tester,
          hero(DailyVerseOffline(
            verse: _verse(_shortVerse),
            currentLanguage: VerseLanguage.english,
            preferredLanguage: VerseLanguage.english,
          )));
      expect(find.text(_shortVerse), findsOneWidget);
      expect(find.text('Offline Mode'), findsOneWidget);
      expect(find.text('Study now'), findsNothing);
    });

    for (final (label, theme) in [
      ('dark', AppTheme.darkTheme),
      ('light', AppTheme.lightTheme),
    ]) {
      testWidgets('$label: long verse shrinks and fits on a small phone',
          (tester) async {
        await pump(
          tester,
          hero(_loaded(_longVerse), name: 'Bartholomew Alexander Fitzgerald'),
          theme: theme,
          width: 320,
          height: 1400,
        );
        final text =
            tester.widget<Text>(find.byKey(const Key('home_verse_text')));
        expect(text.style?.fontSize, 18);
        expect(text.maxLines, homeVerseMaxLines);
        // Any RenderFlex overflow would have been reported as an exception.
        expect(tester.takeException(), isNull);
        expect(find.text('Study now'), findsOneWidget);
      });
    }

    for (final (label, theme) in [
      ('dark', AppTheme.darkTheme),
      ('light', AppTheme.lightTheme),
    ]) {
      testWidgets('$label: shade stays dark behind content, fades below it',
          (tester) async {
        await pump(tester, hero(_loaded(_shortVerse)), theme: theme);

        final fade = tester.widget<DecoratedBox>(
            find.byKey(const Key('home_hero_ground_fade')));
        final fadeColors =
            ((fade.decoration as BoxDecoration).gradient! as LinearGradient)
                .colors;
        expect(fadeColors.last, theme.scaffoldBackgroundColor);

        // The fade strip must sit entirely below the verse actions.
        final fadeTop = tester
            .getTopLeft(find.byKey(const Key('home_hero_ground_fade')))
            .dy;
        final actionsBottom =
            tester.getBottomLeft(find.byIcon(Icons.copy_outlined)).dy;
        expect(fadeTop, greaterThanOrEqualTo(actionsBottom));

        // The main shade is near-black at every stop, in both themes.
        final shade = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.gradient)
            .whereType<LinearGradient>()
            .firstWhere((g) => g.colors.length == 4);
        for (final c in shade.colors) {
          expect(c.r, lessThan(0.1));
          expect(c.a, greaterThanOrEqualTo(0.5));
        }
      });
    }
  });

  group('no truncated labels', () {
    bool fullyShown(WidgetTester tester, String text) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      return !paragraph.didExceedMaxLines &&
          paragraph.size.width >=
              paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5;
    }

    for (final width in [280.0, 320.0, 390.0]) {
      testWidgets('Study now is never cut at ${width.toInt()}px',
          (tester) async {
        await pump(tester, hero(_loaded(_shortVerse)), width: width);
        expect(fullyShown(tester, 'Study now'), isTrue);
        expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Personalize card buttons keep their full labels at 280px',
        (tester) async {
      var started = 0, skipped = 0;
      await pump(
        tester,
        PersonalizationPromptCard(
          onGetStarted: () => started++,
          onSkip: () => skipped++,
        ),
        width: 280,
      );
      expect(find.text('Personalize Your Experience'), findsOneWidget);
      expect(fullyShown(tester, 'Get Started'), isTrue);
      expect(fullyShown(tester, 'Maybe Later'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Get Started'));
      await tester.tap(find.text('Maybe Later'));
      expect((started, skipped), (1, 1));
    });

    for (final (label, theme) in [
      ('dark', AppTheme.darkTheme),
      ('light', AppTheme.lightTheme),
    ]) {
      testWidgets('Personalize card renders in $label theme', (tester) async {
        await pump(
          tester,
          PersonalizationPromptCard(onGetStarted: () {}, onSkip: () {}),
          theme: theme,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('memory verse due', () {
    MemoryVerseEntity memVerse(String sourceId) => MemoryVerseEntity(
          id: 'm1',
          verseReference: 'Philippians 4:13',
          verseText: _shortVerse,
          language: 'en',
          sourceType: 'daily_verse',
          sourceId: sourceId,
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          nextReviewDate: DateTime(2026, 9, 29),
          addedDate: DateTime(2026, 9, 29),
          totalReviews: 0,
          createdAt: DateTime(2026, 9, 29),
        );
    const stats = ReviewStatisticsEntity(
      totalVerses: 1,
      dueVerses: 1,
      reviewedToday: 0,
      upcomingReviews: 0,
      masteredVerses: 0,
      fullyMasteredVerses: 0,
    );

    testWidgets('verse already in the deck shows as added, not addable',
        (tester) async {
      whenListen<MemoryVerseState>(
          memoryBloc, const Stream<MemoryVerseState>.empty(),
          initialState:
              DueVersesLoaded(verses: [memVerse('v1')], statistics: stats));
      await pump(tester, hero(_loaded(_shortVerse)));
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsNothing);
    });

    testWidgets('transient states keep the added state (no flicker)',
        (tester) async {
      whenListen<MemoryVerseState>(
        memoryBloc,
        Stream<MemoryVerseState>.fromIterable([const MemoryVerseInitial()]),
        initialState:
            DueVersesLoaded(verses: [memVerse('v1')], statistics: stats),
      );
      await pump(tester, hero(_loaded(_shortVerse)));
      await tester.pump();
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
    });
  });

  group('pinned header', () {
    Future<void> pumpPinned(WidgetTester tester, ThemeData theme,
        {VoidCallback? onHeaderTap}) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: HomeScrollView(
            headerBuilder: (context, onGround) => TextButton(
              onPressed: onHeaderTap,
              child: Text(onGround ? 'header on page' : 'header on photo'),
            ),
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 80, child: Text('row $i')),
            ],
          ),
        ),
      ));
    }

    double backdrop(WidgetTester tester) => tester
        .widget<FadeTransition>(find.byKey(const Key('home_header_backdrop')))
        .opacity
        .value;

    SystemUiOverlayStyle overlay(WidgetTester tester) => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first)
        .value;

    for (final (label, theme, scrolledIcons) in [
      ('light', AppTheme.lightTheme, SystemUiOverlayStyle.dark),
      ('dark', AppTheme.darkTheme, SystemUiOverlayStyle.light),
    ]) {
      testWidgets('$label: header stays put and turns solid on scroll',
          (tester) async {
        await pumpPinned(tester, theme);
        final headerTop =
            tester.getTopLeft(find.byKey(const Key('home_pinned_header'))).dy;
        expect(headerTop, 44 + 12, reason: 'below the status bar');
        expect(backdrop(tester), 0);
        expect(find.text('header on photo'), findsOneWidget);
        expect(overlay(tester), SystemUiOverlayStyle.light);

        // A small scroll already makes it solid: never half-covered text.
        await tester.drag(find.text('row 3'), const Offset(0, -30));
        await tester.pumpAndSettle();
        expect(backdrop(tester), 1);
        expect(find.text('header on page'), findsOneWidget);
        expect(overlay(tester), scrolledIcons);

        await tester.drag(find.text('row 3'), const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(
            tester.getTopLeft(find.byKey(const Key('home_pinned_header'))).dy,
            headerTop,
            reason: 'the header never scrolls');

        HomeScrollToTop.instance.request();
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('row 0')).dy, 0);
        expect(backdrop(tester), 0);
        expect(find.text('header on photo'), findsOneWidget);
      });
    }

    testWidgets('header stays tappable at every scroll position',
        (tester) async {
      var taps = 0;
      await pumpPinned(tester, AppTheme.darkTheme, onHeaderTap: () => taps++);
      await tester.tap(find.text('header on photo'));
      await tester.drag(find.text('row 3'), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('header on page'));
      expect(taps, 2);
    });
  });

  group('today tiles', () {
    testWidgets('streak and review counts', (tester) async {
      var reviewTaps = 0;
      await pump(
        tester,
        HomeTodayTiles(
          streakDays: 2,
          dueCount: 3,
          showReview: true,
          nextReviewReference: 'John 3:16',
          onReviewTap: () => reviewTaps++,
        ),
      );
      expect(find.text('2-day streak'), findsOneWidget);
      expect(find.text('Keep it alive'), findsOneWidget);
      expect(find.text('3 to review'), findsOneWidget);
      expect(find.text('John 3:16  +2\u00A0more', findRichText: true),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('home_review_tile')));
      expect(reviewTaps, 1);
    });

    testWidgets('one due: reference only, no "+more"', (tester) async {
      await pump(
          tester,
          const HomeTodayTiles(
              streakDays: 1,
              dueCount: 1,
              showReview: true,
              nextReviewReference: 'Philippians 4:13'));
      expect(find.text('1 to review'), findsOneWidget);
      expect(find.text('Philippians 4:13', findRichText: true), findsOneWidget);
      expect(find.textContaining('more', findRichText: true), findsNothing);
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('many due, long reference: nothing cut at ${width.toInt()}px',
          (tester) async {
        await pump(
          tester,
          const HomeTodayTiles(
              streakDays: 1,
              dueCount: 12,
              showReview: true,
              nextReviewReference: '1 Thessalonians 5:16-18'),
          width: width,
        );
        for (final p in tester
            .renderObjectList<RenderParagraph>(find.byType(RichText))) {
          expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('empty states read as encouragement, not zeros',
        (tester) async {
      await pump(tester,
          const HomeTodayTiles(streakDays: 0, dueCount: 0, showReview: true));
      expect(find.text('No streak yet'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.textContaining('0'), findsNothing);
    });

    testWidgets('review tile hidden when memory verses is hidden',
        (tester) async {
      await pump(tester,
          const HomeTodayTiles(streakDays: 5, dueCount: 4, showReview: false));
      expect(find.byKey(const Key('home_review_tile')), findsNothing);
      expect(find.text('5-day streak'), findsOneWidget);
    });

    testWidgets('fits at 320px with the largest counts', (tester) async {
      await pump(
        tester,
        const HomeTodayTiles(
            streakDays: 1234,
            dueCount: 999,
            showReview: true,
            nextReviewReference: '1 Thessalonians 5:16-18'),
        width: 320,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('path row', () {
    testWidgets('shows progress text and is tappable', (tester) async {
      var taps = 0;
      await pump(
        tester,
        HomePathRow(
          title: 'The Attributes of God',
          subtitle: '3 of 8 topics',
          progress: 0.375,
          accent: Colors.amber,
          onTap: () => taps++,
        ),
        theme: AppTheme.lightTheme,
      );
      expect(find.text('The Attributes of God'), findsOneWidget);
      expect(find.text('3 of 8 topics'), findsOneWidget);
      expect(find.byType(HomeProgressRing), findsOneWidget);
      await tester.tap(find.text('The Attributes of God'));
      expect(taps, 1);
    });
  });

  group('recent activity empty states', () {
    late MockCommunityRepository repo;

    setUp(() {
      repo = MockCommunityRepository();
      final lang = MockLanguagePreferenceService();
      when(lang.getStudyContentLanguage())
          .thenAnswer((_) async => AppLanguage.english);
      when(lang.getSelectedLanguage())
          .thenAnswer((_) async => AppLanguage.english);
      if (sl.isRegistered<CommunityRepository>()) {
        sl.unregister<CommunityRepository>();
      }
      if (sl.isRegistered<LanguagePreferenceService>()) {
        sl.unregister<LanguagePreferenceService>();
      }
      sl.registerLazySingleton<CommunityRepository>(() => repo);
      sl.registerLazySingleton<LanguagePreferenceService>(() => lang);
    });

    Future<void> pumpSection(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: HomeCommunitySection()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('not in a fellowship and none to suggest: browse row',
        (tester) async {
      when(repo.getFellowships(any)).thenAnswer((_) async => const Right([]));
      when(repo.discoverFellowships()).thenAnswer((_) async =>
          const Right(DiscoverPage(fellowships: [], hasMore: false)));
      await pumpSection(tester);
      expect(find.text('Find your fellowship'), findsOneWidget);
      expect(find.text('Browse fellowships'), findsOneWidget);
    });

    testWidgets('member with no posts: activity header and empty row',
        (tester) async {
      when(repo.getFellowships(any)).thenAnswer((_) async => const Right([
            FellowshipEntity(
              id: 'f1',
              name: 'Young Adults',
              memberCount: 4,
              userRole: 'member',
              joinedAt: '2026-01-01T00:00:00Z',
              createdAt: '2026-01-01T00:00:00Z',
            ),
          ]));
      when(repo.getFellowshipPosts(
              fellowshipId: anyNamed('fellowshipId'), limit: anyNamed('limit')))
          .thenAnswer((_) async => const Right([]));
      await pumpSection(tester);
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('No posts yet'), findsOneWidget);
    });

    testWidgets('after a join, home stops offering the group it joined',
        (tester) async {
      const group = FellowshipEntity(
        id: 'f1',
        name: 'Disciplefy',
        memberCount: 2,
        userRole: 'member',
        joinedAt: '2026-09-29T00:00:00Z',
        createdAt: '2026-09-29T00:00:00Z',
      );
      var joined = false;
      when(repo.getFellowships(any))
          .thenAnswer((_) async => Right(joined ? const [group] : const []));
      when(repo.discoverFellowships()).thenAnswer((_) async =>
          const Right(DiscoverPage(fellowships: [], hasMore: false)));
      when(repo.getFellowshipPosts(
              fellowshipId: anyNamed('fellowshipId'), limit: anyNamed('limit')))
          .thenAnswer((_) async => const Right([]));

      await pumpSection(tester);
      expect(find.text('Find your fellowship'), findsOneWidget);

      joined = true;
      FellowshipChanges.instance.notifyChanged();
      await tester.pumpAndSettle();

      expect(find.text('Find your fellowship'), findsNothing);
      expect(find.text('Recent activity'), findsOneWidget);
    });

    testWidgets('lookup failure renders nothing (never invite a member)',
        (tester) async {
      when(repo.getFellowships(any))
          .thenAnswer((_) async => const Left(ServerFailure()));
      await pumpSection(tester);
      expect(find.byKey(const Key('home_activity_empty_row')), findsNothing);
      expect(find.text('Find your fellowship'), findsNothing);
    });
  });
}
