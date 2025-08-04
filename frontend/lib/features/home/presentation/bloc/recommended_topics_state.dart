import 'package:equatable/equatable.dart';

import '../../domain/entities/recommended_guide_topic.dart';

/// States for the Recommended Topics BLoC.
abstract class RecommendedTopicsState extends Equatable {
  const RecommendedTopicsState();

  @override
  List<Object?> get props => [];
}

/// Initial state when no topics have been loaded yet.
class RecommendedTopicsInitial extends RecommendedTopicsState {
  const RecommendedTopicsInitial();
}

/// State when recommended topics are being loaded.
class RecommendedTopicsLoading extends RecommendedTopicsState {
  const RecommendedTopicsLoading();
}

/// State when recommended topics have been loaded successfully.
class RecommendedTopicsLoaded extends RecommendedTopicsState {
  /// The list of loaded recommended topics.
  final List<RecommendedGuideTopic> topics;

  const RecommendedTopicsLoaded({
    required this.topics,
  });

  @override
  List<Object?> get props => [topics];
}

/// State when there was an error loading recommended topics.
class RecommendedTopicsError extends RecommendedTopicsState {
  /// The error message.
  final String message;

  /// Optional error code for specific error handling.
  final String? errorCode;

  const RecommendedTopicsError({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}
