import 'package:equatable/equatable.dart';

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

/// User selected a faith journey option
class SelectFaithJourney extends PersonalizationEvent {
  final String faithJourney;

  const SelectFaithJourney(this.faithJourney);

  @override
  List<Object?> get props => [faithJourney];
}

/// User toggled a seeking option
class ToggleSeeking extends PersonalizationEvent {
  final String seeking;

  const ToggleSeeking(this.seeking);

  @override
  List<Object?> get props => [seeking];
}

/// User selected a time commitment option
class SelectTimeCommitment extends PersonalizationEvent {
  final String timeCommitment;

  const SelectTimeCommitment(this.timeCommitment);

  @override
  List<Object?> get props => [timeCommitment];
}

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
