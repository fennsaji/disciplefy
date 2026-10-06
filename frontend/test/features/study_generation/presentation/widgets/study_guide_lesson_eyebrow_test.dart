import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_guide_body.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';

import '../../../../helpers/welcome_test_harness.dart';

void main() {
  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<String> eyebrowFor(
    WidgetTester tester, {
    LessonRef? lesson,
    StudyMode mode = StudyMode.quick,
  }) async {
    late String eyebrow;
    await tester.pumpWidget(welcomeApp(
      path: '/guide',
      dark: false,
      screen: Builder(builder: (c) {
        eyebrow = StudyGuideTopicTitle.eyebrow(
          c,
          inputType: 'topic',
          studyMode: mode,
          lesson: lesson,
        );
        return const SizedBox();
      }),
    ));
    return eyebrow;
  }

  testWidgets('lesson eyebrow replaces TOPIC', (tester) async {
    final eyebrow = await eyebrowFor(
      tester,
      lesson: const LessonRef(
          pathId: 'p', pathTitle: 'NBE', lessonNumber: 1, lessonTotal: 8),
    );
    expect(eyebrow, 'LESSON 1 OF 8 · QUICK READ · 3 MIN');
  });

  testWidgets('without a lesson the eyebrow is unchanged', (tester) async {
    final eyebrow = await eyebrowFor(tester, mode: StudyMode.standard);
    expect(eyebrow, startsWith('TOPIC · '));
  });
}
