// lib/features/study_topics/data/models/learning_path_download_model.dart

enum PathDownloadStatus { queued, downloading, completed, failed, paused }

enum TopicDownloadStatus { pending, downloading, done, failed }

/// Plain Dart model for a learning path download job.
/// Stored as `Map<String, dynamic>` in Hive box 'learning_path_downloads'.
class LearningPathDownloadModel {
  final String learningPathId;
  final String learningPathTitle;
  final String language;
  final List<LearningPathTopicDownload> topics;
  final PathDownloadStatus status;
  final DateTime queuedAt;
  final int completedCount;
  final int totalCount;

  const LearningPathDownloadModel({
    required this.learningPathId,
    required this.learningPathTitle,
    required this.language,
    required this.topics,
    required this.status,
    required this.queuedAt,
    required this.completedCount,
    required this.totalCount,
  });

  LearningPathDownloadModel copyWith({
    List<LearningPathTopicDownload>? topics,
    PathDownloadStatus? status,
    int? completedCount,
    int? totalCount,
  }) {
    return LearningPathDownloadModel(
      learningPathId: learningPathId,
      learningPathTitle: learningPathTitle,
      language: language,
      topics: topics ?? this.topics,
      status: status ?? this.status,
      queuedAt: queuedAt,
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'learningPathId': learningPathId,
      'learningPathTitle': learningPathTitle,
      'language': language,
      'topics': topics.map((t) => t.toMap()).toList(),
      'status': status.name,
      'queuedAt': queuedAt.toIso8601String(),
      'completedCount': completedCount,
      'totalCount': totalCount,
    };
  }

  factory LearningPathDownloadModel.fromMap(Map<dynamic, dynamic> map) {
    return LearningPathDownloadModel(
      learningPathId: map['learningPathId'] as String,
      learningPathTitle: map['learningPathTitle'] as String,
      language: map['language'] as String? ?? 'en',
      topics: (map['topics'] as List<dynamic>)
          .map((t) =>
              LearningPathTopicDownload.fromMap(t as Map<dynamic, dynamic>))
          .toList(),
      status: PathDownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PathDownloadStatus.queued,
      ),
      queuedAt: DateTime.parse(map['queuedAt'] as String),
      completedCount: map['completedCount'] as int? ?? 0,
      totalCount: map['totalCount'] as int? ?? 0,
    );
  }
}

/// State of one topic within a download job.
class LearningPathTopicDownload {
  final String topicId;
  final String topicTitle;
  final String inputType;
  final String description;
  final String studyMode;
  final TopicDownloadStatus status;
  final String? cachedGuideId;

  const LearningPathTopicDownload({
    required this.topicId,
    required this.topicTitle,
    required this.inputType,
    required this.description,
    required this.studyMode,
    required this.status,
    this.cachedGuideId,
  });

  LearningPathTopicDownload copyWith({
    TopicDownloadStatus? status,
    String? cachedGuideId,
  }) {
    return LearningPathTopicDownload(
      topicId: topicId,
      topicTitle: topicTitle,
      inputType: inputType,
      description: description,
      studyMode: studyMode,
      status: status ?? this.status,
      cachedGuideId: cachedGuideId ?? this.cachedGuideId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'topicId': topicId,
      'topicTitle': topicTitle,
      'inputType': inputType,
      'description': description,
      'studyMode': studyMode,
      'status': status.name,
      'cachedGuideId': cachedGuideId,
    };
  }

  factory LearningPathTopicDownload.fromMap(Map<dynamic, dynamic> map) {
    return LearningPathTopicDownload(
      topicId: map['topicId'] as String? ?? '',
      topicTitle: map['topicTitle'] as String,
      inputType: map['inputType'] as String? ?? 'topic',
      description: map['description'] as String? ?? '',
      studyMode: map['studyMode'] as String? ?? 'standard',
      status: TopicDownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TopicDownloadStatus.pending,
      ),
      cachedGuideId: map['cachedGuideId'] as String?,
    );
  }
}
