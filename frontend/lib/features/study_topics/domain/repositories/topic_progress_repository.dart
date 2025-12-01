import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/topic_progress.dart';

/// Result from completing a topic.
class TopicCompletionResult {
  /// Unique ID of the progress record
  final String? progressId;

  /// XP earned from this completion (0 if repeat completion)
  final int xpEarned;

  /// Whether this was the first time completing the topic
  final bool isFirstCompletion;

  /// Title of the completed topic
  final String? topicTitle;

  const TopicCompletionResult({
    this.progressId,
    required this.xpEarned,
    required this.isFirstCompletion,
    this.topicTitle,
  });
}

/// Abstract repository for topic progress operations.
///
/// This repository defines the contract for tracking user progress
/// on study topics, including starting, completing, and fetching
/// in-progress topics.
abstract class TopicProgressRepository {
  /// Starts tracking progress on a topic.
  ///
  /// Called when a user opens a topic for study.
  ///
  /// [topicId] - The topic being started
  ///
  /// Returns [Right] on success,
  /// [Left] with [Failure] on error.
  Future<Either<Failure, void>> startTopic(String topicId);

  /// Marks a topic as completed and awards XP.
  ///
  /// Called when a user finishes studying a topic.
  /// XP is only awarded on first completion.
  ///
  /// [topicId] - The topic being completed
  /// [timeSpentSeconds] - Total time spent on this session
  ///
  /// Returns [Right] with completion result on success,
  /// [Left] with [Failure] on error.
  Future<Either<Failure, TopicCompletionResult>> completeTopic(
    String topicId, {
    int timeSpentSeconds = 0,
  });

  /// Updates time spent on a topic without completing it.
  ///
  /// Called periodically during study sessions.
  ///
  /// [topicId] - The topic being studied
  /// [timeSpentSeconds] - Additional time to add
  ///
  /// Returns [Right] on success,
  /// [Left] with [Failure] on error.
  Future<Either<Failure, void>> updateTimeSpent(
    String topicId,
    int timeSpentSeconds,
  );

  /// Fetches in-progress topics for the "Continue Learning" section.
  ///
  /// Returns topics the user has started but not completed,
  /// ordered by most recently accessed.
  ///
  /// [language] - Language code for localization
  /// [limit] - Maximum number of topics to return
  ///
  /// Returns [Right] with list of in-progress topics,
  /// [Left] with [Failure] on error.
  Future<Either<Failure, List<InProgressTopic>>> getInProgressTopics({
    String language = 'en',
    int limit = 5,
  });
}
