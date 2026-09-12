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

  // Scripture passage for meditation and reading
  final String? passage;

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
    this.passage,
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
    String? passage,
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
        passage: passage ?? this.passage,
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
        return '8 min';
      case 'deep':
        return '12 min';
      case 'lectio':
        return '9 min';
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
        passage,
      ];

  /// The `extra` map the study-guide route expects to open this guide
  /// directly, without a separate fetch. Shared by every place that opens a
  /// guide from an entity already in hand — the Saved/Recent list and a
  /// push notification that fetched one by id — so the route's expected
  /// shape lives in one place instead of being hand-copied at each call site.
  ///
  /// The route reads its `source` (saved/recent/...) from the URL query
  /// string, not from `extra` — pass it there, not into this map.
  Map<String, dynamic> toRouteExtra() => {
        'study_guide': {
          'id': id,
          'title': displayTitle,
          'content': content,
          // The study screen's input-type vocabulary is 'scripture' | 'topic'.
          'type': type == GuideType.verse ? 'scripture' : 'topic',
          'study_mode': studyMode,
          'verse_reference': verseReference,
          'topic_name': topicName,
          'is_saved': isSaved,
          'created_at': createdAt.toIso8601String(),
          'last_accessed_at': lastAccessedAt.toIso8601String(),
          'summary': summary,
          'interpretation': interpretation,
          'context': context,
          'related_verses': relatedVerses,
          'reflection_questions': reflectionQuestions,
          'prayer_points': prayerPoints,
          'passage': passage,
        },
      };
}
