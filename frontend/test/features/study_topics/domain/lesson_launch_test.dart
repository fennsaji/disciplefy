import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/utils/lesson_launch.dart';

LearningPathTopic topic(int pos, String id, String title) => LearningPathTopic(
      position: pos,
      isMilestone: false,
      topicId: id,
      title: title,
      description: 'd',
      category: 'c',
      xpValue: 50,
    );

void main() {
  group('LessonRef', () {
    test('round-trips through query parameters', () {
      const ref = LessonRef(
          pathId: 'p1',
          pathTitle: 'New Believer Essentials',
          lessonNumber: 2,
          lessonTotal: 8);
      expect(LessonRef.fromQuery(ref.toQuery()), ref);
    });
    test('is null when any lesson param is missing or invalid', () {
      expect(LessonRef.fromQuery({'path_id': 'p1'}), isNull);
      expect(
          LessonRef.fromQuery(
              {'path_id': 'p1', 'lesson_number': 'x', 'lesson_total': '8'}),
          isNull);
      expect(
          LessonRef.fromQuery(
              {'path_id': 'p1', 'lesson_number': '9', 'lesson_total': '8'}),
          isNull);
    });
    test('isLast', () {
      expect(
          const LessonRef(
                  pathId: 'p', pathTitle: 't', lessonNumber: 8, lessonTotal: 8)
              .isLast,
          isTrue);
    });
  });

  test('buildLessonLaunchLocation carries lesson number by position order', () {
    final path = LearningPathDetail.forTest(
      id: 'p1',
      title: 'New Believer Essentials',
      description: 'desc',
      topics: [
        topic(20, 't2', 'One God'),
        topic(10, 't1', 'Who is Jesus Christ?')
      ],
    );
    final loc = buildLessonLaunchLocation(
        path: path,
        topic: path.topics.firstWhere((t) => t.topicId == 't2'),
        mode: StudyMode.quick,
        language: 'en');
    final uri = Uri.parse(loc);
    expect(uri.path, '/study-guide-v2');
    expect(uri.queryParameters['topic_id'], 't2');
    expect(uri.queryParameters['mode'], 'quick');
    expect(uri.queryParameters['source'], 'learningPath');
    expect(uri.queryParameters['path_id'], 'p1');
    expect(uri.queryParameters['lesson_number'], '2');
    expect(uri.queryParameters['lesson_total'], '2');
    expect(uri.queryParameters['input'], 'One God');
  });
}
