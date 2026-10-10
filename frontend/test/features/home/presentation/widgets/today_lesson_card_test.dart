import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/domain/utils/lesson_launch_from_summary.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/path_progress_strip.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/today_lesson_card.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/utils/lesson_launch.dart';

import '../../../../helpers/fit_matrix.dart';
import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

const summary4of8 = ActivePathSummary(
  pathId: 'p1',
  title: 'New Believer Essentials',
  description: 'First steps',
  discipleLevel: 'seeker',
  lessonTotal: 8,
  lessonsCompleted: 3,
  next: NextLesson(
    topicId: 't4',
    title: 'Confidence in Your Salvation',
    description: 'Assurance',
    inputType: 'topic',
    number: 4,
    total: 8,
  ),
);

const finishedSummary = ActivePathSummary(
  pathId: 'p1',
  title: 'New Believer Essentials',
  description: 'First steps',
  discipleLevel: 'seeker',
  lessonTotal: 8,
  lessonsCompleted: 8,
);

const mlSummary = ActivePathSummary(
  pathId: 'p1',
  title: 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനങ്ങൾ',
  description: '',
  discipleLevel: '',
  lessonTotal: 8,
  lessonsCompleted: 3,
  next: NextLesson(
    topicId: 't4',
    title: 'നിങ്ങളുടെ രക്ഷയിലുള്ള ഉറപ്പും ദൈവത്തിന്റെ വിശ്വസ്തതയും',
    description: '',
    inputType: 'topic',
    number: 4,
    total: 8,
  ),
);

const hiSummary = ActivePathSummary(
  pathId: 'p1',
  title: 'नए विश्वासी की नींव',
  description: '',
  discipleLevel: '',
  lessonTotal: 8,
  lessonsCompleted: 3,
  next: NextLesson(
    topicId: 't4',
    title: 'अपने उद्धार में भरोसा और परमेश्वर की विश्वासयोग्यता',
    description: '',
    inputType: 'topic',
    number: 4,
    total: 8,
  ),
);

ActivePathSummary _withTotal(ActivePathSummary s, int total, int done) =>
    ActivePathSummary(
      pathId: s.pathId,
      title: s.title,
      description: '',
      discipleLevel: '',
      lessonTotal: total,
      lessonsCompleted: done,
      milestoneNumbers: const [5, 17],
      next: done >= total
          ? null
          : NextLesson(
              topicId: 't',
              title: s.next!.title,
              description: '',
              inputType: 'topic',
              number: done + 1,
              total: total,
            ),
    );

Widget _card(ActivePathSummary summary,
        {VoidCallback? onStart, VoidCallback? onSeePath}) =>
    TodayLessonCard(
        summary: summary,
        mode: StudyMode.standard,
        onStart: onStart ?? () {},
        onChooseNextPath: () {},
        onSeePath: onSeePath ?? () {});

void main() {
  setUpAll(() async {
    await loadAppFonts();
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });
  tearDownAll(sl.reset);

  test('launch location from summary', () {
    final loc = Uri.parse(
        buildLessonLaunchFromSummary(summary4of8, StudyMode.standard, 'en'));
    expect(loc.queryParameters['lesson_number'], '4');
    expect(loc.queryParameters['lesson_total'], '8');
    expect(loc.queryParameters['topic_id'], 't4');
    expect(loc.queryParameters['mode'], 'standard');
  });

  test('launch location from summary matches the path-detail builder', () {
    final path = LearningPathDetail(
      id: 'p1',
      slug: '',
      title: 'New Believer Essentials',
      description: 'First steps',
      iconName: '',
      color: '',
      totalXp: 0,
      estimatedDays: 0,
      discipleLevel: 'seeker',
      topics: [
        for (var i = 1; i <= 8; i++)
          LearningPathTopic(
            position: i,
            isMilestone: false,
            topicId: 't$i',
            title: i == 4 ? 'Confidence in Your Salvation' : 'Lesson $i',
            description: i == 4 ? 'Assurance' : 'd',
            category: 'c',
            xpValue: 50,
          ),
      ],
    );
    final fromDetail = Uri.parse(buildLessonLaunchLocation(
        path: path,
        topic: path.topics[3],
        mode: StudyMode.quick,
        language: 'hi'));
    final fromSummary = Uri.parse(
        buildLessonLaunchFromSummary(summary4of8, StudyMode.quick, 'hi'));
    expect(fromSummary.path, fromDetail.path);
    expect(fromSummary.queryParameters, fromDetail.queryParameters);
  });

  test('launch location needs a next lesson', () {
    expect(
        () => buildLessonLaunchFromSummary(
            finishedSummary, StudyMode.standard, 'en'),
        throwsArgumentError);
  });

  testWidgets('one primary button, no Next: line, chip is a label',
      (tester) async {
    var started = 0;
    await tester.pumpWidget(welcomeApp(
        screen: Scaffold(
      body: TodayLessonCard(
          summary: summary4of8,
          mode: StudyMode.standard,
          onStart: () => started++),
    )));
    expect(find.text('TODAY · LESSON 4'), findsOneWidget);
    expect(find.text('Confidence in Your Salvation'), findsOneWidget);
    expect(find.text('Start lesson 4'), findsOneWidget);
    expect(find.textContaining('Next:'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.getSize(find.byType(FilledButton)).height, 40);
    // The chip is drawn 26px tall in a 40px tap row.
    expect(tester.getSize(find.byKey(const Key('today_mode_chip'))).height, 26);
    expect(
        tester
            .getSize(find
                .ancestor(
                    of: find.byKey(const Key('today_mode_chip')),
                    matching: find.byType(Padding))
                .first)
            .height,
        greaterThanOrEqualTo(40));

    await tester.tap(find.byType(FilledButton));
    expect(started, 1);

    // No picker: tapping the label opens no menu.
    await tester.tap(find.textContaining('Standard'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Read · 3 min'), findsNothing);
    expect(find.byType(PopupMenuButton<StudyMode>), findsNothing);
  });

  testWidgets('chip shows the quick label in quick mode', (tester) async {
    await tester.pumpWidget(welcomeApp(
        dark: true,
        screen: Scaffold(
          body: TodayLessonCard(
              summary: summary4of8, mode: StudyMode.quick, onStart: () {}),
        )));
    expect(find.text('Quick Read · 3 min'), findsOneWidget);
    expect(find.textContaining('Standard'), findsNothing);
  });

  testWidgets('a saved Deep Dive is named on the chip, not as Standard',
      (tester) async {
    await tester.pumpWidget(welcomeApp(
        dark: true,
        screen: Scaffold(
          body: TodayLessonCard(
              summary: summary4of8, mode: StudyMode.deep, onStart: () {}),
        )));
    expect(find.text('Deep Dive · 12 min'), findsOneWidget);
    expect(find.textContaining('Standard'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('start button fill in ${dark ? 'dark' : 'light'} theme',
        (tester) async {
      await tester.pumpWidget(welcomeApp(
          dark: dark,
          screen: Scaffold(
            body: TodayLessonCard(
                summary: summary4of8, mode: StudyMode.standard, onStart: () {}),
          )));
      final context = tester.element(find.byType(TodayLessonCard));
      final palette = ReaderPalette.of(context);
      final style =
          tester.widget<FilledButton>(find.byType(FilledButton)).style!;
      final fill = style.backgroundColor!.resolve({});
      final ink = style.foregroundColor!.resolve({});
      if (dark) {
        expect(fill, Colors.white);
        expect(ink, palette.ctaInk);
      } else {
        expect(fill, palette.text);
        expect(ink, Colors.white);
      }
      expect(fill, isNot(palette.gold));
    });
  }

  testWidgets('finished path shows Choose your next path', (tester) async {
    var chose = 0;
    await tester.pumpWidget(welcomeApp(
        screen: Scaffold(
      body: TodayLessonCard(
          summary: finishedSummary,
          mode: StudyMode.standard,
          onStart: () {},
          onChooseNextPath: () => chose++),
    )));
    expect(find.text('You finished New Believer Essentials'), findsOneWidget);
    expect(find.text('Choose your next path'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('Start lesson'), findsNothing);
    expect(find.textContaining('TODAY'), findsNothing);
    await tester.tap(find.text('Choose your next path'));
    expect(chose, 1);
  });

  testWidgets(
      'no next lesson on an unfinished path: See path, never "You finished"',
      (tester) async {
    const missingNext = ActivePathSummary(
      pathId: 'p1',
      title: 'New Believer Essentials',
      description: 'First steps',
      discipleLevel: 'seeker',
      lessonTotal: 8,
      lessonsCompleted: 3,
    );
    var seen = 0;
    await tester.pumpWidget(welcomeApp(
        screen: Scaffold(
      body: TodayLessonCard(
          summary: missingNext,
          mode: StudyMode.standard,
          onStart: () {},
          onChooseNextPath: () {},
          onSeePath: () => seen++),
    )));
    expect(find.textContaining('You finished'), findsNothing);
    expect(find.text('Choose your next path'), findsNothing);
    expect(find.text('New Believer Essentials'), findsOneWidget);
    await tester.tap(find.text('See path'));
    expect(seen, 1);
  });

  for (final c in fitCases()) {
    final lang = c.lang;
    final dark = c.dark;
    final summary = lang == 'ml' ? mlSummary : hiSummary;
    testWidgets('$lang ${c.width.toInt()}px ${dark ? 'dark' : 'light'}: fits',
        (tester) async {
      useSurface(tester, c.size(400));
      await tester.pumpWidget(welcomeApp(
          language: lang,
          dark: dark,
          screen: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TodayLessonCard(
                  summary: summary, mode: StudyMode.standard, onStart: () {}),
            ),
          )));
      expectNoTruncatedText(tester, allow: {summary.next!.title});
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$lang ${c.width.toInt()}px ${dark ? 'dark' : 'light'}: finished fits',
        (tester) async {
      useSurface(tester, c.size(400));
      await tester.pumpWidget(welcomeApp(
          language: lang,
          dark: dark,
          screen: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TodayLessonCard(
                  summary: ActivePathSummary(
                      pathId: 'p1',
                      title: summary.title,
                      description: '',
                      discipleLevel: '',
                      lessonTotal: 8,
                      lessonsCompleted: 8),
                  mode: StudyMode.standard,
                  onStart: () {},
                  onChooseNextPath: () {}),
            ),
          )));
      expectNoTruncatedText(tester);
      expect(tester.takeException(), isNull);
    });
  }

  group('merged path card', () {
    final card = find.byKey(const Key('today_path_card'));

    testWidgets('one card: strip on top, then eyebrow, title and button',
        (tester) async {
      var started = 0;
      var opened = 0;
      await tester.pumpWidget(welcomeApp(
          screen: Scaffold(
              body: _card(summary4of8,
                  onStart: () => started++, onSeePath: () => opened++))));
      expect(card, findsOneWidget);
      final strip =
          find.descendant(of: card, matching: find.byType(PathProgressStrip));
      expect(strip, findsOneWidget);
      // The strip sits above the eyebrow, inside the same card.
      expect(
          tester.getBottomLeft(strip).dy,
          lessThanOrEqualTo(
              tester.getTopLeft(find.text('TODAY · LESSON 4')).dy));
      // "Today" is said once, by the eyebrow.
      expect(find.text('Today'), findsNothing);
      expect(find.byKey(const Key('strip_today')), findsNothing);
      // The current dot keeps its emphasis.
      expect(tester.getSize(find.byKey(const Key('strip_dot_4'))).width, 28);

      await tester.tap(find.text('Start lesson 4'));
      expect(started, 1);
      expect(opened, 0);
      await tester.tap(find.byKey(const Key('strip_dot_6')));
      expect(opened, 1);
      expect(started, 1);
    });

    testWidgets('strip semantics stay on the strip area', (tester) async {
      final handle = tester.ensureSemantics();
      await tester
          .pumpWidget(welcomeApp(screen: Scaffold(body: _card(summary4of8))));
      expect(find.bySemanticsLabel('3 of 8 lessons done'), findsOneWidget);
      expect(find.text('Start lesson 4'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('long path: bar and Lesson n of m caption inside the card',
        (tester) async {
      await tester.pumpWidget(welcomeApp(
          screen: Scaffold(body: _card(_withTotal(summary4of8, 29, 11)))));
      expect(
          find.descendant(
              of: card, matching: find.byKey(const Key('strip_caption'))),
          findsOneWidget);
      expect(find.text('Lesson 12 of 29'), findsOneWidget);
      expect(find.text('18 to go'), findsOneWidget);
      expect(find.textContaining('Today'), findsNothing);
      expect(find.text('TODAY · LESSON 12'), findsOneWidget);
    });

    testWidgets('finished: strip all checked and the finished state',
        (tester) async {
      await tester.pumpWidget(
          welcomeApp(screen: Scaffold(body: _card(finishedSummary))));
      expect(card, findsOneWidget);
      expect(
          find.descendant(of: card, matching: find.byIcon(Icons.check_rounded)),
          findsNWidgets(8));
      expect(find.text('You finished New Believer Essentials'), findsOneWidget);
      expect(find.text('Choose your next path'), findsOneWidget);
      expect(find.textContaining('TODAY'), findsNothing);
    });

    for (final lang in ['en', 'hi', 'ml']) {
      final base = lang == 'ml'
          ? mlSummary
          : lang == 'hi'
              ? hiSummary
              : summary4of8;
      for (final total in [8, 10, 16, 29]) {
        for (final finished in [false, true]) {
          testWidgets(
              '$lang 320px 1.3x: $total lessons${finished ? ' finished' : ''} fits',
              (tester) async {
            useSurface(tester, const Size(320, 600));
            final summary =
                _withTotal(base, total, finished ? total : total - 3);
            await tester.pumpWidget(welcomeApp(
                language: lang,
                screen: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: Scaffold(
                      body: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _card(summary),
                      ),
                    ),
                  ),
                )));
            expectNoTruncatedText(tester, allow: {base.next!.title});
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('eyebrow stays on one line next to (or above) the mode chip', () {
    const eyebrows = {
      'en': 'TODAY · LESSON 7',
      'hi': 'आज · पाठ 7',
      'ml': 'ഇന്ന് · പാഠം 7',
    };

    /// True when [finder]'s paragraph is one line: no taller than the same
    /// text laid out without a width limit.
    bool oneLine(WidgetTester tester, Finder finder) {
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
      )..layout();
      final single = painter.height;
      painter.dispose();
      return paragraph.size.height <= single + 0.5;
    }

    for (final lang in ['en', 'hi', 'ml']) {
      final base = lang == 'ml'
          ? mlSummary
          : lang == 'hi'
              ? hiSummary
              : summary4of8;
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.3]) {
          for (final mode in [StudyMode.standard, StudyMode.quick]) {
            testWidgets(
                '$lang ${width.toInt()}px ${scale}x ${mode.name}: one line, '
                'chip whole', (tester) async {
              useSurface(tester, Size(width, 700));
              final summary = _withTotal(base, 12, 6);
              await tester.pumpWidget(welcomeApp(
                  language: lang,
                  screen: Builder(
                    builder: (context) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: Scaffold(
                        body: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TodayLessonCard(
                              summary: summary, mode: mode, onStart: () {}),
                        ),
                      ),
                    ),
                  )));
              final eyebrow = find.text(eyebrows[lang]!);
              expect(eyebrow, findsOneWidget);
              expect(oneLine(tester, eyebrow), isTrue,
                  reason: 'eyebrow wrapped');
              final chip = find.byKey(const Key('today_mode_chip'));
              expect(chip, findsOneWidget);
              // Never overlapping: the chip is beside the eyebrow or below.
              final e = tester.getRect(eyebrow);
              final c = tester.getRect(chip);
              expect(e.overlaps(c), isFalse);
              expectNoTruncatedText(tester, allow: {summary.next!.title});
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }

    testWidgets('en 412px 1.0x: the chip sits on the eyebrow row, at the end',
        (tester) async {
      useSurface(tester, const Size(412, 700));
      await tester.pumpWidget(welcomeApp(
          language: 'en',
          screen: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: _card(_withTotal(summary4of8, 12, 6)),
            ),
          )));
      final e = tester.getRect(find.text('TODAY · LESSON 7'));
      final c = tester.getRect(find.byKey(const Key('today_mode_chip')));
      expect((e.center.dy - c.center.dy).abs(), lessThan(4));
      expect(c.right, greaterThan(412 - 16 - 30));
    });
  });
}
