import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_guide_body.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_reading_tracker.dart';
import 'package:disciplefy_bible_study/shared/widgets/markdown_with_scripture.dart';

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => AppLanguage.english;
}

/// A long Malayalam paragraph with a scripture reference, ~450 characters.
String _mlParagraph(String tag, int i) =>
    '$tag $i. ദൈവം ലോകത്തെ ഇത്രയധികം സ്നേഹിച്ചതിനാൽ തന്റെ ഏകജാതനായ പുത്രനെ '
    'നൽകി (യോഹന്നാൻ 3:16). അവനിൽ വിശ്വസിക്കുന്ന ഏവനും നശിച്ചുപോകാതെ '
    'നിത്യജീവൻ പ്രാപിക്കേണ്ടതിനു തന്നേ. ഈ സ്നേഹം നമ്മുടെ യോഗ്യതയെ '
    'ആശ്രയിക്കുന്നില്ല; അത് ദൈവത്തിന്റെ കൃപയാണ് (റോമർ 5:8). ക്രിസ്തു '
    'നമുക്കുവേണ്ടി മരിച്ചതിനാൽ ദൈവം നമ്മോടുള്ള തന്റെ സ്നേഹം '
    'പ്രദർശിപ്പിക്കുന്നു, അതുകൊണ്ട് നാം അനുതപിച്ച് അവനിലേക്ക് തിരിയുന്നു.';

/// A Deep Dive guide about forty screens long: every section long, the
/// interpretation forty paragraphs.
StudyGuide _longGuide(String tag) {
  String paragraphs(String name, int n) =>
      [for (var i = 0; i < n; i++) _mlParagraph('$tag-$name', i)].join('\n\n');
  return StudyGuide(
    id: 'long-$tag',
    input: 'യോഹന്നാൻ 3:16',
    inputType: 'scripture',
    language: 'ml',
    summary: paragraphs('summary', 8),
    context: paragraphs('context', 12),
    interpretation: paragraphs('interpretation', 40),
    relatedVerses: [
      for (var i = 0; i < 15; i++) _mlParagraph('$tag-verse', i),
    ],
    reflectionQuestions: [
      for (var i = 0; i < 10; i++) _mlParagraph('$tag-question', i),
    ],
    prayerPoints: [
      for (var i = 0; i < 8; i++) _mlParagraph('$tag-prayer', i),
    ],
    createdAt: DateTime(2026),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<TranslationService>(
        TranslationService(_FakeLanguageService(), prefs));
  });

  tearDown(() => GetIt.instance.reset());

  Future<ScrollController> pumpGuide(
    WidgetTester tester,
    StudyGuide guide, {
    StudyReadingTracker? tracker,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          controller: controller,
          slivers: [
            StudyGuideBody(
              studyMode: StudyMode.deep,
              sections: StudyGuideSections.fromStudyGuide(guide),
              inputType: guide.inputType,
              title: guide.input,
              tracker: tracker,
            ),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    return controller;
  }

  test('long section text splits at paragraph breaks and keeps every word', () {
    final text =
        [for (var i = 0; i < 40; i++) _mlParagraph('split', i)].join('\n\n');
    final parts = chunkSectionMarkdown(text);

    expect(parts.length, greaterThanOrEqualTo(8));
    expect(parts.join('\n\n'), text);
    // Short text stays whole.
    expect(chunkSectionMarkdown('One paragraph.'), ['One paragraph.']);
  });

  test('a list is never split from its items or its heading', () {
    final intro = _mlParagraph('intro', 0) * 3;
    final list = [for (var i = 1; i <= 6; i++) '$i. ${_mlParagraph('q', i)}']
        .join('\n\n');
    final text = '$intro\n\n## Heading\n\n$list';
    final parts = chunkSectionMarkdown(text);

    expect(parts.join('\n\n'), text);
    for (final part in parts) {
      expect(part.trimRight().endsWith('## Heading'), isFalse);
      expect(RegExp(r'^\d+\. ').hasMatch(part), isFalse,
          reason: 'a part must not start in the middle of a list');
    }
  });

  testWidgets('a long guide builds only the blocks near the viewport',
      (tester) async {
    final guide = _longGuide('lazy');
    final totalBlocks = [
      guide.summary,
      guide.context,
      guide.interpretation,
      guide.relatedVerses.join('\n\n'),
    ].map((t) => chunkSectionMarkdown(t).length).reduce((a, b) => a + b);
    StudyGuideBody.debugBlockBuilds = 0;
    MarkdownWithScripture.debugPreprocessCount = 0;

    await pumpGuide(tester, guide);

    expect(totalBlocks, greaterThan(15));
    // Hero plus the first few blocks: one screen and the cache extent.
    expect(StudyGuideBody.debugBlockBuilds, lessThan(6));
    expect(MarkdownWithScripture.debugPreprocessCount, lessThan(6));
    // The interpretation and everything after it are not built yet.
    expect(find.textContaining('lazy-interpretation 0.', findRichText: true),
        findsNothing);
    expect(
        find.textContaining('lazy-prayer', findRichText: true), findsNothing);
  });

  testWidgets('scrolling builds only newly exposed blocks', (tester) async {
    final guide = _longGuide('scroll');
    await pumpGuide(tester, guide);

    // Scroll a screen at a time through the whole guide.
    var builds = 0;
    var steps = 0;
    for (var i = 0; i < 15; i++) {
      StudyGuideBody.debugBlockBuilds = 0;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      builds += StudyGuideBody.debugBlockBuilds;
      steps++;
      // One 600pt drag exposes at most a few ~1200-character blocks; blocks
      // already built are not rebuilt.
      expect(StudyGuideBody.debugBlockBuilds, lessThanOrEqualTo(6),
          reason: 'step $i rebuilt blocks that were already built');
    }
    expect(builds / steps, lessThan(4));

    // A rebuild with the same content reuses the memoised markdown.
    MarkdownWithScripture.debugPreprocessCount = 0;
    await pumpGuide(tester, guide);
    expect(MarkdownWithScripture.debugPreprocessCount, 0);
  });

  testWidgets('progress counts sections passed while they were not built',
      (tester) async {
    final tracker = StudyReadingTracker();
    addTearDown(tracker.dispose);
    final controller =
        await pumpGuide(tester, _longGuide('tracker'), tracker: tracker);
    expect(tracker.total, 6);

    // Jump deep into the guide: the first sections are no longer built.
    controller.jumpTo(controller.position.maxScrollExtent * 0.75);
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(find.textContaining('tracker-summary 0.', findRichText: true),
        findsNothing);

    tracker.update(thresholdY: 300);
    expect(tracker.readCount, greaterThanOrEqualTo(5));
    tracker.update(thresholdY: 300, atBottom: true);
    expect(tracker.readCount, 6);
  });
}
