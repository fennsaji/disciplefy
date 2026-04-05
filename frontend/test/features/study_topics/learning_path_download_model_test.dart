import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_download_model.dart';

void main() {
  group('LearningPathDownloadModel', () {
    test('serializes and deserializes correctly', () {
      final model = LearningPathDownloadModel(
        learningPathId: 'path-1',
        learningPathTitle: 'Foundations of Faith',
        language: 'en',
        topics: [
          LearningPathTopicDownload(
            topicId: 'topic-1',
            topicTitle: 'Grace',
            inputType: 'topic',
            description: 'Understanding grace',
            studyMode: 'standard',
            status: TopicDownloadStatus.pending,
          ),
        ],
        status: PathDownloadStatus.queued,
        queuedAt: DateTime(2026, 4, 4),
        completedCount: 0,
        totalCount: 1,
      );

      final map = model.toMap();
      final restored = LearningPathDownloadModel.fromMap(map);

      expect(restored.learningPathId, 'path-1');
      expect(restored.learningPathTitle, 'Foundations of Faith');
      expect(restored.language, 'en');
      expect(restored.status, PathDownloadStatus.queued);
      expect(restored.topics.length, 1);
      expect(restored.topics.first.topicTitle, 'Grace');
      expect(restored.topics.first.status, TopicDownloadStatus.pending);
      expect(restored.completedCount, 0);
      expect(restored.totalCount, 1);
    });

    test('LearningPathTopicDownload serializes cachedGuideId as null', () {
      final topic = LearningPathTopicDownload(
        topicId: 'topic-1',
        topicTitle: 'Grace',
        inputType: 'topic',
        description: '',
        studyMode: 'standard',
        status: TopicDownloadStatus.done,
        cachedGuideId: 'guide-abc',
      );

      final map = topic.toMap();
      final restored = LearningPathTopicDownload.fromMap(map);

      expect(restored.cachedGuideId, 'guide-abc');
    });

    test('copyWith updates status correctly', () {
      final model = LearningPathDownloadModel(
        learningPathId: 'p1',
        learningPathTitle: 'Test',
        language: 'en',
        topics: [],
        status: PathDownloadStatus.queued,
        queuedAt: DateTime(2026, 4, 4),
        completedCount: 0,
        totalCount: 5,
      );

      final updated = model.copyWith(
        status: PathDownloadStatus.downloading,
        completedCount: 2,
      );

      expect(updated.status, PathDownloadStatus.downloading);
      expect(updated.completedCount, 2);
      expect(updated.learningPathId, 'p1');
    });
  });
}
