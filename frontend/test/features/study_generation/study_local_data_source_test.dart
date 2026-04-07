import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/datasources/study_local_data_source.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';

void main() {
  late StudyLocalDataSourceImpl dataSource;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp();
    Hive.init(dir.path);
    dataSource = StudyLocalDataSourceImpl();
  });

  tearDown(() async {
    await Hive.close();
  });

  final testGuide = StudyGuide(
    id: 'guide-1',
    input: 'Grace and Mercy',
    inputType: 'topic',
    summary: 'A guide on grace',
    interpretation: 'God extends grace freely',
    context: 'Early church teaching',
    relatedVerses: const [],
    reflectionQuestions: const [],
    prayerPoints: const [],
    language: 'en',
    createdAt: DateTime(2026, 4, 7),
  );

  group('deleteStudyGuide', () {
    test('removes the specific guide from the Hive cache', () async {
      await dataSource.cacheStudyGuide(testGuide);

      final before = await dataSource.getCachedStudyGuides();
      expect(before.any((g) => g.id == 'guide-1'), isTrue);

      final result = await dataSource.deleteStudyGuide('guide-1');
      expect(result, isTrue);

      final after = await dataSource.getCachedStudyGuides();
      expect(after.any((g) => g.id == 'guide-1'), isFalse);
    });

    test('returns true when the id does not exist', () async {
      final result = await dataSource.deleteStudyGuide('nonexistent-id');
      expect(result, isTrue);
    });

    test('does not remove other guides', () async {
      final other = StudyGuide(
        id: 'guide-2',
        input: 'Faith',
        inputType: 'topic',
        summary: 'Faith summary',
        interpretation: 'Faith interpretation',
        context: 'Faith context',
        relatedVerses: const [],
        reflectionQuestions: const [],
        prayerPoints: const [],
        language: 'en',
        createdAt: DateTime(2026, 4, 7),
      );

      await dataSource.cacheStudyGuide(testGuide);
      await dataSource.cacheStudyGuide(other);

      await dataSource.deleteStudyGuide('guide-1');

      final remaining = await dataSource.getCachedStudyGuides();
      expect(remaining.any((g) => g.id == 'guide-2'), isTrue);
      expect(remaining.any((g) => g.id == 'guide-1'), isFalse);
    });
  });
}
