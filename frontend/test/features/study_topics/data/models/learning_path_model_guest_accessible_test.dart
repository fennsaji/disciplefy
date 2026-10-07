import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _pathJson(
        {Object? guestAccessible, bool include = true}) =>
    {
      'id': 'p1',
      'slug': 'gospel-of-mark',
      'title': 'The Gospel of Mark',
      'description': 'd',
      'icon_name': 'school',
      'color': '#6A4FB6',
      'total_xp': 100,
      'estimated_days': 7,
      'disciple_level': 'believer',
      if (include) 'guest_accessible': guestAccessible,
    };

void main() {
  group('LearningPathModel guest_accessible', () {
    test('parses true and false', () {
      expect(
        LearningPathModel.fromJson(_pathJson(guestAccessible: true))
            .guestAccessible,
        isTrue,
      );
      expect(
        LearningPathModel.fromJson(_pathJson(guestAccessible: false))
            .guestAccessible,
        isFalse,
      );
    });

    test('defaults to false when missing, null or not a bool', () {
      expect(
        LearningPathModel.fromJson(_pathJson(include: false)).guestAccessible,
        isFalse,
      );
      expect(
        LearningPathModel.fromJson(_pathJson()).guestAccessible,
        isFalse,
      );
      expect(
        LearningPathModel.fromJson(_pathJson(guestAccessible: 'true'))
            .guestAccessible,
        isFalse,
      );
    });

    test('round-trips through toJson and survives copyWith', () {
      final model =
          LearningPathModel.fromJson(_pathJson(guestAccessible: true));
      expect(model.toJson()['guest_accessible'], isTrue);
      expect(
        LearningPathModel.fromJson(model.toJson()).guestAccessible,
        isTrue,
      );
      expect(model.copyWith(isEnrolled: true).guestAccessible, isTrue);
    });
  });

  group('LearningPathDetailModel guest_accessible', () {
    test('parses the flag and defaults to false', () {
      expect(
        LearningPathDetailModel.fromJson(_pathJson(guestAccessible: true))
            .guestAccessible,
        isTrue,
      );
      expect(
        LearningPathDetailModel.fromJson(_pathJson(include: false))
            .guestAccessible,
        isFalse,
      );
      final detail =
          LearningPathDetailModel.fromJson(_pathJson(guestAccessible: true));
      expect(detail.toJson()['guest_accessible'], isTrue);
    });
  });
}
