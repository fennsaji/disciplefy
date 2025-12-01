import 'package:equatable/equatable.dart';

/// Represents a user's personalization preferences from the questionnaire
class PersonalizationEntity extends Equatable {
  final String? faithJourney;
  final List<String> seeking;
  final String? timeCommitment;
  final bool questionnaireCompleted;
  final bool questionnaireSkipped;

  const PersonalizationEntity({
    this.faithJourney,
    this.seeking = const [],
    this.timeCommitment,
    this.questionnaireCompleted = false,
    this.questionnaireSkipped = false,
  });

  /// Whether the user needs to see the questionnaire prompt
  bool get needsQuestionnaire =>
      !questionnaireCompleted && !questionnaireSkipped;

  PersonalizationEntity copyWith({
    String? faithJourney,
    List<String>? seeking,
    String? timeCommitment,
    bool? questionnaireCompleted,
    bool? questionnaireSkipped,
  }) {
    return PersonalizationEntity(
      faithJourney: faithJourney ?? this.faithJourney,
      seeking: seeking ?? this.seeking,
      timeCommitment: timeCommitment ?? this.timeCommitment,
      questionnaireCompleted:
          questionnaireCompleted ?? this.questionnaireCompleted,
      questionnaireSkipped: questionnaireSkipped ?? this.questionnaireSkipped,
    );
  }

  @override
  List<Object?> get props => [
        faithJourney,
        seeking,
        timeCommitment,
        questionnaireCompleted,
        questionnaireSkipped,
      ];
}

/// Valid faith journey values
enum FaithJourney {
  newToFaith('new', 'New to Christianity'),
  growing('growing', 'Growing in faith'),
  mature('mature', 'Mature believer');

  final String value;
  final String label;
  const FaithJourney(this.value, this.label);
}

/// Valid seeking values
enum SeekingType {
  peace('peace', 'Peace & comfort'),
  guidance('guidance', 'Life guidance'),
  knowledge('knowledge', 'Deeper Bible knowledge'),
  relationships('relationships', 'Strengthening relationships'),
  challenges('challenges', 'Overcoming challenges');

  final String value;
  final String label;
  const SeekingType(this.value, this.label);
}

/// Valid time commitment values
enum TimeCommitment {
  fiveMin('5min', '5 minutes daily'),
  fifteenMin('15min', '15 minutes daily'),
  thirtyMin('30min', '30+ minutes daily');

  final String value;
  final String label;
  const TimeCommitment(this.value, this.label);
}
