import 'package:disciplefy_bible_study/features/saved_guides/data/models/saved_guide_model.dart';
import 'package:disciplefy_bible_study/features/saved_guides/domain/entities/saved_guide_entity.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/screens/study_guide_open_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exact shape `GET study-guides?id=` returns in `data.guide`
/// (StudyGuideRepository.formatStudyGuideResponse).
Map<String, dynamic> apiGuide(
        {String type = 'topic', String value = 'Prayer'}) =>
    {
      'id': 'e8275605-2056-4c1a-87e4-443e9daa8357',
      'input': {
        'type': type,
        'value': value,
        'language': 'ml',
        'study_mode': 'deep',
      },
      'content': {
        'summary': 'Prayer is talking with God.',
        'interpretation': 'Jesus taught us to pray.',
        'context': 'Written to early believers.',
        'passage': 'Matthew 6:5-13',
        'relatedVerses': ['Philippians 4:6', '1 Thessalonians 5:17'],
        'reflectionQuestions': ['When do you pray?'],
        'prayerPoints': ['Pray daily'],
      },
      'isSaved': true,
      'createdAt': '2026-09-01T10:00:00Z',
      'updatedAt': '2026-09-02T10:00:00Z',
      'personal_notes': 'My note',
    };

void main() {
  group('studyGuideRouteDataFromApi', () {
    test('flattens the nested API guide into the keys the study screen reads',
        () {
      final data = studyGuideRouteDataFromApi(apiGuide());

      expect(data['id'], 'e8275605-2056-4c1a-87e4-443e9daa8357');
      expect(data['topic_name'], 'Prayer');
      expect(data['summary'], 'Prayer is talking with God.');
      expect(data['interpretation'], 'Jesus taught us to pray.');
      expect(data['context'], 'Written to early believers.');
      expect(data['passage'], 'Matthew 6:5-13');
      expect(
          data['related_verses'], ['Philippians 4:6', '1 Thessalonians 5:17']);
      expect(data['reflection_questions'], ['When do you pray?']);
      expect(data['prayer_points'], ['Pray daily']);
      expect(data['is_saved'], true);
      expect(data['study_mode'], 'deep');
      expect(data['language'], 'ml');
      expect(data['personal_notes'], 'My note');
      expect(data['type'], 'topic');
    });

    test('a scripture guide keeps its scripture type and reference', () {
      final data = studyGuideRouteDataFromApi(
          apiGuide(type: 'scripture', value: 'John 3:16'));

      expect(data['type'], 'scripture');
      expect(data['verse_reference'], 'John 3:16');
      expect(data['topic_name'], isNull);
    });
  });

  test('saved-list parsing keeps scripture guides as verse guides', () {
    final model = SavedGuideModel.fromApiResponse(
        apiGuide(type: 'scripture', value: 'John 3:16'));

    expect(model.type, GuideType.verse);
  });
}
