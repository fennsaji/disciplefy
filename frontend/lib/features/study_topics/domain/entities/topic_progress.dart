import 'package:equatable/equatable.dart';

/// Entity representing user's progress on a study topic.
///
/// Tracks when a user started a topic, completion status,
/// time spent studying, and XP earned.
class TopicProgress extends Equatable {
  /// Topic ID this progress is for
  final String topicId;

  /// When the user started this topic (null if not started)
  final DateTime? startedAt;

  /// When the user completed this topic (null if not completed)
  final DateTime? completedAt;

  /// Total time spent studying this topic in seconds
  final int timeSpentSeconds;

  /// XP earned from this topic (only awarded on first completion)
  final int xpEarned;

  /// Whether the topic has been completed
  bool get isCompleted => completedAt != null;

  /// Whether the topic has been started but not completed
  bool get isInProgress => startedAt != null && completedAt == null;

  /// Whether the topic has not been started
  bool get isNotStarted => startedAt == null;

  /// Formatted time spent (e.g., "5m", "1h 30m")
  String get formattedTimeSpent {
    if (timeSpentSeconds == 0) return '0m';

    final hours = timeSpentSeconds ~/ 3600;
    final minutes = (timeSpentSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  const TopicProgress({
    required this.topicId,
    this.startedAt,
    this.completedAt,
    this.timeSpentSeconds = 0,
    this.xpEarned = 0,
  });

  @override
  List<Object?> get props => [
        topicId,
        startedAt,
        completedAt,
        timeSpentSeconds,
        xpEarned,
      ];

  TopicProgress copyWith({
    String? topicId,
    DateTime? startedAt,
    DateTime? completedAt,
    int? timeSpentSeconds,
    int? xpEarned,
  }) {
    return TopicProgress(
      topicId: topicId ?? this.topicId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      xpEarned: xpEarned ?? this.xpEarned,
    );
  }

  @override
  String toString() =>
      'TopicProgress(topicId: $topicId, isCompleted: $isCompleted, xpEarned: $xpEarned)';
}

/// Entity representing an in-progress topic with full topic details.
///
/// Used for the "Continue Learning" section to show topics
/// the user has started but not completed.
class InProgressTopic extends Equatable {
  /// Topic ID
  final String topicId;

  /// Topic title
  final String title;

  /// Topic description
  final String description;

  /// Topic category
  final String category;

  /// When the user started this topic
  final DateTime startedAt;

  /// Total time spent studying this topic in seconds
  final int timeSpentSeconds;

  /// XP value that will be awarded upon completion
  final int xpValue;

  /// Learning path ID if this topic is part of a learning path
  final String? learningPathId;

  /// Learning path name if this topic is part of a learning path
  final String? learningPathName;

  /// Position of this topic within the learning path (1-based)
  final int? positionInPath;

  /// Total number of topics in the learning path
  final int? totalTopicsInPath;

  /// Number of topics completed in the learning path
  final int? topicsCompletedInPath;

  /// Recommended study mode for this topic's learning path
  final String? recommendedMode;

  /// Whether this topic is from a learning path
  bool get isFromLearningPath =>
      learningPathId != null && learningPathId!.isNotEmpty;

  /// Formatted time spent (e.g., "5m", "1h 30m")
  String get formattedTimeSpent {
    if (timeSpentSeconds == 0) return '0m';

    final hours = timeSpentSeconds ~/ 3600;
    final minutes = (timeSpentSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  /// Formatted position in path (e.g., "3 of 10")
  String get formattedPositionInPath {
    if (positionInPath == null || totalTopicsInPath == null) return '';
    return '$positionInPath of $totalTopicsInPath';
  }

  /// Formatted progress in path showing completed topics (e.g., "5 of 10 completed")
  String get formattedProgressInPath {
    if (topicsCompletedInPath == null || totalTopicsInPath == null) return '';
    return '$topicsCompletedInPath of $totalTopicsInPath';
  }

  const InProgressTopic({
    required this.topicId,
    required this.title,
    required this.description,
    required this.category,
    required this.startedAt,
    this.timeSpentSeconds = 0,
    this.xpValue = 50,
    this.learningPathId,
    this.learningPathName,
    this.positionInPath,
    this.totalTopicsInPath,
    this.topicsCompletedInPath,
    this.recommendedMode,
  });

  @override
  List<Object?> get props => [
        topicId,
        title,
        description,
        category,
        startedAt,
        timeSpentSeconds,
        xpValue,
        learningPathId,
        learningPathName,
        positionInPath,
        totalTopicsInPath,
        topicsCompletedInPath,
        recommendedMode,
      ];

  @override
  String toString() =>
      'InProgressTopic(topicId: $topicId, title: $title, timeSpent: $formattedTimeSpent, learningPath: $learningPathName)';
}
