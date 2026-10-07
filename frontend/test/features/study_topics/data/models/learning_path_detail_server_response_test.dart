import 'dart:convert';
import 'dart:io';

import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/utils/lesson_launch.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real `learning-paths` detail responses captured from the local function
/// (guest enrolled / guest not enrolled / full user).
Map<String, dynamic> _data(String fixture) {
  final body = jsonDecode(
    File('test/fixtures/learning_paths/$fixture.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return body['data'] as Map<String, dynamic>;
}

void main() {
  for (final fixture in const [
    'path_detail_guest_enrolled_ml',
    'path_detail_guest_not_enrolled_ml',
    'path_detail_full_user_enrolled_en',
  ]) {
    test('$fixture parses and builds a lesson link', () {
      final json = _data(fixture);
      final detail = LearningPathDetailModel.fromJson(json);

      expect(detail.id, json['id']);
      expect(detail.guestAccessible, isTrue);
      expect(detail.isEnrolled, json['is_enrolled']);
      expect(detail.topics, hasLength((json['topics'] as List).length));

      final location = buildLessonLaunchLocation(
        path: detail,
        topic: detail.topics.last,
        mode: StudyMode.quick,
        language: 'ml',
      );
      expect(Uri.parse(location).queryParameters['lesson_total'],
          '${detail.topics.length}');
    });
  }
}
