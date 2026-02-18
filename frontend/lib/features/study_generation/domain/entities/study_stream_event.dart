import 'dart:convert';

/// Section types that can be streamed from the study guide generation
enum StudyStreamSectionType {
  summary,
  interpretation,
  context,
  passage,
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
  prayerQuestion;

  static StudyStreamSectionType? fromString(String value) {
    return StudyStreamSectionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown section type: $value'),
    );
  }
}

/// Base sealed class for all study stream events
sealed class StudyStreamEvent {
  const StudyStreamEvent();

  /// Parse a raw SSE event into a typed StudyStreamEvent
  factory StudyStreamEvent.parse(String eventType, String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;

      return switch (eventType) {
        'init' => StudyStreamInitEvent.fromJson(json),
        'section' => StudyStreamSectionEvent.fromJson(json),
        'complete' => StudyStreamCompleteEvent.fromJson(json),
        'error' => StudyStreamErrorEvent.fromJson(json),
        _ => throw ArgumentError('Unknown event type: $eventType'),
      };
    } catch (e) {
      return StudyStreamErrorEvent(
        code: 'PARSE_ERROR',
        message: 'Failed to parse event: $e',
        retryable: true,
      );
    }
  }
}

/// Event indicating stream initialization
class StudyStreamInitEvent extends StudyStreamEvent {
  final StudyStreamStatus status;
  final int estimatedSections;

  const StudyStreamInitEvent({
    required this.status,
    required this.estimatedSections,
  });

  factory StudyStreamInitEvent.fromJson(Map<String, dynamic> json) {
    return StudyStreamInitEvent(
      status: json['status'] == 'cache_hit'
          ? StudyStreamStatus.cacheHit
          : StudyStreamStatus.started,
      estimatedSections: json['estimatedSections'] as int? ?? 6,
    );
  }
}

/// Status of the stream initialization
enum StudyStreamStatus {
  started,
  cacheHit,
}

/// Event containing a completed section
class StudyStreamSectionEvent extends StudyStreamEvent {
  final StudyStreamSectionType type;
  final dynamic
      content; // String for text sections, List<String> for array sections
  final int index;
  final int total;

  const StudyStreamSectionEvent({
    required this.type,
    required this.content,
    required this.index,
    required this.total,
  });

  factory StudyStreamSectionEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = StudyStreamSectionType.fromString(typeStr);

    // Content can be string or list
    final rawContent = json['content'];
    dynamic content;

    if (rawContent is List) {
      content = List<String>.from(rawContent.map((e) => e.toString()));
    } else {
      content = rawContent.toString();
    }

    return StudyStreamSectionEvent(
      type: type!,
      content: content,
      index: json['index'] as int? ?? 0,
      total: json['total'] as int? ?? 6,
    );
  }

  /// Get content as a string (for text sections)
  String get contentAsString => content is String ? content : '';

  /// Get content as a list (for array sections)
  List<String> get contentAsList =>
      content is List ? List<String>.from(content) : [];

  /// Get section type as string for logging/debugging
  String get sectionType => type.name;
}

/// Event indicating stream completion
class StudyStreamCompleteEvent extends StudyStreamEvent {
  final String studyGuideId;
  final int tokensConsumed;
  final bool fromCache;

  const StudyStreamCompleteEvent({
    required this.studyGuideId,
    required this.tokensConsumed,
    required this.fromCache,
  });

  factory StudyStreamCompleteEvent.fromJson(Map<String, dynamic> json) {
    return StudyStreamCompleteEvent(
      studyGuideId: json['studyGuideId'] as String? ?? '',
      tokensConsumed: json['tokensConsumed'] as int? ?? 0,
      fromCache: json['fromCache'] as bool? ?? false,
    );
  }
}

/// Event indicating an error occurred
class StudyStreamErrorEvent extends StudyStreamEvent {
  final String code;
  final String message;
  final bool retryable;

  const StudyStreamErrorEvent({
    required this.code,
    required this.message,
    required this.retryable,
  });

  factory StudyStreamErrorEvent.fromJson(Map<String, dynamic> json) {
    return StudyStreamErrorEvent(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'An unknown error occurred',
      retryable: json['retryable'] as bool? ?? true,
    );
  }
}

/// Accumulated study guide content during streaming
class StreamingStudyGuideContent {
  final String? summary;
  final String? interpretation;
  final String? context;
  final String? passage;
  final List<String>? relatedVerses;
  final List<String>? reflectionQuestions;
  final List<String>? prayerPoints;
  final List<String>? interpretationInsights;
  final List<String>? summaryInsights;
  final List<String>? reflectionAnswers;
  final String? contextQuestion;
  final String? summaryQuestion;
  final String? relatedVersesQuestion;
  final String? reflectionQuestion;
  final String? prayerQuestion;
  final int sectionsLoaded;
  final int totalSections;
  final bool isFromCache;
  final String? studyGuideId;

  const StreamingStudyGuideContent({
    this.summary,
    this.interpretation,
    this.context,
    this.passage,
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
    this.sectionsLoaded = 0,
    this.totalSections = 14,
    this.isFromCache = false,
    this.studyGuideId,
  });

  /// Create an empty streaming content
  factory StreamingStudyGuideContent.empty() {
    return const StreamingStudyGuideContent();
  }

  /// Progress from 0.0 to 1.0
  double get progress =>
      totalSections > 0 ? sectionsLoaded / totalSections : 0.0;

  /// Whether all required sections have been loaded
  /// Changed from hardcoded 6 to dynamic totalSections to support all study modes
  bool get isComplete => sectionsLoaded >= totalSections;

  /// Create a copy with a new section added
  StreamingStudyGuideContent copyWithSection(StudyStreamSectionEvent section) {
    return StreamingStudyGuideContent(
      summary: section.type == StudyStreamSectionType.summary
          ? section.contentAsString
          : summary,
      interpretation: section.type == StudyStreamSectionType.interpretation
          ? section.contentAsString
          : interpretation,
      context: section.type == StudyStreamSectionType.context
          ? section.contentAsString
          : context,
      passage: section.type == StudyStreamSectionType.passage
          ? section.contentAsString
          : passage,
      relatedVerses: section.type == StudyStreamSectionType.relatedVerses
          ? section.contentAsList
          : relatedVerses,
      reflectionQuestions:
          section.type == StudyStreamSectionType.reflectionQuestions
              ? section.contentAsList
              : reflectionQuestions,
      prayerPoints: section.type == StudyStreamSectionType.prayerPoints
          ? section.contentAsList
          : prayerPoints,
      interpretationInsights:
          section.type == StudyStreamSectionType.interpretationInsights
              ? section.contentAsList
              : interpretationInsights,
      summaryInsights: section.type == StudyStreamSectionType.summaryInsights
          ? section.contentAsList
          : summaryInsights,
      reflectionAnswers:
          section.type == StudyStreamSectionType.reflectionAnswers
              ? section.contentAsList
              : reflectionAnswers,
      contextQuestion: section.type == StudyStreamSectionType.contextQuestion
          ? section.contentAsString
          : contextQuestion,
      summaryQuestion: section.type == StudyStreamSectionType.summaryQuestion
          ? section.contentAsString
          : summaryQuestion,
      relatedVersesQuestion:
          section.type == StudyStreamSectionType.relatedVersesQuestion
              ? section.contentAsString
              : relatedVersesQuestion,
      reflectionQuestion:
          section.type == StudyStreamSectionType.reflectionQuestion
              ? section.contentAsString
              : reflectionQuestion,
      prayerQuestion: section.type == StudyStreamSectionType.prayerQuestion
          ? section.contentAsString
          : prayerQuestion,
      sectionsLoaded: sectionsLoaded + 1,
      totalSections: section.total,
      isFromCache: isFromCache,
    );
  }

  /// Create initial state with cache flag
  StreamingStudyGuideContent withCacheFlag(bool fromCache) {
    return StreamingStudyGuideContent(
      summary: summary,
      interpretation: interpretation,
      context: context,
      passage: passage,
      relatedVerses: relatedVerses,
      reflectionQuestions: reflectionQuestions,
      prayerPoints: prayerPoints,
      interpretationInsights: interpretationInsights,
      summaryInsights: summaryInsights,
      reflectionAnswers: reflectionAnswers,
      contextQuestion: contextQuestion,
      summaryQuestion: summaryQuestion,
      relatedVersesQuestion: relatedVersesQuestion,
      reflectionQuestion: reflectionQuestion,
      prayerQuestion: prayerQuestion,
      sectionsLoaded: sectionsLoaded,
      totalSections: totalSections,
      isFromCache: fromCache,
      studyGuideId: studyGuideId,
    );
  }

  /// General copy with method
  StreamingStudyGuideContent copyWith({
    String? summary,
    String? interpretation,
    String? context,
    String? passage,
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
    int? sectionsLoaded,
    int? totalSections,
    bool? isFromCache,
    String? studyGuideId,
  }) {
    return StreamingStudyGuideContent(
      summary: summary ?? this.summary,
      interpretation: interpretation ?? this.interpretation,
      context: context ?? this.context,
      passage: passage ?? this.passage,
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
      sectionsLoaded: sectionsLoaded ?? this.sectionsLoaded,
      totalSections: totalSections ?? this.totalSections,
      isFromCache: isFromCache ?? this.isFromCache,
      studyGuideId: studyGuideId ?? this.studyGuideId,
    );
  }

  /// Convert to props list for Equatable comparison
  List<Object?> get props => [
        summary,
        interpretation,
        context,
        passage,
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
        sectionsLoaded,
        totalSections,
        isFromCache,
        studyGuideId,
      ];

  /// Getter for section type to easily get the sectionType for UI rendering
  String get sectionType {
    if (summary != null) return 'summary';
    if (interpretation != null) return 'interpretation';
    if (context != null) return 'context';
    if (passage != null) return 'passage';
    if (relatedVerses != null) return 'relatedVerses';
    if (reflectionQuestions != null) return 'reflectionQuestions';
    if (prayerPoints != null) return 'prayerPoints';
    return 'unknown';
  }
}
