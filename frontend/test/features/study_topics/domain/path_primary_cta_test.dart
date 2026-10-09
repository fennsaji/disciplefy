import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/utils/path_primary_cta.dart';

void main() {
  LearningPathTopic t(int pos, {bool done = false, bool started = false}) =>
      LearningPathTopic(
          position: pos,
          isMilestone: false,
          topicId: 't$pos',
          title: 'L$pos',
          description: '',
          category: '',
          xpValue: 50,
          isCompleted: done,
          isInProgress: started);

  LearningPathDetail path(List<LearningPathTopic> topics,
          {bool enrolled = true}) =>
      LearningPathDetail.forTest(
          id: 'p',
          title: 'P',
          description: '',
          topics: topics,
          isEnrolled: enrolled);

  test('not enrolled → enrollAndStart lesson 1', () {
    final cta = pathPrimaryCta(path([t(1), t(2)], enrolled: false))!;
    expect(cta.kind, PathCtaKind.enrollAndStart);
    expect(cta.lessonNumber, 1);
  });
  test('enrolled, nothing started → start lesson 1', () {
    final cta = pathPrimaryCta(path([t(1), t(2)]))!;
    expect(cta.kind, PathCtaKind.start);
    expect(cta.lessonNumber, 1);
  });
  test('two done → resume lesson 3', () {
    final cta =
        pathPrimaryCta(path([t(1, done: true), t(2, done: true), t(3), t(4)]))!;
    expect(cta.kind, PathCtaKind.resume);
    expect(cta.lessonNumber, 3);
  });
  test('all done → review lesson 1, never lesson N+1', () {
    final cta = pathPrimaryCta(path([t(1, done: true), t(2, done: true)]))!;
    expect(cta.kind, PathCtaKind.review);
    expect(cta.lessonNumber, 1);
    expect(cta.topic.position, 1);
  });
  test('no topics → null', () {
    expect(pathPrimaryCta(path([])), isNull);
  });
}
