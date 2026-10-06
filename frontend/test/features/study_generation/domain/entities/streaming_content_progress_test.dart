import 'package:disciplefy_bible_study/features/study_generation/domain/entities/expected_sections.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_stream_event.dart';
import 'package:flutter_test/flutter_test.dart';

StudyStreamSectionEvent _event(StudyStreamSectionType type, int total) =>
    StudyStreamSectionEvent(
      type: type,
      content: switch (type) {
        StudyStreamSectionType.relatedVerses ||
        StudyStreamSectionType.reflectionQuestions ||
        StudyStreamSectionType.prayerPoints =>
          ['item'],
        _ => 'text ${type.name}',
      },
      index: 0,
      total: total,
    );

void main() {
  test(
      'a multi-pass stream that re-sends interpretation counts distinct '
      'sections and completes only after all seven', () {
    final total = expectedSectionsFor(StudyMode.deep);
    // The order the multi-pass paths emit: pass 1 sections, interpretation
    // re-sent as each pass adds to it, then the closing sections.
    final sequence = [
      StudyStreamSectionType.summary,
      StudyStreamSectionType.context,
      StudyStreamSectionType.passage,
      StudyStreamSectionType.interpretation,
      StudyStreamSectionType.interpretation,
      StudyStreamSectionType.interpretation,
      StudyStreamSectionType.interpretation,
      StudyStreamSectionType.relatedVerses,
      StudyStreamSectionType.reflectionQuestions,
      StudyStreamSectionType.prayerPoints,
    ];

    var content = StreamingStudyGuideContent.empty(mode: StudyMode.deep);
    var lastProgress = content.progress;
    final distinct = <StudyStreamSectionType>{};
    for (final type in sequence) {
      content = content.copyWithSection(_event(type, total));
      distinct.add(type);

      expect(content.sectionsLoaded, distinct.length, reason: type.name);
      expect(content.progress, greaterThanOrEqualTo(lastProgress));
      expect(content.progress, lessThanOrEqualTo(1.0));
      lastProgress = content.progress;

      final isLast = type == StudyStreamSectionType.prayerPoints;
      expect(content.isComplete, isLast, reason: type.name);
    }
    expect(content.sectionsLoaded, total);
    expect(content.progress, 1.0);
  });

  test('progress never passes 1 even if the backend over-reports sections', () {
    final content = StreamingStudyGuideContent.empty(mode: StudyMode.quick)
        .copyWith(sectionsLoaded: 20);
    expect(content.progress, 1.0);
  });
}
