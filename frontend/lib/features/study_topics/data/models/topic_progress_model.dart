import '../../domain/entities/topic_progress.dart';

/// Model for TopicProgress with JSON serialization support.
class TopicProgressModel extends TopicProgress {
  const TopicProgressModel({
    required super.topicId,
    super.startedAt,
    super.completedAt,
    super.timeSpentSeconds,
    super.xpEarned,
  });

  /// Creates a TopicProgressModel from JSON data.
  factory TopicProgressModel.fromJson(Map<String, dynamic> json) {
    return TopicProgressModel(
      topicId: json['topic_id'] as String,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      timeSpentSeconds: json['time_spent_seconds'] as int? ?? 0,
      xpEarned: json['xp_earned'] as int? ?? 0,
    );
  }

  /// Converts the model to JSON.
  Map<String, dynamic> toJson() {
    return {
      'topic_id': topicId,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'time_spent_seconds': timeSpentSeconds,
      'xp_earned': xpEarned,
    };
  }

  /// Converts to domain entity.
  TopicProgress toEntity() {
    return TopicProgress(
      topicId: topicId,
      startedAt: startedAt,
      completedAt: completedAt,
      timeSpentSeconds: timeSpentSeconds,
      xpEarned: xpEarned,
    );
  }
}

/// Model for InProgressTopic with JSON serialization support.
class InProgressTopicModel extends InProgressTopic {
  const InProgressTopicModel({
    required super.topicId,
    required super.title,
    required super.description,
    required super.category,
    required super.startedAt,
    super.timeSpentSeconds,
    super.xpValue,
    super.learningPathId,
    super.learningPathName,
    super.positionInPath,
    super.totalTopicsInPath,
    super.topicsCompletedInPath,
  });

  /// Creates an InProgressTopicModel from JSON data.
  factory InProgressTopicModel.fromJson(Map<String, dynamic> json) {
    return InProgressTopicModel(
      topicId: json['topic_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      timeSpentSeconds: json['time_spent_seconds'] as int? ?? 0,
      xpValue: json['xp_value'] as int? ?? 50,
      learningPathId: json['learning_path_id'] as String?,
      learningPathName: json['learning_path_name'] as String?,
      positionInPath: json['position_in_path'] as int?,
      totalTopicsInPath: json['total_topics_in_path'] as int?,
      topicsCompletedInPath: json['topics_completed_in_path'] as int?,
    );
  }

  /// Converts the model to JSON.
  Map<String, dynamic> toJson() {
    return {
      'topic_id': topicId,
      'title': title,
      'description': description,
      'category': category,
      'started_at': startedAt.toIso8601String(),
      'time_spent_seconds': timeSpentSeconds,
      'xp_value': xpValue,
      'learning_path_id': learningPathId,
      'learning_path_name': learningPathName,
      'position_in_path': positionInPath,
      'total_topics_in_path': totalTopicsInPath,
      'topics_completed_in_path': topicsCompletedInPath,
    };
  }

  /// Converts to domain entity.
  InProgressTopic toEntity() {
    return InProgressTopic(
      topicId: topicId,
      title: title,
      description: description,
      category: category,
      startedAt: startedAt,
      timeSpentSeconds: timeSpentSeconds,
      xpValue: xpValue,
      learningPathId: learningPathId,
      learningPathName: learningPathName,
      positionInPath: positionInPath,
      totalTopicsInPath: totalTopicsInPath,
      topicsCompletedInPath: topicsCompletedInPath,
    );
  }
}

/// Response model for continue-learning endpoint.
class ContinueLearningResponse {
  final List<InProgressTopicModel> topics;
  final int total;

  const ContinueLearningResponse({
    required this.topics,
    required this.total,
  });

  factory ContinueLearningResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final topicsList = (data['topics'] as List<dynamic>?) ?? <dynamic>[];

    return ContinueLearningResponse(
      topics: topicsList
          .map((t) => InProgressTopicModel.fromJson(t as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  List<InProgressTopic> toEntities() {
    return topics.map((t) => t.toEntity()).toList();
  }
}

/// Response model for topic-progress endpoint actions.
class TopicProgressActionResponse {
  final bool success;
  final String? progressId;
  final int? xpEarned;
  final bool? isFirstCompletion;
  final String? topicTitle;

  const TopicProgressActionResponse({
    required this.success,
    this.progressId,
    this.xpEarned,
    this.isFirstCompletion,
    this.topicTitle,
  });

  factory TopicProgressActionResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;

    return TopicProgressActionResponse(
      success: json['success'] as bool? ?? false,
      progressId: data?['progress_id'] as String? ?? data?['id'] as String?,
      xpEarned: data?['xp_earned'] as int?,
      isFirstCompletion: data?['is_first_completion'] as bool?,
      topicTitle: data?['topic_title'] as String?,
    );
  }
}
