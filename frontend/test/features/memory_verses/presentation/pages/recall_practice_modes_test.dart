import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/app_translations.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_result_params.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/review_statistics_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/first_letter_hints_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/progressive_reveal_practice_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/type_it_out_practice_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/verse_review_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/self_assessment_bottom_sheet.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import 'memory_verses_reset_flow_test.mocks.dart';

class _MockMemoryVerseBloc extends MockBloc<MemoryVerseEvent, MemoryVerseState>
    implements MemoryVerseBloc {}

/// Recall practice modes: flip card, progressive reveal, first letter hints
/// and type it out. Covers light + dark rendering, 320pt width with long
/// Malayalam text, and that the restyled controls still drive the same
/// behaviour (flip, reveal, hint accounting, results navigation).
void main() {
  late MockTranslationService translations;
  late MockWalkthroughRepository walkthrough;
  late _MockMemoryVerseBloc bloc;
  var language = AppLanguage.english;
  final epoch = DateTime(2026, 9);
  PracticeResultParams? results;

  final englishVerse = MemoryVerseEntity(
    id: 'v1',
    verseReference: 'Philippians 4:13',
    verseText: 'I can do all things through him who strengthens me.',
    language: 'en',
    sourceType: 'manual',
    easeFactor: 2.5,
    intervalDays: 3,
    repetitions: 2,
    nextReviewDate: epoch,
    addedDate: epoch,
    totalReviews: 2,
    createdAt: epoch,
  );

  final malayalamVerse = MemoryVerseEntity(
    id: 'v1',
    verseReference: 'യോഹന്നാൻ 3:16',
    verseText: 'തന്റെ ഏകജാതനായ പുത്രനിൽ വിശ്വസിക്കുന്ന ഏവനും '
        'നശിച്ചുപോകാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിന്നു ദൈവം അവനെ '
        'നൽകുവാൻ തക്കവണ്ണം ലോകത്തെ സ്നേഹിച്ചു.',
    language: 'ml',
    sourceType: 'manual',
    easeFactor: 2.5,
    intervalDays: 12,
    repetitions: 5,
    nextReviewDate: epoch,
    addedDate: epoch,
    totalReviews: 5,
    createdAt: epoch,
  );

  String resolve(String key, Map<dynamic, dynamic>? args) {
    dynamic value = AppTranslations.translations[language];
    for (final part in key.split('.')) {
      value = value is Map ? value[part] : null;
    }
    if (value is! String) {
      value = AppTranslations.translations[AppLanguage.english];
      for (final part in key.split('.')) {
        value = value is Map ? value[part] : null;
      }
    }
    var text = value is String ? value : key.split('.').last;
    args?.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    return text;
  }

  setUpAll(() {
    translations = MockTranslationService();
    when(translations.getTranslation(any, any)).thenAnswer((i) => resolve(
        i.positionalArguments[0] as String,
        i.positionalArguments.length > 1
            ? i.positionalArguments[1] as Map<dynamic, dynamic>?
            : null));
    sl.registerLazySingleton<TranslationService>(() => translations);
  });

  tearDownAll(() => sl.reset());

  setUp(() {
    language = AppLanguage.english;
    results = null;
    walkthrough = MockWalkthroughRepository();
    when(walkthrough.hasSeen(any)).thenAnswer((_) async => true);
    if (sl.isRegistered<WalkthroughRepository>()) {
      sl.unregister<WalkthroughRepository>();
    }
    sl.registerLazySingleton<WalkthroughRepository>(() => walkthrough);
  });

  Future<void> pumpMode(
    WidgetTester tester,
    Widget page, {
    MemoryVerseEntity? verse,
    Brightness brightness = Brightness.dark,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bloc = _MockMemoryVerseBloc();
    whenListen<MemoryVerseState>(
      bloc,
      const Stream<MemoryVerseState>.empty(),
      initialState: DueVersesLoaded(
        verses: [verse ?? englishVerse],
        statistics: const ReviewStatisticsEntity(
          totalVerses: 1,
          dueVerses: 1,
          reviewedToday: 0,
          upcomingReviews: 0,
          masteredVerses: 0,
          fullyMasteredVerses: 0,
        ),
      ),
    );

    final router = GoRouter(
      initialLocation: '/mode',
      routes: [
        GoRoute(
          path: '/mode',
          builder: (_, __) =>
              BlocProvider<MemoryVerseBloc>.value(value: bloc, child: page),
        ),
        GoRoute(
          path: AppRoutes.practiceResults,
          builder: (_, state) {
            results = state.extra as PracticeResultParams?;
            return const Scaffold(body: Text('results'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Unmount so the pages' periodic timers are cancelled.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  final modes = <String, Widget Function()>{
    'flip card': () => const VerseReviewPage(verseId: 'v1'),
    'progressive reveal': () =>
        const ProgressiveRevealPracticePage(verseId: 'v1'),
    'first letter hints': () => const FirstLetterHintsPage(verseId: 'v1'),
    'type it out': () => const TypeItOutPracticePage(verseId: 'v1'),
  };

  group('renders', () {
    for (final entry in modes.entries) {
      for (final brightness in Brightness.values) {
        testWidgets('${entry.key} in ${brightness.name} mode', (tester) async {
          await pumpMode(tester, entry.value(), brightness: brightness);
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Philippians 4:13'), findsWidgets);
          expect(find.byIcon(Icons.close_rounded), findsOneWidget);
          await unmount(tester);
        });
      }

      testWidgets('${entry.key} fits 320x640 with Malayalam text',
          (tester) async {
        language = AppLanguage.malayalam;
        await pumpMode(
          tester,
          entry.value(),
          verse: malayalamVerse,
          size: const Size(320, 640),
        );
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });

  group('flip card', () {
    testWidgets('flip shows the verse, submit opens self-assessment',
        (tester) async {
      await pumpMode(tester, modes['flip card']!());
      expect(find.text(englishVerse.verseText), findsNothing);

      await tester.tap(find.text('Flip card'));
      await tester.pumpAndSettle();
      expect(find.text(englishVerse.verseText), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.byType(SelfAssessmentBottomSheet), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('rating sheet asks how well it was recalled; pick submits',
        (tester) async {
      await pumpMode(tester, modes['flip card']!());
      await tester.tap(find.text('Flip card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('How well did you recall it?'), findsOneWidget);
      expect(
          find.text('Be honest — this sets your next review'), findsOneWidget);
      await tester.tap(find.text('Knew it perfectly'));
      await tester.pumpAndSettle();
      expect(results?.practiceMode, 'flip_card');
      expect(results?.qualityRating, 5);
      expect(results?.accuracyPercentage, 100);
      await unmount(tester);
    });

    testWidgets('back side fits 320x640 with Malayalam text', (tester) async {
      language = AppLanguage.malayalam;
      await pumpMode(tester, modes['flip card']!(),
          verse: malayalamVerse, size: const Size(320, 640));
      await tester.tap(find.text('കാർഡ് മറിക്കുക'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(malayalamVerse.verseText), findsOneWidget);
      await unmount(tester);
    });
  });

  group('progressive reveal', () {
    testWidgets('reveal next, reveal all, then submit', (tester) async {
      await pumpMode(tester, modes['progressive reveal']!());
      // 10 verse words + 2 reference words.
      expect(find.text('1 of 12 words'), findsOneWidget);

      await tester.tap(find.text('Reveal next'));
      await tester.pump();
      expect(find.text('2 of 12 words'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pump();
      expect(find.text('12 of 12 words'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.byType(SelfAssessmentBottomSheet), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('walkthrough steps through all four targets', (tester) async {
      when(walkthrough.hasSeen(any)).thenAnswer((_) async => false);
      when(walkthrough.markSeen(any)).thenAnswer((_) async {});
      await pumpMode(tester, modes['progressive reveal']!());
      // Showcase tooltips animate continuously; use fixed pumps.
      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.pump(const Duration(milliseconds: 700));
      await settle();
      for (var step = 1; step <= 4; step++) {
        expect(find.text('$step / 4'), findsOneWidget);
        await tester.tap(find.textContaining('Got it').last);
        await settle();
      }
      expect(tester.takeException(), isNull);
      verify(walkthrough.markSeen(any)).called(1);
      await unmount(tester);
    });

    testWidgets('phrase mode resets progress', (tester) async {
      await pumpMode(tester, modes['progressive reveal']!());
      await tester.tap(find.text('Reveal next'));
      await tester.pump();

      await tester.tap(find.text('Phrase by phrase'));
      await tester.pump();
      expect(find.textContaining('phrases'), findsOneWidget);
      expect(find.textContaining('1 of'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('first letter hints', () {
    testWidgets('tile tap and Hint both count hints; Check goes to results',
        (tester) async {
      await pumpMode(tester, modes['first letter hints']!());
      expect(find.text('Hints used 0/12'), findsOneWidget);

      // First tile is the "I" of "I can do all things…".
      await tester.tap(find.text('I').first);
      await tester.pump();
      expect(find.text('Hints used 1/12'), findsOneWidget);

      await tester.tap(find.text('Hint'));
      await tester.pump();
      expect(find.text('can'), findsOneWidget);
      expect(find.text('Hints used 2/12'), findsOneWidget);

      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(results?.practiceMode, 'first_letter');
      expect(results?.hintsUsed, 2);
      expect(results?.accuracyPercentage, closeTo(10 / 12 * 100, 0.01));
    });
  });

  group('type it out', () {
    testWidgets('submit is disabled until text is typed', (tester) async {
      await pumpMode(tester, modes['type it out']!());
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(results, isNull);

      await tester.enterText(find.byType(TextField), 'I can do all things');
      await tester.pump();
      expect(find.text('5 / 12 words'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(results?.practiceMode, 'type_it_out');
      expect(results?.showedAnswer, isFalse);
    });

    testWidgets('Answer submits with showedAnswer', (tester) async {
      await pumpMode(tester, modes['type it out']!());
      await tester.tap(find.byWidgetPredicate(
          (w) => w is MemoryActionPill && w.label == 'Answer'));
      await tester.pumpAndSettle();
      expect(results?.practiceMode, 'type_it_out');
      expect(results?.showedAnswer, isTrue);
    });

    testWidgets('field adds no padding of its own inside the card',
        (tester) async {
      await pumpMode(tester, modes['type it out']!());
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.contentPadding, EdgeInsets.zero);
      // Text starts at the card's own inset, like every other card.
      final card = tester.getTopLeft(find.byType(MemoryAnswerCard));
      final text = tester.getTopLeft(find.byType(EditableText));
      expect(text.dx - card.dx, lessThanOrEqualTo(20));
      await unmount(tester);
    });

    testWidgets('shows the type-from-memory instruction', (tester) async {
      await pumpMode(tester, modes['type it out']!());
      expect(find.text('Type the verse from memory'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Clear empties the field', (tester) async {
      await pumpMode(tester, modes['type it out']!());
      await tester.enterText(find.byType(TextField), 'I can');
      await tester.pump();
      await tester.tap(find.byWidgetPredicate(
          (w) => w is MemoryActionPill && w.label == 'Clear'));
      await tester.pump();
      expect(find.text('0 / 12 words'), findsOneWidget);
      await unmount(tester);
    });
  });
}
