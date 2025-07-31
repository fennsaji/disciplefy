import 'package:equatable/equatable.dart';
import '../../domain/entities/recommended_guide_topic.dart';
import '../../../study_generation/domain/entities/study_guide.dart';

/// States for the Home screen
abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class HomeInitial extends HomeState {
  const HomeInitial();
}

/// Loading state for recommended topics
class HomeTopicsLoading extends HomeState {
  const HomeTopicsLoading();
}

/// State when recommended topics are loaded successfully
class HomeTopicsLoaded extends HomeState {
  final List<RecommendedGuideTopic> topics;

  const HomeTopicsLoaded({
    required this.topics,
  });

  @override
  List<Object?> get props => [topics];
}

/// Error state for recommended topics
class HomeTopicsError extends HomeState {
  final String message;

  const HomeTopicsError({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}

/// State when generating study guide
class HomeGeneratingStudyGuide extends HomeState {
  final String input;
  final String inputType; // 'verse' or 'topic'

  const HomeGeneratingStudyGuide({
    required this.input,
    required this.inputType,
  });

  @override
  List<Object?> get props => [input, inputType];
}

/// State when study guide generation is complete
class HomeStudyGuideGenerated extends HomeState {
  final StudyGuide studyGuide;

  const HomeStudyGuideGenerated({
    required this.studyGuide,
  });

  @override
  List<Object?> get props => [studyGuide];
}

/// Error state for study guide generation
class HomeStudyGuideError extends HomeState {
  final String message;
  final String input;
  final String inputType;

  const HomeStudyGuideError({
    required this.message,
    required this.input,
    required this.inputType,
  });

  @override
  List<Object?> get props => [message, input, inputType];
}

/// Combined state with topics and generation status
class HomeCombinedState extends HomeState {
  final List<RecommendedGuideTopic> topics;
  final bool isLoadingTopics;
  final String? topicsError;
  final bool isGeneratingStudyGuide;
  final String? generationInput;
  final String? generationInputType;
  final String? generationError;

  const HomeCombinedState({
    this.topics = const [],
    this.isLoadingTopics = false,
    this.topicsError,
    this.isGeneratingStudyGuide = false,
    this.generationInput,
    this.generationInputType,
    this.generationError,
  });

  @override
  List<Object?> get props => [
        topics,
        isLoadingTopics,
        topicsError,
        isGeneratingStudyGuide,
        generationInput,
        generationInputType,
        generationError,
      ];

  /// Create a copy with updated values
  HomeCombinedState copyWith({
    List<RecommendedGuideTopic>? topics,
    bool? isLoadingTopics,
    String? topicsError,
    bool? isGeneratingStudyGuide,
    String? generationInput,
    String? generationInputType,
    String? generationError,
    bool clearTopicsError = false,
    bool clearGenerationError = false,
  }) => HomeCombinedState(
      topics: topics ?? this.topics,
      isLoadingTopics: isLoadingTopics ?? this.isLoadingTopics,
      topicsError: clearTopicsError ? null : (topicsError ?? this.topicsError),
      isGeneratingStudyGuide: isGeneratingStudyGuide ?? this.isGeneratingStudyGuide,
      generationInput: generationInput ?? this.generationInput,
      generationInputType: generationInputType ?? this.generationInputType,
      generationError: clearGenerationError ? null : (generationError ?? this.generationError),
    );
}