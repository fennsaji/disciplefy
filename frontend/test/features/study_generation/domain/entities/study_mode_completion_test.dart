import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudyMode.minCompletionSeconds', () {
    test('uses the lenient minimums', () {
      expect(StudyMode.quick.minCompletionSeconds, 30);
      expect(StudyMode.standard.minCompletionSeconds, 45);
      expect(StudyMode.deep.minCompletionSeconds, 60);
      expect(StudyMode.lectio.minCompletionSeconds, 60);
      expect(StudyMode.sermon.minCompletionSeconds, 90);
    });

    test(
        'never drops below the 30 s floor in mark-study-guide-complete, '
        'which would reject auto-completion', () {
      for (final mode in StudyMode.values) {
        expect(mode.minCompletionSeconds, greaterThanOrEqualTo(30),
            reason: mode.name);
      }
    });
  });
}
