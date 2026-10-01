import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/features/community/domain/utils/fellowship_lesson_language.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_guide_detail_screen.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';

Future<String> _resolve({
  Map<String, Object> saved = const {},
  String? groupLanguage,
  Future<String?> Function()? fetch,
  String user = 'en',
}) async {
  SharedPreferences.setMockInitialValues(saved);
  return resolveFellowshipLessonLanguage(
    prefs: await SharedPreferences.getInstance(),
    fellowshipId: 'f1',
    fellowshipLanguage: groupLanguage,
    fetchFellowshipLanguage: fetch,
    userStudyLanguage: () async => user,
  );
}

void main() {
  group('resolveFellowshipLessonLanguage', () {
    test('a Hindi group opens lessons in Hindi for an English user', () async {
      expect(await _resolve(groupLanguage: 'hi'), 'hi');
    });

    test('the member choice for this group wins over the group language',
        () async {
      expect(
        await _resolve(
          saved: {fellowshipLessonsLanguagePrefKey('f1'): 'en'},
          groupLanguage: 'hi',
          user: 'ml',
        ),
        'en',
      );
    });

    test('a choice saved for another group does not apply', () async {
      expect(
        await _resolve(
          saved: {fellowshipLessonsLanguagePrefKey('f2'): 'ml'},
          groupLanguage: 'hi',
        ),
        'hi',
      );
    });

    test('fetches the group language when it is not loaded yet', () async {
      expect(await _resolve(fetch: () async => 'hi'), 'hi');
    });

    test('falls back to the user language only when the group is unknown',
        () async {
      expect(await _resolve(fetch: () async => null, user: 'ml'), 'ml');
      expect(await _resolve(fetch: () => throw Exception('offline')), 'en');
    });
  });

  test('study guide route carries the lesson language, not the app language',
      () {
    const topic = LearningPathTopic(
      position: 0,
      isMilestone: false,
      topicId: 't1',
      title: 'आत्मिक युद्ध',
      description: '',
      category: 'c',
      xpValue: 50,
    );
    final location = fellowshipStudyGuideLocation(
      topic: topic,
      language: 'hi',
      studyMode: StudyMode.standard,
    );
    final uri = Uri.parse(location);
    expect(uri.path, '/study-guide-v2');
    expect(uri.queryParameters['language'], 'hi');
    expect(uri.queryParameters['input'], 'आत्मिक युद्ध');
    expect(uri.queryParameters['topic_id'], 't1');
    expect(uri.queryParameters['source'], 'fellowship');
  });
}
