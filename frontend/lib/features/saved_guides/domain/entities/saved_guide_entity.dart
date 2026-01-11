import 'package:equatable/equatable.dart';

enum GuideType {
  verse,
  topic,
}

class SavedGuideEntity extends Equatable {
  final String id;
  final String title;

  // Structured content fields (preferred)
  final String? summary;
  final String? interpretation;
  final String? context;
  final List<String>? relatedVerses;
  final List<String>? reflectionQuestions;
  final List<String>? prayerPoints;

  // Reflection enhancement fields
  final List<String>? interpretationInsights;
  final List<String>? summaryInsights;
  final List<String>? reflectionAnswers;
  final String? contextQuestion;
  final String? summaryQuestion;
  final String? relatedVersesQuestion;
  final String? reflectionQuestion;
  final String? prayerQuestion;

  // Legacy content field for backward compatibility
  final String content;

  final GuideType type;
  final String? studyMode; // quick, standard, deep, lectio, sermon
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final bool isSaved;
  final String? verseReference;
  final String? topicName;

  const SavedGuideEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.isSaved,
    this.studyMode,
    this.verseReference,
    this.topicName,
    this.summary,
    this.interpretation,
    this.context,
    this.relatedVerses,
    this.reflectionQuestions,
    this.prayerPoints,
    this.interpretationInsights,
    this.summaryInsights,
    this.reflectionAnswers,
    this.contextQuestion,
    this.summaryQuestion,
    this.relatedVersesQuestion,
    this.reflectionQuestion,
    this.prayerQuestion,
  });

  SavedGuideEntity copyWith({
    String? id,
    String? title,
    String? content,
    GuideType? type,
    String? studyMode,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    bool? isSaved,
    String? verseReference,
    String? topicName,
    String? summary,
    String? interpretation,
    String? context,
    List<String>? relatedVerses,
    List<String>? reflectionQuestions,
    List<String>? prayerPoints,
    List<String>? interpretationInsights,
    List<String>? summaryInsights,
    List<String>? reflectionAnswers,
    String? contextQuestion,
    String? summaryQuestion,
    String? relatedVersesQuestion,
    String? reflectionQuestion,
    String? prayerQuestion,
  }) =>
      SavedGuideEntity(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        type: type ?? this.type,
        studyMode: studyMode ?? this.studyMode,
        createdAt: createdAt ?? this.createdAt,
        lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
        isSaved: isSaved ?? this.isSaved,
        verseReference: verseReference ?? this.verseReference,
        topicName: topicName ?? this.topicName,
        summary: summary ?? this.summary,
        interpretation: interpretation ?? this.interpretation,
        context: context ?? this.context,
        relatedVerses: relatedVerses ?? this.relatedVerses,
        reflectionQuestions: reflectionQuestions ?? this.reflectionQuestions,
        prayerPoints: prayerPoints ?? this.prayerPoints,
        interpretationInsights:
            interpretationInsights ?? this.interpretationInsights,
        summaryInsights: summaryInsights ?? this.summaryInsights,
        reflectionAnswers: reflectionAnswers ?? this.reflectionAnswers,
        contextQuestion: contextQuestion ?? this.contextQuestion,
        summaryQuestion: summaryQuestion ?? this.summaryQuestion,
        relatedVersesQuestion:
            relatedVersesQuestion ?? this.relatedVersesQuestion,
        reflectionQuestion: reflectionQuestion ?? this.reflectionQuestion,
        prayerQuestion: prayerQuestion ?? this.prayerQuestion,
      );

  String get displayTitle {
    switch (type) {
      case GuideType.verse:
        return verseReference ?? title;
      case GuideType.topic:
        return topicName ?? title;
    }
  }

  String get subtitle {
    switch (type) {
      case GuideType.verse:
        return 'Bible Verse Study';
      case GuideType.topic:
        return 'Topic Study';
    }
  }

  /// Returns the display name for the study mode
  String? get studyModeDisplay {
    if (studyMode == null) return null;

    switch (studyMode) {
      case 'quick':
        return 'Quick Read';
      case 'standard':
        return 'Standard Study';
      case 'deep':
        return 'Deep Dive';
      case 'lectio':
        return 'Lectio Divina';
      case 'sermon':
        return 'Sermon Outline';
      default:
        return null;
    }
  }

  /// Returns the duration badge text for the study mode
  String? get studyModeDuration {
    if (studyMode == null) return null;

    switch (studyMode) {
      case 'quick':
        return '3 min';
      case 'standard':
        return '10 min';
      case 'deep':
        return '25 min';
      case 'lectio':
        return '15 min';
      case 'sermon':
        return '55 min';
      default:
        return null;
    }
  }

  /// Returns true if this entity has structured content
  bool get hasStructuredContent =>
      summary != null ||
      interpretation != null ||
      context != null ||
      relatedVerses != null ||
      reflectionQuestions != null ||
      prayerPoints != null;

  /// Gets the content preview for display in lists
  String get contentPreview {
    if (hasStructuredContent && summary != null && summary!.isNotEmpty) {
      return summary!.length > 120
          ? '${summary!.substring(0, 120)}...'
          : summary!;
    }

    // Fallback to parsing legacy content format
    if (content.contains('**Summary:**')) {
      final summaryMatch = RegExp(r'\*\*Summary:\*\*\s*([^\*]+)', dotAll: true)
          .firstMatch(content);
      if (summaryMatch != null) {
        final summaryText = summaryMatch.group(1)?.trim() ?? '';
        return summaryText.length > 120
            ? '${summaryText.substring(0, 120)}...'
            : summaryText;
      }
    }

    // Final fallback to raw content
    return content.length > 120 ? '${content.substring(0, 120)}...' : content;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        type,
        studyMode,
        createdAt,
        lastAccessedAt,
        isSaved,
        verseReference,
        topicName,
        summary,
        interpretation,
        context,
        relatedVerses,
        reflectionQuestions,
        prayerPoints,
        interpretationInsights,
        summaryInsights,
        reflectionAnswers,
        contextQuestion,
        summaryQuestion,
        relatedVersesQuestion,
        reflectionQuestion,
        prayerQuestion,
      ];
}
