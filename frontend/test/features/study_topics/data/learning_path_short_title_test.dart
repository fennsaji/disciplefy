import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _path([Object? shortTitle]) => {
      'id': 'p1',
      'slug': '1-thessalonians-living-ready',
      'title': "1 Thessalonians: Living Ready for Christ's Return",
      'description': 'd',
      'short_title': shortTitle,
    };

void main() {
  group('LearningPath short title', () {
    test('displayTitle falls back to title when short_title is null or blank',
        () {
      final title = _path()['title'];
      expect(LearningPathModel.fromJson(_path()).displayTitle, title);
      expect(LearningPathModel.fromJson(_path('  ')).displayTitle, title);
      expect(LearningPathModel.fromJson(_path('Short')).displayTitle, 'Short');
    });

    test('a missing or non-string short_title reads as none', () {
      final json = _path()..remove('short_title');
      expect(LearningPathModel.fromJson(json).shortTitle, isNull);
      expect(LearningPathModel.fromJson(_path(42)).shortTitle, isNull);
    });

    test('short_title is trimmed and round-trips through toJson', () {
      final model = LearningPathModel.fromJson(_path(' 1 Thessalonians '));
      expect(model.shortTitle, '1 Thessalonians');
      final again = LearningPathModel.fromJson(model.toJson());
      expect(again.shortTitle, '1 Thessalonians');
      expect(again, model);
    });

    test('copyWith keeps the short title', () {
      final model = LearningPathModel.fromJson(_path('1 Thessalonians'));
      final copy = model.copyWith(isEnrolled: true, progressPercentage: 40);
      expect(copy.shortTitle, '1 Thessalonians');
      expect(copy.displayTitle, '1 Thessalonians');
    });

    test('the detail model parses short_title too', () {
      final detail = LearningPathDetailModel.fromJson(_path('1 Thessalonians'));
      expect(detail.displayTitle, '1 Thessalonians');
      expect(detail.toJson()['short_title'], '1 Thessalonians');
    });

    test('the recommended path summary carries the same short title', () {
      final model = RecommendedPathResponseModel.fromJson({
        'data': {'path': _path('1 Thessalonians'), 'reason': 'active'},
      });
      expect(model.path!.displayTitle, '1 Thessalonians');
      expect(model.summary!.displayTitle, '1 Thessalonians');
    });
  });
}
