import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/all_paths_page.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/path_list_row.dart';

Map<String, dynamic> _json({Object? next = _absent, int progress = 50}) => {
      'id': 'romans',
      'slug': 'romans',
      'title': 'Romans',
      'topics_count': 4,
      'is_enrolled': true,
      'progress_percentage': progress,
      if (next != _absent) 'next_lesson_number': next,
    };

const _absent = Object();

void main() {
  // Lessons 1 and 3 of 4 done (50%). "completed + 1" said Lesson 3, which is
  // finished; the server's lesson rows say Lesson 2.
  test('All paths "Lesson N of M" uses next_lesson_number', () {
    final path = LearningPathModel.fromJson(_json(next: 2));
    expect(path.currentLessonNumber, 2);
    expect(currentPathIn([path])!.lesson, 2);
    expect(enrolledLessonOf(path), 2);
  });

  test('older servers without the field keep the count-based guess', () {
    final path = LearningPathModel.fromJson(_json());
    expect(path.nextLessonNumberKnown, isFalse);
    expect(currentPathIn([path])!.lesson, 3);
  });

  test('null next_lesson_number (finished) clamps to the last lesson', () {
    final path = LearningPathModel.fromJson(_json(next: null));
    expect(path.currentLessonNumber, 4);
  });

  test('round-trips through toJson', () {
    final path = LearningPathModel.fromJson(_json(next: 2));
    final again = LearningPathModel.fromJson(path.toJson());
    expect(again.nextLessonNumber, 2);
    expect(again.nextLessonNumberKnown, isTrue);
  });
}
