import 'package:equatable/equatable.dart';

import '../../domain/entities/personalization_entity.dart';

/// Base event for personalization
abstract class PersonalizationEvent extends Equatable {
  const PersonalizationEvent();

  @override
  List<Object?> get props => [];
}

/// Load the user's personalization status
class LoadPersonalization extends PersonalizationEvent {
  const LoadPersonalization();
}

// ===========================================================================
// Question 1: Faith Stage
// ===========================================================================

/// User selected a faith stage option
class SelectFaithStage extends PersonalizationEvent {
  final FaithStage faithStage;

  const SelectFaithStage(this.faithStage);

  @override
  List<Object?> get props => [faithStage];
}

// ===========================================================================
// Question 2: Spiritual Goals (Multi-select, max 3)
// ===========================================================================

/// User toggled a spiritual goal option
class ToggleSpiritualGoal extends PersonalizationEvent {
  final SpiritualGoal goal;

  const ToggleSpiritualGoal(this.goal);

  @override
  List<Object?> get props => [goal];
}

// ===========================================================================
// Question 3: Time Availability
// ===========================================================================

/// User selected a time availability option
class SelectTimeAvailability extends PersonalizationEvent {
  final TimeAvailability timeAvailability;

  const SelectTimeAvailability(this.timeAvailability);

  @override
  List<Object?> get props => [timeAvailability];
}

// ===========================================================================
// Question 4: Learning Style
// ===========================================================================

/// User selected a learning style option
class SelectLearningStyle extends PersonalizationEvent {
  final LearningStyle learningStyle;

  const SelectLearningStyle(this.learningStyle);

  @override
  List<Object?> get props => [learningStyle];
}

// ===========================================================================
// Question 5: Life Stage Focus
// ===========================================================================

/// User selected a life stage focus option
class SelectLifeStageFocus extends PersonalizationEvent {
  final LifeStageFocus lifeStageFocus;

  const SelectLifeStageFocus(this.lifeStageFocus);

  @override
  List<Object?> get props => [lifeStageFocus];
}

// ===========================================================================
// Question 6: Biggest Challenge
// ===========================================================================

/// User selected a biggest challenge option
class SelectBiggestChallenge extends PersonalizationEvent {
  final BiggestChallenge biggestChallenge;

  const SelectBiggestChallenge(this.biggestChallenge);

  @override
  List<Object?> get props => [biggestChallenge];
}

// ===========================================================================
// Navigation & Submission
// ===========================================================================

/// User submitted the questionnaire
class SubmitQuestionnaire extends PersonalizationEvent {
  const SubmitQuestionnaire();
}

/// User skipped the questionnaire
class SkipQuestionnaire extends PersonalizationEvent {
  const SkipQuestionnaire();
}

/// Navigate to next question
class NextQuestion extends PersonalizationEvent {
  const NextQuestion();
}

/// Navigate to previous question
class PreviousQuestion extends PersonalizationEvent {
  const PreviousQuestion();
}
