import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/domain/utils/lesson_launch_from_summary.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/today_lesson_card.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/utils/lesson_launch.dart';

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

  testWidgets('one primary button, no Next: line, chip toggles mode',
      (tester) async {
    StudyMode? changed;
    var started = 0;
    await tester.pumpWidget(welcomeApp(
        screen: Scaffold(
      body: TodayLessonCard(
          summary: summary4of8,
          mode: StudyMode.standard,
          onModeChanged: (m) => changed = m,
          onStart: () => started++),
    )));
    expect(find.text('TODAY · LESSON 4'), findsOneWidget);
    expect(find.text('Confidence in Your Salvation'), findsOneWidget);
    expect(find.text('Start lesson 4'), findsOneWidget);
    expect(find.textContaining('Next:'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.getSize(find.byType(FilledButton)).height, 40);
    expect(tester.getSize(find.byType(OutlinedButton)).height, 32);

    await tester.tap(find.byType(FilledButton));
    expect(started, 1);

    await tester.tap(find.textContaining('Full guide'));
    await tester.pumpAndSettle();
    expect(find.text('Quick read · 3 min'), findsOneWidget);
    await tester.tap(find.textContaining('Quick read').last);
    await tester.pumpAndSettle();
    expect(changed, StudyMode.quick);
  });

  testWidgets('chip shows the quick label in quick mode', (tester) async {
    await tester.pumpWidget(welcomeApp(
        dark: true,
        screen: Scaffold(
          body: TodayLessonCard(
              summary: summary4of8,
              mode: StudyMode.quick,
              onModeChanged: (_) {},
              onStart: () {}),
        )));
    expect(find.text('Quick read · 3 min'), findsOneWidget);
    expect(find.textContaining('Full guide'), findsNothing);
  });

  testWidgets('finished path shows Choose your next path', (tester) async {
    var chose = 0;
    await tester.pumpWidget(welcomeApp(
        screen: Scaffold(
      body: TodayLessonCard(
          summary: finishedSummary,
          mode: StudyMode.standard,
          onModeChanged: (_) {},
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

  for (final (lang, summary) in [('ml', mlSummary), ('hi', hiSummary)]) {
    for (final dark in [false, true]) {
      testWidgets('$lang 320px ${dark ? 'dark' : 'light'}: fits',
          (tester) async {
        useSurface(tester, const Size(320, 400));
        await tester.pumpWidget(welcomeApp(
            language: lang,
            dark: dark,
            screen: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: TodayLessonCard(
                    summary: summary,
                    mode: StudyMode.standard,
                    onModeChanged: (_) {},
                    onStart: () {}),
              ),
            )));
        expectNoTruncatedText(tester, allow: {summary.next!.title});
        expect(tester.takeException(), isNull);
      });

      testWidgets('$lang 320px ${dark ? 'dark' : 'light'}: finished fits',
          (tester) async {
        useSurface(tester, const Size(320, 400));
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
                    onModeChanged: (_) {},
                    onStart: () {},
                    onChooseNextPath: () {}),
              ),
            )));
        expectNoTruncatedText(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
