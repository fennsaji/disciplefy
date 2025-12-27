import 'package:equatable/equatable.dart';

import 'study_mode.dart';

/// Represents a complete set of reflection responses from a Reflect Mode session.
///
/// Contains all the user's responses to interactive prompts during a study guide
/// reflection, along with metadata about the session.
class ReflectionSession extends Equatable {
  /// Unique identifier for this reflection session.
  final String? id;

  /// The study guide ID this reflection is associated with.
  final String studyGuideId;

  /// The study mode used for this guide.
  final StudyMode studyMode;

  /// Individual responses for each section/card.
  final List<ReflectionResponse> responses;

  /// Total time spent in Reflect Mode in seconds.
  final int timeSpentSeconds;

  /// Timestamp when the reflection was completed.
  final DateTime? completedAt;

  /// Timestamp when the reflection was created.
  final DateTime createdAt;

  const ReflectionSession({
    this.id,
    required this.studyGuideId,
    required this.studyMode,
    required this.responses,
    this.timeSpentSeconds = 0,
    this.completedAt,
    required this.createdAt,
  });

  /// Whether this reflection session is complete (all cards answered).
  bool get isComplete => completedAt != null;

  /// Gets the number of completed responses.
  int get completedCount => responses.where((r) => r.isCompleted).length;

  /// Creates a copy with modified fields.
  ReflectionSession copyWith({
    String? id,
    String? studyGuideId,
    StudyMode? studyMode,
    List<ReflectionResponse>? responses,
    int? timeSpentSeconds,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return ReflectionSession(
      id: id ?? this.id,
      studyGuideId: studyGuideId ?? this.studyGuideId,
      studyMode: studyMode ?? this.studyMode,
      responses: responses ?? this.responses,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Converts the responses to a JSONB-compatible map.
  Map<String, dynamic> toResponsesJson() {
    final Map<String, dynamic> json = {};
    for (final response in responses) {
      json.addAll(response.toJson());
    }
    return json;
  }

  @override
  List<Object?> get props => [
        id,
        studyGuideId,
        studyMode,
        responses,
        timeSpentSeconds,
        completedAt,
        createdAt,
      ];
}

/// Represents a single response to an interactive reflection prompt.
///
/// Each response corresponds to one card/section in Reflect Mode.
class ReflectionResponse extends Equatable {
  /// The type of interaction for this response.
  final ReflectionInteractionType interactionType;

  /// The section/card index (0-based).
  final int cardIndex;

  /// The section title (e.g., "Summary", "Interpretation").
  final String sectionTitle;

  /// The response value - type depends on [interactionType].
  final dynamic value;

  /// Optional additional text input.
  final String? additionalText;

  /// Timestamp when this response was recorded.
  final DateTime? respondedAt;

  const ReflectionResponse({
    required this.interactionType,
    required this.cardIndex,
    required this.sectionTitle,
    this.value,
    this.additionalText,
    this.respondedAt,
  });

  /// Whether this response has been completed.
  bool get isCompleted => value != null || respondedAt != null;

  /// Converts this response to a JSON key-value pair.
  Map<String, dynamic> toJson() {
    final key = _getJsonKey();
    switch (interactionType) {
      case ReflectionInteractionType.tapSelection:
        return {key: value as String?};
      case ReflectionInteractionType.slider:
        return {key: value as double?};
      case ReflectionInteractionType.yesNo:
        return {
          key: value as bool?,
          if (additionalText != null && additionalText!.isNotEmpty)
            '${key}_note': additionalText,
        };
      case ReflectionInteractionType.multiSelect:
        return {key: (value as List<String>?) ?? []};
      case ReflectionInteractionType.verseSelection:
        // Include cardIndex to prevent duplicates
        return {'saved_verses_$cardIndex': (value as List<String>?) ?? []};
      case ReflectionInteractionType.prayer:
        final prayerData = value as Map<String, dynamic>?;
        // Include cardIndex to prevent duplicates
        return {
          'prayer_mode_$cardIndex': prayerData?['mode'] as String?,
          'prayer_duration_seconds_$cardIndex': prayerData?['duration'] as int?,
        };
    }
  }

  String _getJsonKey() {
    // Include cardIndex in the key to ensure uniqueness across multiple cards
    // with the same section title
    final baseKey = _getBaseJsonKey();
    return '${baseKey}_$cardIndex';
  }

  String _getBaseJsonKey() {
    switch (sectionTitle.toLowerCase()) {
      case 'summary':
        return 'summary_theme';
      case 'interpretation':
        return 'interpretation_relevance';
      case 'context':
        return 'context_related';
      case 'related verses':
        return 'saved_verses';
      case 'reflection questions':
      case 'reflection':
        return 'life_areas';
      case 'prayer points':
      case 'prayer':
        return 'prayer_mode';
      default:
        return sectionTitle.toLowerCase().replaceAll(' ', '_');
    }
  }

  /// Creates a copy with modified fields.
  ReflectionResponse copyWith({
    ReflectionInteractionType? interactionType,
    int? cardIndex,
    String? sectionTitle,
    dynamic value,
    String? additionalText,
    DateTime? respondedAt,
  }) {
    return ReflectionResponse(
      interactionType: interactionType ?? this.interactionType,
      cardIndex: cardIndex ?? this.cardIndex,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      value: value ?? this.value,
      additionalText: additionalText ?? this.additionalText,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  @override
  List<Object?> get props => [
        interactionType,
        cardIndex,
        sectionTitle,
        value,
        additionalText,
        respondedAt,
      ];
}

/// Types of interactions available in Reflect Mode.
enum ReflectionInteractionType {
  /// Tap to select one option from multiple choices.
  /// Value type: String (selected option label)
  tapSelection,

  /// Slider to indicate a scale value.
  /// Value type: double (0.0 to 1.0)
  slider,

  /// Yes/No question with optional text input.
  /// Value type: bool
  yesNo,

  /// Multi-select chips to choose multiple options.
  /// Value type: `List<String>`
  multiSelect,

  /// Checkbox selection for verses to save.
  /// Value type: `List<String>` (verse references)
  verseSelection,

  /// Prayer mode selection with timer.
  /// Value type: `Map<String, dynamic>` with 'mode' and 'duration' keys
  prayer,
}

/// Extension methods for [ReflectionInteractionType].
extension ReflectionInteractionTypeExtension on ReflectionInteractionType {
  /// Returns the display name for this interaction type.
  String get displayName {
    switch (this) {
      case ReflectionInteractionType.tapSelection:
        return 'Tap Selection';
      case ReflectionInteractionType.slider:
        return 'Slider';
      case ReflectionInteractionType.yesNo:
        return 'Yes/No';
      case ReflectionInteractionType.multiSelect:
        return 'Multi-Select';
      case ReflectionInteractionType.verseSelection:
        return 'Verse Selection';
      case ReflectionInteractionType.prayer:
        return 'Prayer';
    }
  }
}

/// Predefined life areas for the reflection multi-select interaction.
class LifeAreas {
  static const List<LifeAreaOption> all = [
    LifeAreaOption(id: 'work', label: 'Work'),
    LifeAreaOption(id: 'family', label: 'Family'),
    LifeAreaOption(id: 'health', label: 'Health'),
    LifeAreaOption(id: 'finances', label: 'Finances'),
    LifeAreaOption(id: 'faith', label: 'Faith'),
    LifeAreaOption(id: 'anxiety', label: 'Anxiety'),
  ];
}

/// Represents a life area option for multi-select.
class LifeAreaOption {
  final String id;
  final String label;
  final String? icon;

  const LifeAreaOption({
    required this.id,
    required this.label,
    this.icon,
  });
}

/// Prayer modes available in the prayer interaction.
enum PrayerMode {
  /// Listen to the prayer prompt via TTS.
  listen,

  /// Read the prayer silently.
  readSilently,

  /// Write a personal prayer.
  writeOwn,
}

/// Extension methods for [PrayerMode].
extension PrayerModeExtension on PrayerMode {
  String get displayName {
    switch (this) {
      case PrayerMode.listen:
        return 'Listen';
      case PrayerMode.readSilently:
        return 'Read silently';
      case PrayerMode.writeOwn:
        return 'Write my own';
    }
  }

  String get icon {
    switch (this) {
      case PrayerMode.listen:
        return '🔊';
      case PrayerMode.readSilently:
        return '📖';
      case PrayerMode.writeOwn:
        return '✍️';
    }
  }

  String get value => name;

  static PrayerMode fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'listen':
        return PrayerMode.listen;
      case 'writeown':
      case 'write_own':
        return PrayerMode.writeOwn;
      case 'readsilently':
      case 'read_silently':
      default:
        return PrayerMode.readSilently;
    }
  }
}
