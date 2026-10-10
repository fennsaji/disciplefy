import 'package:flutter/gestures.dart';
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

  testWidgets(
      'scrolling to the bottom and back renders every paragraph once, in '
      'order, with tappable scripture links', (tester) async {
    final guide = _longGuide('order');
    final controller = await pumpGuide(tester, guide);

    // Every paragraph the guide holds, top to bottom.
    final expected = <String>[
      for (final name in ['summary', 'context'])
        for (var i = 0; i < (name == 'summary' ? 8 : 12); i++)
          _mlParagraph('order-$name', i),
      for (var i = 0; i < 40; i++) _mlParagraph('order-interpretation', i),
      for (var i = 0; i < 15; i++) _mlParagraph('order-verse', i),
      for (var i = 0; i < 10; i++) _mlParagraph('order-question', i),
      for (var i = 0; i < 8; i++) _mlParagraph('order-prayer', i),
    ];
    final firstSeen = <String, int>{};
    var linksSeen = 0;

    // Markdown renders selectable text: one SelectableText per paragraph or
    // list item.
    List<InlineSpan> spans() => [
          for (final t
              in tester.widgetList<SelectableText>(find.byType(SelectableText)))
            t.textSpan ?? TextSpan(text: t.data),
        ];

    Future<void> look() async {
      final texts = spans().map((s) => s.toPlainText()).toList();
      for (final p in expected) {
        final hits = texts.where((t) => t.contains(p)).length;
        expect(hits, lessThanOrEqualTo(1), reason: 'duplicated: $p');
        if (hits == 1) firstSeen.putIfAbsent(p, () => firstSeen.length);
      }
      for (final root in spans()) {
        root.visitChildren((span) {
          if (span is TextSpan &&
              span.recognizer is TapGestureRecognizer &&
              (span.text ?? '').contains(':')) {
            linksSeen++;
          }
          return true;
        });
      }
    }

    for (var down = true;; down = !down) {
      while (true) {
        await look();
        final pos = controller.position;
        if (down ? pos.pixels >= pos.maxScrollExtent : pos.pixels <= 0) {
          break;
        }
        controller.jumpTo(
            (pos.pixels + (down ? 300 : -300)).clamp(0.0, pos.maxScrollExtent));
        await tester.pump();
      }
      if (!down) break;
    }

    final missing = expected.where((p) => !firstSeen.containsKey(p));
    expect(missing, isEmpty, reason: 'never rendered: ${missing.take(3)}');
    final order = firstSeen.keys.toList();
    expect(order, expected, reason: 'paragraphs rendered out of order');
    expect(linksSeen, greaterThan(0), reason: 'no tappable scripture links');
  });

  testWidgets(
      'paragraphs either side of a block split are spaced like any other '
      'paragraphs', (tester) async {
    final guide = _longGuide('gap');
    final controller = await pumpGuide(tester, guide);
    final parts = chunkSectionMarkdown(guide.summary);
    expect(parts.length, greaterThan(1));
    // The last paragraph of the first block and the first of the second.
    final split = '\n\n'.allMatches(parts.first).length + 1;

    Rect rectOf(int i) => tester.getRect(find.byWidgetPredicate((w) =>
        w is SelectableText &&
        (w.textSpan?.toPlainText() ?? w.data ?? '')
            .contains(_mlParagraph('gap-summary', i))));

    Future<double> gapAfter(int i) async {
      // Bring the pair on screen.
      while (find
          .byWidgetPredicate((w) =>
              w is SelectableText &&
              (w.textSpan?.toPlainText() ?? w.data ?? '')
                  .contains(_mlParagraph('gap-summary', i + 1)))
          .evaluate()
          .isEmpty) {
        controller.jumpTo(controller.offset + 200);
        await tester.pump();
      }
      return rectOf(i + 1).top - rectOf(i).bottom;
    }

    final within = await gapAfter(0);
    final across = await gapAfter(split - 1);
    expect(within, greaterThan(0));
    expect(across, moreOrLessEquals(within, epsilon: 0.5));
  });
}
