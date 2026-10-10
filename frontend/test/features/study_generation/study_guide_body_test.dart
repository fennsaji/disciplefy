import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_stream_event.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/streaming_study_content.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_guide_body.dart';

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => AppLanguage.english;
}

const _screenWidth = 400.0;

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

/// A phone-sized surface, so the width assertions mean what they say.
void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(_screenWidth, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// What the finished screen renders above the end-of-guide blocks. The body
/// is full-bleed (hero photo) and pads its own sections.
Widget _finishedBody(StudyGuide guide, StudyMode mode) => CustomScrollView(
      slivers: [
        StudyGuideBody(
          studyMode: mode,
          sections: StudyGuideSections.fromStudyGuide(guide),
          inputType: guide.inputType,
          title: StudyGuideLayout.displayTitle(guide.inputType, guide.input),
        ),
      ],
    );

void main() {
  final guide = StudyGuide(
    id: 'g1',
    input: 'John 3:16',
    inputType: 'scripture',
    language: 'en',
    summary: 'God so loved the world.',
    interpretation: 'Interpretation text.',
    context: 'Context text.',
    relatedVerses: const ['Romans 5:8'],
    reflectionQuestions: const ['What does love cost?'],
    prayerPoints: const ['Thank God for his love.'],
    createdAt: DateTime(2026),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<TranslationService>(
        TranslationService(_FakeLanguageService(), prefs));
  });

  tearDown(() => GetIt.instance.reset());

  for (final mode in StudyMode.values) {
    testWidgets(
        '${mode.name}: loading and finished views put the title card and first '
        'section in the same place', (tester) async {
      _usePhoneSize(tester);
      final streaming = StreamingStudyGuideContent(
        summary: guide.summary,
        sectionsLoaded: 1,
      );

      await tester.pumpWidget(_app(StreamingStudyContent(
        content: streaming,
        inputType: guide.inputType,
        inputValue: guide.input,
        language: 'en',
        studyMode: mode,
      )));
      await tester.pump(const Duration(milliseconds: 500));
      final loadingTitle = tester.getRect(find.byType(StudyGuideTopicTitle));
      final loadingFirstCard =
          tester.getRect(find.byType(StudySectionCard).first);

      await tester.pumpWidget(_app(_finishedBody(guide, mode)));
      await tester.pump(const Duration(milliseconds: 500));
      final finishedTitle = tester.getRect(find.byType(StudyGuideTopicTitle));
      final finishedFirstCard =
          tester.getRect(find.byType(StudySectionCard).first);

      // Same place on both sides of the stream completing. The progress line
      // floats over the hero, so even the vertical position must match.
      expect(loadingTitle.left, StudyGuideLayout.sidePadding.left);
      expect(loadingTitle.width,
          _screenWidth - StudyGuideLayout.sidePadding.horizontal);
      expect(finishedTitle.left, loadingTitle.left);
      expect(finishedTitle.width, loadingTitle.width);
      expect(finishedFirstCard.left, loadingFirstCard.left);
      expect(finishedFirstCard.width, loadingFirstCard.width);
      expect(finishedTitle.top, loadingTitle.top);
      expect(finishedFirstCard.top, loadingFirstCard.top);
    });
  }

  testWidgets('sections not yet streamed show a shimmer', (tester) async {
    await tester.pumpWidget(_app(StreamingStudyContent(
      content:
          StreamingStudyGuideContent(summary: guide.summary, sectionsLoaded: 1),
      inputType: guide.inputType,
      inputValue: guide.input,
      language: 'en',
    )));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(StudySectionCard), findsOneWidget);
    expect(find.byType(StudySectionShimmer), findsWidgets);
  });

  testWidgets('a partial stream shows what arrived and no shimmer',
      (tester) async {
    await tester.pumpWidget(_app(StreamingStudyContent(
      content:
          StreamingStudyGuideContent(summary: guide.summary, sectionsLoaded: 1),
      inputType: guide.inputType,
      inputValue: guide.input,
      language: 'en',
      isPartial: true,
    )));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(StudySectionCard), findsOneWidget);
    expect(find.byType(StudySectionShimmer), findsNothing);
  });

  testWidgets('a finished guide never shows a shimmer', (tester) async {
    // Tall enough that the lazily built list builds every section.
    tester.view.physicalSize = const Size(_screenWidth, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_finishedBody(guide, StudyMode.standard)));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(StudySectionShimmer), findsNothing);
    // Summary, context, interpretation, verses, questions, prayer; no passage.
    expect(find.byType(StudySectionCard), findsNWidgets(6));
  });
}
