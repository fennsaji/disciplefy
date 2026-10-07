import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_path_detail_parts.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_list_row.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

LearningPath lp({
  String id = 'p',
  int topicsCount = 6,
  int estimatedDays = 14,
  int totalXp = 100,
  String discipleLevel = 'follower',
  String color = '#2563EB',
  bool enrolled = false,
  int progress = 0,
}) =>
    LearningPath(
      id: id,
      slug: id,
      title: 'Rooted in Christ',
      description: '',
      iconName: 'park',
      color: color,
      totalXp: totalXp,
      estimatedDays: estimatedDays,
      discipleLevel: discipleLevel,
      topicsCount: topicsCount,
      isEnrolled: enrolled,
      progressPercentage: progress,
      category: 'Foundations',
    );

void main() {
  late FakeTranslationService translations;

  setUpAll(loadAppFonts);
  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });
  tearDown(() => sl.reset());

  Widget host(Widget child) => welcomeApp(
        screen: Scaffold(body: ListView(children: [child])),
        dark: true,
      );

  testWidgets('row meta: lessons and days only', (tester) async {
    await tester.pumpWidget(host(PathListRow(
        path: lp(
            topicsCount: 5,
            estimatedDays: 21,
            totalXp: 250,
            discipleLevel: 'seeker'))));
    await tester.pumpAndSettle();
    expect(find.text('5 lessons · 21 days'), findsOneWidget);
    expect(find.textContaining('XP'), findsNothing);
    expect(find.textContaining('Seeker'), findsNothing);
    expect(find.textContaining('Topics'), findsNothing);
  });

  testWidgets('enrolled row shows Lesson N of M in gold', (tester) async {
    await tester.pumpWidget(host(
        PathListRow(path: lp(topicsCount: 8, enrolled: true, progress: 38))));
    await tester.pumpAndSettle();
    final lesson = tester.widget<Text>(find.text('Lesson 4 of 8'));
    final context = tester.element(find.text('Lesson 4 of 8'));
    expect(lesson.style?.color, ReaderPalette.of(context).gold);
    expect(find.textContaining('lessons ·'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('currentLesson and the Current tag', (tester) async {
    await tester.pumpWidget(host(PathListRow(
        path: lp(topicsCount: 22, enrolled: true),
        currentLesson: 1,
        isCurrent: true)));
    await tester.pumpAndSettle();
    expect(find.text('Lesson 1 of 22'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
  });

  test("tile uses the path's colour; indigo and bad values become blue", () {
    expect(pathTileColor(lp(color: '#DC2626')), const Color(0xFFDC2626));
    expect(pathTileColor(lp(color: '#10B981')), const Color(0xFF10B981));
    expect(pathTileColor(lp(color: '#6366F1')), const Color(0xFF2563EB));
    expect(pathTileColor(lp(color: '#4F46E5')), const Color(0xFF2563EB));
    expect(pathTileColor(lp(color: '')), const Color(0xFF2563EB));
    expect(pathTileColor(lp(color: 'nope')), const Color(0xFF2563EB));
  });

  group('path detail lesson rows', () {
    testWidgets(
        'no XP or category; Milestone stays; the current lesson says Today',
        (tester) async {
      await tester.pumpWidget(host(const Column(children: [
        PathTopicRow(
            number: 3,
            title: 'What is the Gospel?',
            status: PathTopicStatus.completed),
        PathTopicRow(
            number: 4,
            title: 'Confidence in Your Salvation',
            status: PathTopicStatus.current,
            isMilestone: true),
        PathTopicRow(
            number: 5,
            title: 'Why Read the Bible?',
            status: PathTopicStatus.upcoming),
      ])));
      await tester.pumpAndSettle();
      expect(find.textContaining('XP'), findsNothing);
      expect(find.text('Milestone'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('header: category eyebrow, lessons and days, no level or XP',
        (tester) async {
      await tester.pumpWidget(host(const PathDetailHeader(
        category: 'Foundations',
        title: 'New Believer Essentials',
        description: '',
        topicsCount: 8,
        estimatedDays: 14,
        icon: Icons.park,
      )));
      await tester.pumpAndSettle();
      expect(find.text('FOUNDATIONS'), findsOneWidget);
      expect(find.text('8 Lessons'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      expect(find.textContaining('SEEKER'), findsNothing);
    });
  });

  for (final lang in AppLanguage.values) {
    for (final dark in [true, false]) {
      final name = '${lang.code} ${dark ? 'dark' : 'light'}';
      testWidgets('rows and lesson rows fit 320 wide ($name)', (tester) async {
        useSurface(tester, const Size(320, 800));
        await tester.pumpWidget(welcomeApp(
          language: lang.code,
          dark: dark,
          screen: Scaffold(
            body: ListView(children: [
              PathListRow(path: lp()),
              PathListRow(path: lp(id: 'e', enrolled: true, progress: 38)),
              PathListRow(
                  path: lp(id: 'c', enrolled: true),
                  currentLesson: 1,
                  isCurrent: true),
              const PathTopicRow(
                  number: 4,
                  title: 'Confidence',
                  status: PathTopicStatus.current,
                  isMilestone: true),
              const PathDetailHeader(
                category: 'Foundations',
                title: 'New Believer Essentials',
                description: '',
                topicsCount: 8,
                estimatedDays: 14,
                icon: Icons.park,
              ),
            ]),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }
  }
}
