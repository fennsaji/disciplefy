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
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/audio_practice_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/cloze_review_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/word_bank_practice_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/word_scramble_practice_page.dart';
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

/// Phrase scramble, word bank, fill in the blanks and audio practice modes:
/// light + dark rendering, 320pt width with long Hindi/Malayalam text, and
/// that the restyled controls still drive the same scoring and navigation.
void main() {
  late MockTranslationService translations;
  late MockWalkthroughRepository walkthrough;
  late _MockMemoryVerseBloc bloc;
  var language = AppLanguage.english;
  final epoch = DateTime(2026, 9);
  PracticeResultParams? results;

  MemoryVerseEntity verse({
    required String reference,
    required String text,
    String language = 'en',
  }) =>
      MemoryVerseEntity(
        id: 'v1',
        verseReference: reference,
        verseText: text,
        language: language,
        sourceType: 'manual',
        easeFactor: 2.5,
        intervalDays: 3,
        repetitions: 2,
        nextReviewDate: epoch,
        addedDate: epoch,
        totalReviews: 2,
        createdAt: epoch,
      );

  final englishVerse = verse(
    reference: 'Philippians 4:13',
    text: 'I can do all things through him who strengthens me.',
  );

  final malayalamVerse = verse(
    reference: 'യോഹന്നാൻ 3:16',
    text: 'തന്റെ ഏകജാതനായ പുത്രനിൽ വിശ്വസിക്കുന്ന ഏവനും '
        'നശിച്ചുപോകാതെ നിത്യജീവൻ പ്രാപിക്കേണ്ടതിന്നു ദൈവം അവനെ '
        'നൽകുവാൻ തക്കവണ്ണം ലോകത്തെ സ്നേഹിച്ചു.',
    language: 'ml',
  );

  final hindiVerse = verse(
    reference: 'यूहन्ना 3:16',
    text: 'क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उस ने अपना '
        'एकलौता पुत्र दे दिया, ताकि जो कोई उस पर विश्वास करे, वह '
        'नाश न हो, परन्तु अनन्त जीवन पाए।',
    language: 'hi',
  );

  String resolve(String key, Map<dynamic, dynamic>? args) {
    dynamic lookup(AppLanguage lang) {
      dynamic value = AppTranslations.translations[lang];
      for (final part in key.split('.')) {
        value = value is Map ? value[part] : null;
      }
      return value;
    }

    final value = lookup(language) ?? lookup(AppLanguage.english);
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
    if (sl.isRegistered<TranslationService>()) {
      sl.unregister<TranslationService>();
    }
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
    final loaded = DueVersesLoaded(
      verses: [verse ?? englishVerse],
      statistics: const ReviewStatisticsEntity(
        totalVerses: 1,
        dueVerses: 1,
        reviewedToday: 0,
        upcomingReviews: 0,
        masteredVerses: 0,
        fullyMasteredVerses: 0,
      ),
    );
    // Audio mode only picks the verse up from an emitted state (it always
    // dispatches LoadDueVerses first), so emit the loaded state once too.
    whenListen<MemoryVerseState>(
      bloc,
      Stream<MemoryVerseState>.value(loaded),
      initialState: loaded,
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

  /// A bottom-bar action by its label: it shows as a labelled pill or, on
  /// narrow screens, as an icon circle whose label is the tooltip.
  Finder action(String label) =>
      find.byWidgetPredicate((w) => w is MemoryActionPill && w.label == label);

  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.ensureVisible(action(label));
    await tester.tap(action(label));
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  final modes = <String, Widget Function()>{
    'phrase scramble': () => const WordScramblePracticePage(verseId: 'v1'),
    'word bank': () => const WordBankPracticePage(verseId: 'v1'),
    'fill in the blanks': () => const ClozeReviewPage(verseId: 'v1'),
    'audio': () => const AudioPracticePage(verseId: 'v1'),
  };

  group('renders without overflow', () {
    for (final entry in modes.entries) {
      for (final brightness in Brightness.values) {
        testWidgets('${entry.key} · ${brightness.name}', (tester) async {
          await pumpMode(tester, entry.value(), brightness: brightness);
          expect(tester.takeException(), isNull);
          expect(
              find.text(
                  'Philippians 4:13 · ${entry.key == 'audio' ? 'Hard' : 'Medium'}'),
              findsOneWidget);
          await unmount(tester);
        });
      }

      for (final sample in {'ml': malayalamVerse, 'hi': hindiVerse}.entries) {
        testWidgets('${entry.key} · 320x640 · ${sample.key}', (tester) async {
          language =
              sample.key == 'ml' ? AppLanguage.malayalam : AppLanguage.hindi;
          await pumpMode(
            tester,
            entry.value(),
            verse: sample.value,
            size: const Size(320, 640),
          );
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('restored instructions', () {
    testWidgets('word bank shows its instruction', (tester) async {
      await pumpMode(tester, const WordBankPracticePage(verseId: 'v1'));
      expect(find.text('Tap words in order to form the verse'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('phrase scramble shows its instruction and phrase count',
        (tester) async {
      await pumpMode(tester, const WordScramblePracticePage(verseId: 'v1'));
      expect(find.text('Arrange phrases in correct order'), findsOneWidget);
      expect(find.textContaining('(4)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hint count stays visible on the compact hint circle',
        (tester) async {
      await pumpMode(tester, const WordBankPracticePage(verseId: 'v1'),
          size: const Size(320, 640));
      await tapAction(tester, 'Hint');
      final hint = tester.widget<MemoryActionPill>(action('Hint · 1'));
      if (hint.iconOnly) expect(find.text('1'), findsWidgets);
      expect(hint.badge, '1');
      await unmount(tester);
    });
  });

  group('phrase scramble', () {
    testWidgets('tapping phrases in order scores 100 and submits',
        (tester) async {
      await pumpMode(tester, const WordScramblePracticePage(verseId: 'v1'));

      // "I can do all" · "things through him who" · "strengthens me." ·
      // "Philippians 4:13" (reference is part of the answer).
      for (final phrase in [
        'I can do all',
        'things through him who',
        'strengthens me.',
        'Philippians 4:13',
      ]) {
        await tapText(tester, phrase);
      }
      await tapText(tester, 'Submit');
      await tester.pumpAndSettle();

      expect(find.text('results'), findsOneWidget);
      expect(results!.practiceMode, 'word_scramble');
      expect(results!.accuracyPercentage, 100);
      expect(results!.hintsUsed, 0);
      expect(results!.showedAnswer, isFalse);
      await unmount(tester);
    });

    testWidgets('line breaks and double spaces never reach the phrases',
        (tester) async {
      await pumpMode(
        tester,
        const WordScramblePracticePage(verseId: 'v1'),
        verse: verse(
          reference: 'Philippians 4:13',
          text: 'I can  do all\nthings through him who strengthens me.',
        ),
      );
      for (final phrase in [
        'I can do all',
        'things through him who',
        'strengthens me.',
        'Philippians 4:13',
      ]) {
        await tapText(tester, phrase);
      }
      await tapText(tester, 'Submit');
      await tester.pumpAndSettle();
      expect(results!.accuracyPercentage, 100);
      expect(
        results!.blankComparisons!.map((c) => c.userInput),
        everyElement(isNot(matches(RegExp(r'\s{2}|\n')))),
      );
      await unmount(tester);
    });

    testWidgets('hint places the next phrase and counts on the pill',
        (tester) async {
      await pumpMode(tester, const WordScramblePracticePage(verseId: 'v1'));

      await tapAction(tester, 'Hint');
      expect(action('Hint · 1'), findsOneWidget);
      // Submit stays disabled until every slot is filled.
      final submit = tester.widget<TextButton>(find.ancestor(
          of: find.text('Submit'), matching: find.byType(TextButton)));
      expect(submit.onPressed, isNull);
      await unmount(tester);
    });

    testWidgets('show answer submits as answer shown with 0 accuracy',
        (tester) async {
      await pumpMode(tester, const WordScramblePracticePage(verseId: 'v1'));

      await tester.tap(find.byTooltip('Show answer'));
      await tester.pump();
      await tapText(tester, 'Submit');
      await tester.pumpAndSettle();

      expect(results!.showedAnswer, isTrue);
      expect(results!.accuracyPercentage, 0);
      await unmount(tester);
    });
  });

  group('word bank', () {
    testWidgets('tapping words in order scores 100', (tester) async {
      await pumpMode(tester, const WordBankPracticePage(verseId: 'v1'));

      for (final word in 'I can do all things through him who strengthens me. '
              'Philippians 4:13'
          .split(' ')) {
        await tapText(tester, word);
      }
      await tapText(tester, 'Submit');
      await tester.pumpAndSettle();

      expect(results!.practiceMode, 'word_bank');
      expect(results!.accuracyPercentage, 100);
      expect(results!.hintsUsed, 0);
      await unmount(tester);
    });

    testWidgets('tapping a placed word returns it; clear empties the answer',
        (tester) async {
      await pumpMode(tester, const WordBankPracticePage(verseId: 'v1'));

      await tapText(tester, 'things');
      // Placed in the answer, removed from the bank.
      expect(find.text('things'), findsOneWidget);
      await tapText(tester, 'things');
      expect(find.text('things'), findsOneWidget);

      await tapText(tester, 'can');
      await tapAction(tester, 'Clear');
      expect(find.text('can'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an empty bank shows a note instead of a bare label',
        (tester) async {
      await pumpMode(tester, const WordBankPracticePage(verseId: 'v1'));
      final note = find.byKey(const Key('word_bank_all_placed'));
      expect(note, findsNothing);

      for (final word in 'I can do all things through him who strengthens me. '
              'Philippians 4:13'
          .split(' ')) {
        await tapText(tester, word);
      }
      expect(note, findsOneWidget);
      expect(
          find.text('All words placed. Tap a word in your answer to put it '
              'back.'),
          findsOneWidget);

      // The note's promise holds: tapping a placed word returns it.
      await tapText(tester, 'things');
      expect(note, findsNothing);
      expect(find.text('things'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('show answer submits immediately', (tester) async {
      await pumpMode(tester, const WordBankPracticePage(verseId: 'v1'));

      await tapAction(tester, 'Hint');
      expect(action('Hint · 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Show answer'));
      await tester.pumpAndSettle();

      expect(results!.showedAnswer, isTrue);
      expect(results!.accuracyPercentage, 0);
      expect(results!.hintsUsed, 1);
      await unmount(tester);
    });
  });

  group('fill in the blanks', () {
    testWidgets('check is disabled until every blank is filled',
        (tester) async {
      await pumpMode(tester, const ClozeReviewPage(verseId: 'v1'));

      final fields = find.byType(TextField);
      final blankCount = fields.evaluate().length;
      expect(blankCount, greaterThanOrEqualTo(2));
      TextButton check() => tester.widget<TextButton>(find.ancestor(
          of: find.text('Check'), matching: find.byType(TextButton)));
      expect(check().onPressed, isNull);

      for (var i = 0; i < blankCount; i++) {
        await tester.enterText(fields.at(i), 'zzz');
        await tester.pump();
      }
      await tester.pump();
      expect(check().onPressed, isNotNull);

      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(results!.practiceMode, 'cloze');
      expect(results!.showedAnswer, isFalse);
      expect(results!.blankComparisons, hasLength(blankCount));
      expect(results!.blankComparisons!.every((c) => c.userInput == 'zzz'),
          isTrue);
      await unmount(tester);
    });

    testWidgets('show answer fills blanks and scores as answer shown',
        (tester) async {
      await pumpMode(tester, const ClozeReviewPage(verseId: 'v1'));

      await tapAction(tester, 'Show answer');
      await tapText(tester, 'Check');
      await tester.pumpAndSettle();

      expect(results!.showedAnswer, isTrue);
      expect(results!.accuracyPercentage, 0);
      // Comparisons keep what the user had typed (nothing).
      expect(results!.blankComparisons!.every((c) => c.userInput == '(empty)'),
          isTrue);
      await unmount(tester);
    });

    testWidgets('difficulty control rebuilds the blanks', (tester) async {
      // 24 blankable words: easy 1 in 5 → 5, medium 1 in 4 → 6,
      // hard 1 in 3 → 8.
      await pumpMode(
        tester,
        const ClozeReviewPage(verseId: 'v1'),
        verse: verse(
          reference: 'Test 1:1',
          text: 'Blessed peacemakers inherit heaven; merciful servants obtain '
              'mercy; humble hearts receive grace; faithful disciples follow '
              'Jesus daily, carrying crosses gladly, rejoicing always forever '
              'amen',
        ),
      );
      expect(find.byType(TextField), findsNWidgets(6));

      await tester.enterText(find.byType(TextField).first, 'typed');
      await tapText(tester, 'Easy');
      expect(find.byType(TextField), findsNWidgets(5));
      // Switching clears what was typed.
      expect(find.text('typed'), findsNothing);

      await tapText(tester, 'Hard');
      expect(find.byType(TextField), findsNWidgets(8));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('audio', () {
    testWidgets('read → speak phase keeps the verse and the mic control',
        (tester) async {
      await pumpMode(tester, const AudioPracticePage(verseId: 'v1'));

      expect(find.text(englishVerse.verseText), findsOneWidget);
      await tapText(tester, 'Ready to speak');

      expect(find.byKey(const ValueKey('audio_record_button')), findsOneWidget);
      expect(find.text('Tap the microphone to start'), findsOneWidget);
      // Check result only appears once something was recorded.
      expect(find.text('Check Result'), findsNothing);
      await unmount(tester);
    });
  });
}
