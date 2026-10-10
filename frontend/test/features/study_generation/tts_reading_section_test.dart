import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/study_generation/data/services/study_guide_tts_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_guide_body.dart';

StudyGuide _guide({String? passage}) => StudyGuide(
      id: 'g',
      input: 'John 3:16',
      inputType: 'scripture',
      language: 'en',
      summary: 'Summary',
      context: 'Context',
      interpretation: 'Interpretation',
      relatedVerses: const ['Romans 5:8'],
      reflectionQuestions: const ['Question?'],
      prayerPoints: const ['Prayer'],
      passage: passage,
      createdAt: DateTime(2026),
    );

/// The reader section highlighted while text-to-speech reads TTS section
/// [ttsIndex] of [guide].
int? _highlighted(StudyGuide guide, int ttsIndex) =>
    StudyGuideBody.sectionIndexFor(
        StudyGuideTTSService.readingOrder(guide)[ttsIndex]);

void main() {
  test('without a passage, each TTS section highlights its own section', () {
    final guide = _guide();
    expect(StudyGuideTTSService.readingOrder(guide).length, 6);
    // Summary, context, interpretation, related verses, questions, prayer.
    expect([for (var i = 0; i < 6; i++) _highlighted(guide, i)],
        [0, 1, 3, 4, 5, 6]);
  });

  test('with a passage, the passage is read after the context', () {
    final guide = _guide(passage: 'For God so loved the world.');
    expect([for (var i = 0; i < 7; i++) _highlighted(guide, i)],
        [0, 1, 2, 3, 4, 5, 6]);
  });
}
