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

/// User is filling out the questionnaire
class QuestionnaireInProgress extends PersonalizationState {
  final int currentQuestion; // 0, 1, or 2
  final String? faithJourney;
  final List<String> seeking;
  final String? timeCommitment;

  const QuestionnaireInProgress({
    this.currentQuestion = 0,
    this.faithJourney,
    this.seeking = const [],
    this.timeCommitment,
  });

  bool get canProceed {
    switch (currentQuestion) {
      case 0:
        return faithJourney != null;
      case 1:
        return seeking.isNotEmpty;
      case 2:
        return timeCommitment != null;
      default:
        return false;
    }
  }

  bool get isLastQuestion => currentQuestion == 2;

  QuestionnaireInProgress copyWith({
    int? currentQuestion,
    String? faithJourney,
    List<String>? seeking,
    String? timeCommitment,
  }) {
    return QuestionnaireInProgress(
      currentQuestion: currentQuestion ?? this.currentQuestion,
      faithJourney: faithJourney ?? this.faithJourney,
      seeking: seeking ?? this.seeking,
      timeCommitment: timeCommitment ?? this.timeCommitment,
    );
  }

  @override
  List<Object?> get props =>
      [currentQuestion, faithJourney, seeking, timeCommitment];
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
