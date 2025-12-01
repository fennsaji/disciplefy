import 'package:equatable/equatable.dart';

import '../../domain/entities/topic_progress.dart';

/// States for ContinueLearningBloc
abstract class ContinueLearningState extends Equatable {
  const ContinueLearningState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any action.
class ContinueLearningInitial extends ContinueLearningState {
  const ContinueLearningInitial();
}

/// Loading state while fetching in-progress topics.
class ContinueLearningLoading extends ContinueLearningState {
  const ContinueLearningLoading();
}

/// Loaded state with in-progress topics.
class ContinueLearningLoaded extends ContinueLearningState {
  /// List of in-progress topics
  final List<InProgressTopic> topics;

  const ContinueLearningLoaded({
    required this.topics,
  });

  @override
  List<Object?> get props => [topics];

  /// Whether there are topics to display
  bool get hasTopics => topics.isNotEmpty;

  /// Number of in-progress topics
  int get count => topics.length;
}

/// Error state when fetching failed.
class ContinueLearningError extends ContinueLearningState {
  /// Error message to display
  final String message;

  const ContinueLearningError({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}

/// Empty state when no in-progress topics exist.
class ContinueLearningEmpty extends ContinueLearningState {
  const ContinueLearningEmpty();
}
