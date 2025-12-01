import 'package:equatable/equatable.dart';
import '../../domain/entities/recommended_guide_topic.dart';
import '../../../study_generation/domain/entities/study_guide.dart';
import '../../../study_topics/domain/entities/learning_path.dart';

// Re-export the reason enum for easy access
export '../../../study_topics/domain/entities/learning_path.dart'
    show LearningPathRecommendationReason;

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

  /// Whether to show the personalization questionnaire prompt.
  ///
  /// This is true when the user is authenticated but hasn't completed
  /// or skipped the personalization questionnaire yet.
  final bool showPersonalizationPrompt;

  /// Whether the topics are personalized based on questionnaire responses.
  ///
  /// If false, topics are based on study history or default recommendations.
  final bool isPersonalized;

  /// The user's recommended learning path to display in For You section.
  ///
  /// This can be an active (in-progress) path, a personalized recommendation,
  /// or a featured path for new/anonymous users.
  final LearningPath? activeLearningPath;

  /// The reason why this learning path is being shown.
  ///
  /// - 'active': User has an in-progress learning path
  /// - 'personalized': Recommended based on questionnaire answers
  /// - 'featured': Default featured path (for anonymous/new users)
  final LearningPathRecommendationReason? learningPathReason;

  /// Whether the active learning path is currently loading.
  final bool isLoadingActivePath;

  const HomeCombinedState({
    this.topics = const [],
    this.isLoadingTopics = false,
    this.topicsError,
    this.isGeneratingStudyGuide = false,
    this.generationInput,
    this.generationInputType,
    this.generationError,
    this.showPersonalizationPrompt = false,
    this.isPersonalized = false,
    this.activeLearningPath,
    this.learningPathReason,
    this.isLoadingActivePath = false,
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
        showPersonalizationPrompt,
        isPersonalized,
        activeLearningPath,
        learningPathReason,
        isLoadingActivePath,
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
    bool? showPersonalizationPrompt,
    bool? isPersonalized,
    LearningPath? activeLearningPath,
    LearningPathRecommendationReason? learningPathReason,
    bool? isLoadingActivePath,
    bool clearTopicsError = false,
    bool clearGenerationError = false,
    bool clearActiveLearningPath = false,
  }) =>
      HomeCombinedState(
        topics: topics ?? this.topics,
        isLoadingTopics: isLoadingTopics ?? this.isLoadingTopics,
        topicsError:
            clearTopicsError ? null : (topicsError ?? this.topicsError),
        isGeneratingStudyGuide:
            isGeneratingStudyGuide ?? this.isGeneratingStudyGuide,
        generationInput: generationInput ?? this.generationInput,
        generationInputType: generationInputType ?? this.generationInputType,
        generationError: clearGenerationError
            ? null
            : (generationError ?? this.generationError),
        showPersonalizationPrompt:
            showPersonalizationPrompt ?? this.showPersonalizationPrompt,
        isPersonalized: isPersonalized ?? this.isPersonalized,
        activeLearningPath: clearActiveLearningPath
            ? null
            : (activeLearningPath ?? this.activeLearningPath),
        learningPathReason: clearActiveLearningPath
            ? null
            : (learningPathReason ?? this.learningPathReason),
        isLoadingActivePath: isLoadingActivePath ?? this.isLoadingActivePath,
      );
}

/// Combined state when study guide generation is complete - preserves topics list
class HomeStudyGuideGeneratedCombined extends HomeCombinedState {
  final StudyGuide studyGuide;

  const HomeStudyGuideGeneratedCombined({
    required this.studyGuide,
    super.topics,
    super.isLoadingTopics,
    super.topicsError,
    super.generationInput,
    super.generationInputType,
    super.showPersonalizationPrompt,
    super.isPersonalized,
    super.activeLearningPath,
    super.learningPathReason,
    super.isLoadingActivePath,
  }) : super(
          isGeneratingStudyGuide: false,
          generationError: null,
        );

  @override
  List<Object?> get props => [
        studyGuide,
        ...super.props,
      ];
}
