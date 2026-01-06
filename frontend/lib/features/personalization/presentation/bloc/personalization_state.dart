import 'package:equatable/equatable.dart';

import '../../domain/entities/personalization_entity.dart';

/// Base state for personalization
abstract class PersonalizationState extends Equatable {
  const PersonalizationState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class PersonalizationInitial extends PersonalizationState {
  const PersonalizationInitial();
}

/// Loading personalization data
class PersonalizationLoading extends PersonalizationState {
  const PersonalizationLoading();
}

/// Personalization data loaded - user needs questionnaire
class PersonalizationNeedsQuestionnaire extends PersonalizationState {
  const PersonalizationNeedsQuestionnaire();
}

/// Personalization already completed or skipped
class PersonalizationComplete extends PersonalizationState {
  final PersonalizationEntity personalization;

  const PersonalizationComplete(this.personalization);

  @override
  List<Object?> get props => [personalization];
}

/// Personalization skipped due to error (graceful degradation)
/// This state allows the app to continue without blocking the user
class PersonalizationSkipped extends PersonalizationState {
  const PersonalizationSkipped();
}

/// User is filling out the questionnaire (6 questions)
class QuestionnaireInProgress extends PersonalizationState {
  final int currentQuestion; // 0-5 (6 questions total)
  final FaithStage? faithStage;
  final List<SpiritualGoal> spiritualGoals;
  final TimeAvailability? timeAvailability;
  final LearningStyle? learningStyle;
  final LifeStageFocus? lifeStageFocus;
  final BiggestChallenge? biggestChallenge;

  const QuestionnaireInProgress({
    this.currentQuestion = 0,
    this.faithStage,
    this.spiritualGoals = const [],
    this.timeAvailability,
    this.learningStyle,
    this.lifeStageFocus,
    this.biggestChallenge,
  });

  /// Check if user can proceed to next question
  bool get canProceed {
    switch (currentQuestion) {
      case 0: // Question 1: Faith Stage
        return faithStage != null;
      case 1: // Question 2: Spiritual Goals (1-3 selections)
        return spiritualGoals.isNotEmpty && spiritualGoals.length <= 3;
      case 2: // Question 3: Time Availability
        return timeAvailability != null;
      case 3: // Question 4: Learning Style
        return learningStyle != null;
      case 4: // Question 5: Life Stage Focus
        return lifeStageFocus != null;
      case 5: // Question 6: Biggest Challenge
        return biggestChallenge != null;
      default:
        return false;
    }
  }

  bool get isLastQuestion => currentQuestion == 5;

  /// Check if all 6 questions are answered
  bool get isComplete =>
      faithStage != null &&
      spiritualGoals.isNotEmpty &&
      spiritualGoals.length <= 3 &&
      timeAvailability != null &&
      learningStyle != null &&
      lifeStageFocus != null &&
      biggestChallenge != null;

  QuestionnaireInProgress copyWith({
    int? currentQuestion,
    FaithStage? faithStage,
    List<SpiritualGoal>? spiritualGoals,
    TimeAvailability? timeAvailability,
    LearningStyle? learningStyle,
    LifeStageFocus? lifeStageFocus,
    BiggestChallenge? biggestChallenge,
  }) {
    return QuestionnaireInProgress(
      currentQuestion: currentQuestion ?? this.currentQuestion,
      faithStage: faithStage ?? this.faithStage,
      spiritualGoals: spiritualGoals ?? this.spiritualGoals,
      timeAvailability: timeAvailability ?? this.timeAvailability,
      learningStyle: learningStyle ?? this.learningStyle,
      lifeStageFocus: lifeStageFocus ?? this.lifeStageFocus,
      biggestChallenge: biggestChallenge ?? this.biggestChallenge,
    );
  }

  @override
  List<Object?> get props => [
        currentQuestion,
        faithStage,
        spiritualGoals,
        timeAvailability,
        learningStyle,
        lifeStageFocus,
        biggestChallenge,
      ];
}

/// Submitting questionnaire
class QuestionnaireSubmitting extends PersonalizationState {
  const QuestionnaireSubmitting();
}

/// Questionnaire submitted successfully
class QuestionnaireSubmitted extends PersonalizationState {
  final PersonalizationEntity personalization;

  const QuestionnaireSubmitted(this.personalization);

  @override
  List<Object?> get props => [personalization];
}

/// Error state
class PersonalizationError extends PersonalizationState {
  final String message;

  const PersonalizationError(this.message);

  @override
  List<Object?> get props => [message];
}
