import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_guide_body.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_reading_tracker.dart';

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => AppLanguage.english;
}

final _guide = StudyGuide(
  id: 'g1',
  input: 'forgiveness',
  inputType: 'topic',
  language: 'en',
  summary: 'Forgiveness is receiving God\'s mercy and passing it on.',
  interpretation: 'Interpretation text.',
  context: 'In Matthew 18 Jesus answers Peter\'s question.',
  relatedVerses: const ['Luke 23:34'],
  reflectionQuestions: const ['Is forgiving the same as trusting again?'],
  prayerPoints: const ['Help me release those who hurt me.'],
  createdAt: DateTime(2026),
);

Widget _app(Widget child, {required bool dark}) => MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void _useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Segments drawn in gold.
int _filledSegments(WidgetTester tester, Color gold) => tester
    .widgetList<Container>(find.descendant(
      of: find.byType(StudyGuideSegmentedProgress),
      matching: find.byType(Container),
    ))
    .where((c) => (c.decoration as BoxDecoration?)?.color == gold)
    .length;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<TranslationService>(
        TranslationService(_FakeLanguageService(), prefs));
  });

  tearDown(() => GetIt.instance.reset());

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';
    final gold = dark ? AppColors.brandGold : AppColors.brandGoldDeep;

    testWidgets('$theme: hero, eyebrow and numbered sections fit 320pt',
        (tester) async {
      _useNarrowPhone(tester);
      final tracker = StudyReadingTracker();
      addTearDown(tracker.dispose);

      await tester.pumpWidget(_app(
        StudyGuideBody(
          studyMode: StudyMode.standard,
          sections: StudyGuideSections.fromStudyGuide(_guide),
          inputType: _guide.inputType,
          title: StudyGuideLayout.displayTitle(_guide.inputType, _guide.input),
          tracker: tracker,
        ),
        dark: dark,
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(StudyGuideHero), findsOneWidget);
      expect(find.text('Forgiveness'), findsOneWidget);
      expect(find.textContaining('TOPIC · STANDARD'), findsOneWidget);
      // Six sections (no passage), numbered 01–06, one segment each.
      expect(find.text('01'), findsOneWidget);
      expect(find.text('06'), findsOneWidget);
      expect(find.text('07'), findsNothing);
      expect(tracker.total, 6);
      expect(
        StudyGuideBody.visibleSectionCount(
          tester.element(find.byType(StudyGuideHero)),
          studyMode: StudyMode.standard,
          sections: StudyGuideSections.fromStudyGuide(_guide),
        ),
        6,
      );
      expect(_filledSegments(tester, gold), 0);

      tracker.seed(2);
      await tester.pump();
      expect(_filledSegments(tester, gold), 2);

      tracker.markComplete();
      await tester.pump();
      expect(_filledSegments(tester, gold), 6);
    });

    testWidgets('$theme: sermon keeps the altar call, numbered in sequence',
        (tester) async {
      _useNarrowPhone(tester);
      await tester.pumpWidget(_app(
        StudyGuideBody(
          studyMode: StudyMode.sermon,
          sections: StudyGuideSections.fromStudyGuide(_guide),
          inputType: _guide.inputType,
          title: 'Forgiveness',
        ),
        dark: dark,
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(AltarCallCard), findsOneWidget);
      expect(find.text('06'), findsOneWidget);
    });

    testWidgets('$theme: the section being read aloud shows the Reading chip',
        (tester) async {
      _useNarrowPhone(tester);
      await tester.pumpWidget(_app(
        StudyGuideBody(
          studyMode: StudyMode.standard,
          sections: StudyGuideSections.fromStudyGuide(_guide),
          inputType: _guide.inputType,
          title: 'Forgiveness',
          readingSectionIndex: 1,
        ),
        dark: dark,
      ));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Reading'), findsOneWidget);
      // The pulsing speaker replaces that section's number.
      expect(find.text('02'), findsNothing);
      expect(find.byIcon(Icons.copy_rounded), findsNWidgets(6));
    });
  }

  testWidgets('tracker counts sections whose top passed the threshold',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tracker = StudyReadingTracker();
    addTearDown(tracker.dispose);

    await tester.pumpWidget(_app(
      StudyGuideBody(
        studyMode: StudyMode.standard,
        sections: StudyGuideSections.fromStudyGuide(_guide),
        inputType: _guide.inputType,
        title: 'Forgiveness',
        tracker: tracker,
      ),
      dark: true,
    ));
    await tester.pump(const Duration(milliseconds: 500));

    tracker.update(thresholdY: 0);
    expect(tracker.readCount, 0);
    tracker.update(thresholdY: 10000);
    expect(tracker.readCount, 6);
    // Never goes back down.
    tracker.update(thresholdY: 0);
    expect(tracker.readCount, 6);
  });

  testWidgets('DisciplerGlyph.onCta picks indigo on dark, white on light',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        DisciplerGlyph.onCta(isDark: true),
        DisciplerGlyph.onCta(isDark: false),
      ]),
    ));
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect((images[0].image as AssetImage).assetName,
        'assets/brand/discipler-glyph-indigo.png');
    expect((images[1].image as AssetImage).assetName,
        'assets/brand/discipler-glyph-white.png');
  });
}
