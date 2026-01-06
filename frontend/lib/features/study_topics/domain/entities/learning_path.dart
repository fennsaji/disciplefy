import 'package:equatable/equatable.dart';

/// Represents a learning path - a curated collection of topics
/// for structured learning journeys.
class LearningPath extends Equatable {
  final String id;
  final String slug;
  final String title;
  final String description;
  final String iconName;
  final String color;
  final int totalXp;
  final int estimatedDays;
  final String discipleLevel;
  final String? recommendedMode;
  final bool allowNonSequentialAccess;
  final bool isFeatured;
  final int topicsCount;
  final bool isEnrolled;
  final int progressPercentage;

  const LearningPath({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.iconName,
    required this.color,
    required this.totalXp,
    required this.estimatedDays,
    required this.discipleLevel,
    this.recommendedMode,
    this.allowNonSequentialAccess = false,
    this.isFeatured = false,
    this.topicsCount = 0,
    this.isEnrolled = false,
    this.progressPercentage = 0,
  });

  @override
  List<Object?> get props => [
        id,
        slug,
        title,
        description,
        iconName,
        color,
        totalXp,
        estimatedDays,
        discipleLevel,
        recommendedMode,
        allowNonSequentialAccess,
        isFeatured,
        topicsCount,
        isEnrolled,
        progressPercentage,
      ];

  /// Whether the path is completed
  bool get isCompleted => progressPercentage >= 100;

  /// Whether the path is in progress
  bool get isInProgress => isEnrolled && progressPercentage > 0 && !isCompleted;
}

/// Represents a topic within a learning path with progress information.
class LearningPathTopic extends Equatable {
  final int position;
  final bool isMilestone;
  final String topicId;
  final String title;
  final String description;
  final String category;
  final String inputType; // 'topic', 'verse', or 'question'
  final int xpValue;
  final bool isCompleted;
  final bool isInProgress;

  const LearningPathTopic({
    required this.position,
    required this.isMilestone,
    required this.topicId,
    required this.title,
    required this.description,
    required this.category,
    this.inputType = 'topic', // Default to 'topic' for backward compatibility
    required this.xpValue,
    this.isCompleted = false,
    this.isInProgress = false,
  });

  @override
  List<Object?> get props => [
        position,
        isMilestone,
        topicId,
        title,
        description,
        category,
        inputType,
        xpValue,
        isCompleted,
        isInProgress,
      ];
}

/// Learning path with detailed information including topics.
class LearningPathDetail extends LearningPath {
  final int topicsCompleted;
  final DateTime? enrolledAt;
  final List<LearningPathTopic> topics;

  const LearningPathDetail({
    required super.id,
    required super.slug,
    required super.title,
    required super.description,
    required super.iconName,
    required super.color,
    required super.totalXp,
    required super.estimatedDays,
    required super.discipleLevel,
    super.recommendedMode,
    super.allowNonSequentialAccess,
    super.isFeatured,
    super.topicsCount,
    super.isEnrolled,
    super.progressPercentage,
    this.topicsCompleted = 0,
    this.enrolledAt,
    this.topics = const [],
  });

  @override
  List<Object?> get props => [
        ...super.props,
        topicsCompleted,
        enrolledAt,
        topics,
      ];

  /// Get the next topic to study
  LearningPathTopic? get nextTopic {
    for (final topic in topics) {
      if (!topic.isCompleted) {
        return topic;
      }
    }
    return null;
  }
}

/// Result container for learning paths list.
class LearningPathsResult {
  final List<LearningPath> paths;
  final int total;

  const LearningPathsResult({
    required this.paths,
    required this.total,
  });
}

/// Enrollment result from enrolling in a path.
class EnrollmentResult {
  final String id;
  final String learningPathId;
  final DateTime enrolledAt;
  final DateTime startedAt;

  const EnrollmentResult({
    required this.id,
    required this.learningPathId,
    required this.enrolledAt,
    required this.startedAt,
  });
}

/// Reason for why a learning path is being recommended.
enum LearningPathRecommendationReason {
  /// User has an active (in-progress) learning path
  active,

  /// Recommended based on personalization questionnaire
  personalized,

  /// Featured learning path (default recommendation)
  featured,
}

/// Result container for recommended learning path.
class RecommendedPathResult {
  final LearningPath path;
  final LearningPathRecommendationReason reason;

  const RecommendedPathResult({
    required this.path,
    required this.reason,
  });

  /// Helper to parse reason from string
  static LearningPathRecommendationReason parseReason(String reason) {
    switch (reason) {
      case 'active':
        return LearningPathRecommendationReason.active;
      case 'personalized':
        return LearningPathRecommendationReason.personalized;
      case 'featured':
      default:
        return LearningPathRecommendationReason.featured;
    }
  }
}
