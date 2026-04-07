import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/datasources/study_local_data_source.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/usecases/generate_study_guide.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_path_download_service.dart';

@GenerateMocks([GenerateStudyGuide, StudyLocalDataSource])
import 'learning_path_download_service_test.mocks.dart';

void main() {
  late LearningPathDownloadService service;
  late MockGenerateStudyGuide mockGenerateStudyGuide;
  late MockStudyLocalDataSource mockLocalDataSource;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp();
    Hive.init(dir.path);
    mockGenerateStudyGuide = MockGenerateStudyGuide();
    mockLocalDataSource = MockStudyLocalDataSource();
    service = LearningPathDownloadService(
      generateStudyGuide: mockGenerateStudyGuide,
      localDataSource: mockLocalDataSource,
    );
  });

  tearDown(() async {
    await Hive.close();
  });

  const testTopic = LearningPathTopicDownload(
    topicId: 'topic-1',
    topicTitle: 'Grace and Mercy',
    inputType: 'topic',
    description: 'Understanding divine grace',
    studyMode: 'standard',
    status: TopicDownloadStatus.pending,
  );

  final testGuide = StudyGuide(
    id: 'guide-1',
    input: 'Grace and Mercy',
    inputType: 'topic',
    summary: 'A guide on grace',
    interpretation: 'God extends grace freely to all',
    context: 'Written in the context of early church teaching',
    relatedVerses: const ['Romans 5:8', 'Ephesians 2:8'],
    reflectionQuestions: const ['How have you experienced grace?'],
    prayerPoints: const ['Thank God for His grace'],
    language: 'en',
    createdAt: DateTime(2026, 4, 4),
    userId: 'user-1',
  );

  group('buildDownloadJob', () {
    test('builds model with all topics as pending', () {
      final topics = [
        testTopic,
        testTopic.copyWith(status: TopicDownloadStatus.pending),
      ];
      final model = service.buildDownloadJob(
        learningPathId: 'path-1',
        learningPathTitle: 'Foundations',
        language: 'en',
        topics: topics,
      );

      expect(model.learningPathId, 'path-1');
      expect(model.status, PathDownloadStatus.queued);
      expect(model.totalCount, 2);
      expect(model.completedCount, 0);
      expect(
        model.topics.every((t) => t.status == TopicDownloadStatus.pending),
        isTrue,
      );
    });
  });

  group('processDownload', () {
    test('marks topic as done on successful generation', () async {
      when(mockGenerateStudyGuide(any))
          .thenAnswer((_) async => Right(testGuide));
      when(mockLocalDataSource.cacheStudyGuide(any))
          .thenAnswer((_) async => true);

      final model = LearningPathDownloadModel(
        learningPathId: 'path-1',
        learningPathTitle: 'Foundations',
        language: 'en',
        topics: [testTopic],
        status: PathDownloadStatus.downloading,
        queuedAt: DateTime(2026, 4, 4),
        completedCount: 0,
        totalCount: 1,
      );

      final results = <LearningPathDownloadModel>[];
      service.watchDownload('path-1').listen(results.add);

      await service.processDownloadLoop(model);
      // Flush any remaining microtasks so stream listeners fire.
      await Future<void>.delayed(Duration.zero);

      // Verify final persisted state rather than stream (stream may have
      // intermediate states captured before microtasks flush).
      final finalState = service.getDownload('path-1');
      expect(finalState?.completedCount, 1);
      expect(finalState?.status, PathDownloadStatus.completed);
      expect(finalState?.topics.first.status, TopicDownloadStatus.done);
    });

    test('marks topic as failed and continues on generation error', () async {
      when(mockGenerateStudyGuide(any)).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'err', code: 'E')),
      );

      final model = LearningPathDownloadModel(
        learningPathId: 'path-1',
        learningPathTitle: 'Foundations',
        language: 'en',
        topics: [testTopic],
        status: PathDownloadStatus.downloading,
        queuedAt: DateTime(2026, 4, 4),
        completedCount: 0,
        totalCount: 1,
      );

      await service.processDownloadLoop(model);

      final state = service.getDownload('path-1');
      // Path marked failed (0 completed, no successes)
      expect(state?.topics.first.status, TopicDownloadStatus.failed);
    });

    test('skips already-done topics on resume', () async {
      final doneTopic = testTopic.copyWith(status: TopicDownloadStatus.done);

      final model = LearningPathDownloadModel(
        learningPathId: 'path-1',
        learningPathTitle: 'Foundations',
        language: 'en',
        topics: [doneTopic],
        status: PathDownloadStatus.downloading,
        queuedAt: DateTime(2026, 4, 4),
        completedCount: 1,
        totalCount: 1,
      );

      await service.processDownloadLoop(model);

      // generateStudyGuide never called because topic is already done
      verifyNever(mockGenerateStudyGuide(any));
      expect(
          service.getDownload('path-1')?.status, PathDownloadStatus.completed);
    });
  });

  group('deleteTopic', () {
    test('deletes guide from local data source', () async {
      final box = await Hive.openBox<Map>('learning_path_downloads');
      await box.put('path-delete', {
        'learningPathId': 'path-delete',
        'learningPathTitle': 'Romans',
        'language': 'en',
        'topics': [
          {
            'topicId': 'topic-1',
            'topicTitle': 'Romans 1',
            'inputType': 'topic',
            'description': '',
            'studyMode': 'standard',
            'status': 'done',
            'cachedGuideId': 'guide-abc',
          },
          {
            'topicId': 'topic-2',
            'topicTitle': 'Romans 2',
            'inputType': 'topic',
            'description': '',
            'studyMode': 'standard',
            'status': 'done',
            'cachedGuideId': 'guide-xyz',
          },
        ],
        'status': 'completed',
        'queuedAt': DateTime(2026, 4, 7).toIso8601String(),
        'completedCount': 2,
        'totalCount': 2,
      });

      when(mockLocalDataSource.deleteStudyGuide('guide-abc'))
          .thenAnswer((_) async => true);

      await service.deleteTopic('path-delete', 'guide-abc');

      verify(mockLocalDataSource.deleteStudyGuide('guide-abc')).called(1);
    });

    test('decrements completedCount after single guide deletion', () async {
      final box = await Hive.openBox<Map>('learning_path_downloads');
      await box.put('path-decrement', {
        'learningPathId': 'path-decrement',
        'learningPathTitle': 'Psalms',
        'language': 'en',
        'topics': [
          {
            'topicId': 'topic-1',
            'topicTitle': 'Psalm 1',
            'inputType': 'topic',
            'description': '',
            'studyMode': 'standard',
            'status': 'done',
            'cachedGuideId': 'guide-p1',
          },
          {
            'topicId': 'topic-2',
            'topicTitle': 'Psalm 2',
            'inputType': 'topic',
            'description': '',
            'studyMode': 'standard',
            'status': 'done',
            'cachedGuideId': 'guide-p2',
          },
        ],
        'status': 'completed',
        'queuedAt': DateTime(2026, 4, 7).toIso8601String(),
        'completedCount': 2,
        'totalCount': 2,
      });

      when(mockLocalDataSource.deleteStudyGuide('guide-p1'))
          .thenAnswer((_) async => true);

      await service.deleteTopic('path-decrement', 'guide-p1');

      final downloads = await service.getAllDownloads();
      final updated =
          downloads.firstWhere((d) => d.learningPathId == 'path-decrement');
      expect(updated.completedCount, 1);
    });

    test('removes entire path record when last guide is deleted', () async {
      final box = await Hive.openBox<Map>('learning_path_downloads');
      await box.put('path-last', {
        'learningPathId': 'path-last',
        'learningPathTitle': 'Single Guide Path',
        'language': 'en',
        'topics': [
          {
            'topicId': 'topic-1',
            'topicTitle': 'Only Topic',
            'inputType': 'topic',
            'description': '',
            'studyMode': 'standard',
            'status': 'done',
            'cachedGuideId': 'guide-only',
          },
        ],
        'status': 'completed',
        'queuedAt': DateTime(2026, 4, 7).toIso8601String(),
        'completedCount': 1,
        'totalCount': 1,
      });

      when(mockLocalDataSource.deleteStudyGuide('guide-only'))
          .thenAnswer((_) async => true);

      await service.deleteTopic('path-last', 'guide-only');

      final downloads = await service.getAllDownloads();
      expect(downloads.any((d) => d.learningPathId == 'path-last'), isFalse);
    });
  });
}
