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

  /// Whether to show the personalization questionnaire prompt.
  ///
  /// This is true when the user is authenticated but hasn't completed
  /// or skipped the personalization questionnaire yet.
  final bool showPersonalizationPrompt;

  /// Whether these topics are personalized based on questionnaire responses.
  ///
  /// If false, topics are based on study history or default recommendations.
  final bool isPersonalized;

  const RecommendedTopicsLoaded({
    required this.topics,
    this.showPersonalizationPrompt = false,
    this.isPersonalized = false,
  });

  @override
  List<Object?> get props =>
      [topics, showPersonalizationPrompt, isPersonalized];

  /// Create a copy with updated values.
  RecommendedTopicsLoaded copyWith({
    List<RecommendedGuideTopic>? topics,
    bool? showPersonalizationPrompt,
    bool? isPersonalized,
  }) {
    return RecommendedTopicsLoaded(
      topics: topics ?? this.topics,
      showPersonalizationPrompt:
          showPersonalizationPrompt ?? this.showPersonalizationPrompt,
      isPersonalized: isPersonalized ?? this.isPersonalized,
    );
  }
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
