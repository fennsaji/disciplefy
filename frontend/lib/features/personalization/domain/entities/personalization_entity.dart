import 'package:equatable/equatable.dart';

/// Represents a user's personalization preferences from the questionnaire
class PersonalizationEntity extends Equatable {
  final FaithStage? faithStage;
  final List<SpiritualGoal> spiritualGoals;
  final TimeAvailability? timeAvailability;
  final LearningStyle? learningStyle;
  final LifeStageFocus? lifeStageFocus;
  final BiggestChallenge? biggestChallenge;
  final Map<String, dynamic>? scoringResults;
  final bool questionnaireCompleted;
  final bool questionnaireSkipped;

  const PersonalizationEntity({
    this.faithStage,
    this.spiritualGoals = const [],
    this.timeAvailability,
    this.learningStyle,
    this.lifeStageFocus,
    this.biggestChallenge,
    this.scoringResults,
    this.questionnaireCompleted = false,
    this.questionnaireSkipped = false,
  });

  /// Whether the user needs to see the questionnaire prompt
  bool get needsQuestionnaire =>
      !questionnaireCompleted && !questionnaireSkipped;

  /// Whether the questionnaire responses are complete
  bool get isComplete =>
      faithStage != null &&
      spiritualGoals.isNotEmpty &&
      spiritualGoals.length <= 3 &&
      timeAvailability != null &&
      learningStyle != null &&
      lifeStageFocus != null &&
      biggestChallenge != null;

  PersonalizationEntity copyWith({
    FaithStage? faithStage,
    List<SpiritualGoal>? spiritualGoals,
    TimeAvailability? timeAvailability,
    LearningStyle? learningStyle,
    LifeStageFocus? lifeStageFocus,
    BiggestChallenge? biggestChallenge,
    Map<String, dynamic>? scoringResults,
    bool? questionnaireCompleted,
    bool? questionnaireSkipped,
  }) {
    return PersonalizationEntity(
      faithStage: faithStage ?? this.faithStage,
      spiritualGoals: spiritualGoals ?? this.spiritualGoals,
      timeAvailability: timeAvailability ?? this.timeAvailability,
      learningStyle: learningStyle ?? this.learningStyle,
      lifeStageFocus: lifeStageFocus ?? this.lifeStageFocus,
      biggestChallenge: biggestChallenge ?? this.biggestChallenge,
      scoringResults: scoringResults ?? this.scoringResults,
      questionnaireCompleted:
          questionnaireCompleted ?? this.questionnaireCompleted,
      questionnaireSkipped: questionnaireSkipped ?? this.questionnaireSkipped,
    );
  }

  @override
  List<Object?> get props => [
        faithStage,
        spiritualGoals,
        timeAvailability,
        learningStyle,
        lifeStageFocus,
        biggestChallenge,
        scoringResults,
        questionnaireCompleted,
        questionnaireSkipped,
      ];
}

// ============================================================================
// Question 1: Faith Stage
// ============================================================================

/// Where are you in your faith journey?
enum FaithStage {
  newBeliever('new_believer', 'Just starting to explore Christianity'),
  growingBeliever('growing_believer', 'Growing in my relationship with Jesus'),
  committedDisciple(
      'committed_disciple', 'Actively following and serving Jesus');

  final String value;
  final String label;
  const FaithStage(this.value, this.label);

  static FaithStage? fromValue(String? value) {
    if (value == null) return null;
    return FaithStage.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FaithStage.newBeliever,
    );
  }
}

// ============================================================================
// Question 2: Spiritual Goals (Multi-select, 1-3 selections)
// ============================================================================

/// What are you hoping to grow in? (Choose up to 3)
enum SpiritualGoal {
  foundationalFaith(
      'foundational_faith', 'Understanding Bible basics and core beliefs'),
  spiritualDepth(
      'spiritual_depth', 'Deepening my prayer life and spiritual disciplines'),
  relationships('relationships', 'Strengthening my family and friendships'),
  apologetics(
      'apologetics', 'Defending my faith and answering tough questions'),
  service('service', 'Serving others and sharing the Gospel'),
  theology(
      'theology', 'Exploring deep theological and philosophical questions');

  final String value;
  final String label;
  const SpiritualGoal(this.value, this.label);

  static SpiritualGoal? fromValue(String? value) {
    if (value == null) return null;
    try {
      return SpiritualGoal.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }

  static List<SpiritualGoal> listFromValues(List<String>? values) {
    if (values == null || values.isEmpty) return [];
    return values
        .map((v) => fromValue(v))
        .where((g) => g != null)
        .cast<SpiritualGoal>()
        .toList();
  }
}

// ============================================================================
// Question 3: Time Availability
// ============================================================================

/// How much time can you commit to daily Bible study?
enum TimeAvailability {
  fiveToTenMin('5_to_10_min', '5-10 minutes (quick sessions)'),
  tenToTwentyMin('10_to_20_min', '10-20 minutes (balanced study)'),
  twentyPlusMin('20_plus_min', '20+ minutes (in-depth exploration)');

  final String value;
  final String label;
  const TimeAvailability(this.value, this.label);

  static TimeAvailability? fromValue(String? value) {
    if (value == null) return null;
    try {
      return TimeAvailability.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// Question 4: Learning Style
// ============================================================================

/// How do you prefer to learn?
enum LearningStyle {
  practicalApplication(
      'practical_application', 'Practical steps I can apply right away'),
  deepUnderstanding('deep_understanding', 'Detailed theological explanations'),
  reflectionMeditation(
      'reflection_meditation', 'Prayerful meditation and reflection'),
  balancedApproach(
      'balanced_approach', 'A mix of study, reflection, and action');

  final String value;
  final String label;
  const LearningStyle(this.value, this.label);

  static LearningStyle? fromValue(String? value) {
    if (value == null) return null;
    try {
      return LearningStyle.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// Question 5: Life Stage Focus
// ============================================================================

/// Which area of life is most important to you right now?
enum LifeStageFocus {
  personalFoundation(
      'personal_foundation', 'Building my personal relationship with God'),
  familyRelationships(
      'family_relationships', 'Growing with my family and loved ones'),
  communityImpact('community_impact', 'Making a difference in my community'),
  intellectualGrowth(
      'intellectual_growth', 'Wrestling with big questions about faith');

  final String value;
  final String label;
  const LifeStageFocus(this.value, this.label);

  static LifeStageFocus? fromValue(String? value) {
    if (value == null) return null;
    try {
      return LifeStageFocus.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// Question 6: Biggest Challenge
// ============================================================================

/// What's your biggest challenge in your faith journey?
enum BiggestChallenge {
  startingBasics('starting_basics', "I'm new and don't know where to start"),
  stayingConsistent(
      'staying_consistent', 'Struggling to maintain daily spiritual habits'),
  handlingDoubts(
      'handling_doubts', 'Dealing with doubts and difficult questions'),
  sharingFaith(
      'sharing_faith', 'Not confident in sharing my faith with others'),
  growingStagnant('growing_stagnant', 'Feeling stuck or spiritually dry');

  final String value;
  final String label;
  const BiggestChallenge(this.value, this.label);

  static BiggestChallenge? fromValue(String? value) {
    if (value == null) return null;
    try {
      return BiggestChallenge.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }
}
