import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/services/lesson_events.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';

import '../../../../helpers/mock_activation_analytics.dart';

const _lesson = LessonRef(
  pathId: 'p1',
  pathTitle: 'A long path title that must never be sent',
  lessonNumber: 1,
  lessonTotal: 8,
);

void main() {
  late MockActivationAnalytics analytics;

  setUp(() => analytics = registerMockAnalytics());
  tearDown(() async => sl.reset());

  test('event data: ids, numbers and the mode name only', () {
    expect(
      buildLessonEventData(
          lesson: _lesson, mode: StudyMode.quick, firstRun: true),
      {'path_id': 'p1', 'lesson_number': 1, 'mode': 'quick', 'first_run': true},
    );
  });

  test('started and completed are each sent once per screen', () {
    final tracker = LessonEventTracker(
        lesson: _lesson, mode: StudyMode.quick, firstRun: true);
    tracker
      ..started()
      ..started()
      ..completed()
      ..completed();

    final data = buildLessonEventData(
        lesson: _lesson, mode: StudyMode.quick, firstRun: true);
    verify(() => analytics.track(NuxEvent.lessonStarted, data)).called(1);
    verify(() => analytics.track(NuxEvent.lessonCompleted,
        any(that: containsPair('lesson_number', 1)))).called(1);
  });

  test('the guide screen reports lesson start and completion', () {
    final source = File(
            'lib/features/study_generation/presentation/pages/study_guide_screen_v2.dart')
        .readAsStringSync();
    expect(source, contains('LessonEventTracker('));
    expect(source, contains('_lessonEvents?.started()'));
    expect(source, contains('_lessonEvents?.completed()'));
  });
}
