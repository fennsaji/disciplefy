import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/home/data/models/active_path_summary_model.dart';

void main() {
  test('parses next_lesson, completion and milestones', () {
    final s = ActivePathSummaryModel.fromJson({
      'id': 'p1',
      'title': 'New Believer Essentials',
      'description': 'd',
      'disciple_level': 'seeker',
      'topics_count': 8,
      'topics_completed': 3,
      'milestone_positions': [4, 7, 8],
      'recommended_mode': 'standard',
      'next_lesson': {
        'topic_id': 't4',
        'title': 'Confidence in Your Salvation',
        'description': '',
        'input_type': 'topic',
        'lesson_number': 4,
        'lesson_total': 8,
      },
    });
    expect(s.next!.number, 4);
    expect(s.lessonsCompleted, 3);
    expect(s.milestoneNumbers, [4, 7, 8]);
    expect(s.displayTitle, 'New Believer Essentials');
    expect(s.isFinished, isFalse);
  });

  test('short_title wins when present', () {
    final s = ActivePathSummaryModel.fromJson({
      'id': 'p',
      'title': 'Long',
      'short_title': 'Short',
      'topics_count': 1,
      'topics_completed': 1,
      'next_lesson': null,
    });
    expect(s.displayTitle, 'Short');
    expect(s.isFinished, isTrue);
  });

  test('old response without new fields does not crash', () {
    final s = ActivePathSummaryModel.fromJson({'id': 'p', 'title': 'T'});
    expect(s.next, isNull);
    expect(s.lessonsCompleted, 0);
    expect(s.milestoneNumbers, isEmpty);
    expect(s.recommendedMode, 'standard');
    expect(s.isFinished, isFalse);
  });

  test('malformed next_lesson is ignored', () {
    final s = ActivePathSummaryModel.fromJson({
      'id': 'p',
      'next_lesson': {'title': 'x'},
      'milestone_positions': [1, 'a', null],
    });
    expect(s.next, isNull);
    expect(s.milestoneNumbers, [1]);
  });

  // Out-of-order completion: lessons 1 and 3 of 4 done. The strip used
  // "completed + 1" = 3, which is finished; the server's lesson rows say 2.
  test('highlights the server next_lesson_number, not completed + 1', () {
    final s = ActivePathSummaryModel.fromJson({
      'id': 'p',
      'title': 'Romans',
      'topics_count': 4,
      'topics_completed': 2,
      'next_lesson_number': 2,
    });
    expect(s.nextLessonNumberKnown, isTrue);
    expect(s.currentLessonNumber, 2);
  });

  test('next_lesson_number null means finished: the last lesson', () {
    final s = ActivePathSummaryModel.fromJson({
      'id': 'p',
      'topics_count': 4,
      'topics_completed': 4,
      'next_lesson_number': null,
    });
    expect(s.currentLessonNumber, 4);
  });

  test('older servers without the field keep the count-based guess', () {
    final s = ActivePathSummaryModel.fromJson({
      'id': 'p',
      'topics_count': 4,
      'topics_completed': 2,
    });
    expect(s.nextLessonNumberKnown, isFalse);
    expect(s.currentLessonNumber, 3);
  });
}
