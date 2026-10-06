import 'dart:convert';

import 'package:disciplefy_bible_study/features/study_generation/domain/entities/expected_sections.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';

/// Section types that can be streamed from the study guide generation
enum StudyStreamSectionType {
  summary,
  interpretation,
  context,
  passage,
  relatedVerses,
  reflectionQuestions,
  prayerPoints;

  /// Returns null for a section type this client build does not know.
  ///
  /// The generator streams a section per field it produces, including internal
  /// ones (`interpretationPart1`…) that no client consumes. Throwing here
  /// aborted the whole stream and surfaced as "Generation interrupted", so an
  /// unknown type is now something the caller skips rather than an error.
  static StudyStreamSectionType? fromString(String value) {
    for (final type in StudyStreamSectionType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

/// Thrown when a `section` event names a type this build does not know.
/// Callers skip these; they are not stream failures.
class UnknownStudySectionException implements Exception {
  final String sectionType;

  const UnknownStudySectionException(this.sectionType);

  @override
  String toString() => 'Unknown study section type: $sectionType';
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
    if (type == null) throw UnknownStudySectionException(typeStr);

    // Content can be string or list
    final rawContent = json['content'];
    dynamic content;

    if (rawContent is List) {
      content = List<String>.from(rawContent.map((e) => e.toString()));
    } else {
      content = rawContent.toString();
    }

    return StudyStreamSectionEvent(
      type: type,
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
    this.sectionsLoaded = 0,
    // expectedSectionsFor(StudyMode.standard); a default must be const.
    // Use [StreamingStudyGuideContent.empty] to default from a mode.
    this.totalSections = 7,
    this.isFromCache = false,
    this.studyGuideId,
  });

  /// Empty streaming content expecting the sections a [mode] stream sends,
  /// until the backend's init and section events report the real total.
  factory StreamingStudyGuideContent.empty(
      {StudyMode mode = StudyMode.standard}) {
    return StreamingStudyGuideContent(totalSections: expectedSectionsFor(mode));
  }

  /// Progress from 0.0 to 1.0
  double get progress => totalSections > 0
      ? (sectionsLoaded / totalSections).clamp(0.0, 1.0)
      : 0.0;

  /// Whether all required sections have been loaded
  /// Changed from hardcoded 6 to dynamic totalSections to support all study modes
  bool get isComplete => sectionsLoaded >= totalSections;

  /// Whether all 7 required content fields are present (non-null and non-empty).
  /// Matches REQUIRED_SECTIONS from backend streaming-json-parser.ts:
  ///   summary, interpretation, context, passage, relatedVerses, reflectionQuestions, prayerPoints
  bool get hasRequiredContent =>
      summary != null &&
      summary!.isNotEmpty &&
      interpretation != null &&
      interpretation!.isNotEmpty &&
      context != null &&
      context!.isNotEmpty &&
      passage != null &&
      passage!.isNotEmpty &&
      relatedVerses != null &&
      relatedVerses!.isNotEmpty &&
      reflectionQuestions != null &&
      reflectionQuestions!.isNotEmpty &&
      prayerPoints != null &&
      prayerPoints!.isNotEmpty;

  /// How many distinct section types have arrived.
  int get _distinctSectionsLoaded => [
        summary,
        interpretation,
        context,
        passage,
        relatedVerses,
        reflectionQuestions,
        prayerPoints,
      ].where((field) => field != null).length;

  /// Create a copy with a new section added.
  ///
  /// Multi-pass streams re-send `interpretation` as each pass adds to it, so
  /// [sectionsLoaded] counts distinct section types, not events: a re-sent
  /// section neither advances progress nor completes the stream early.
  StreamingStudyGuideContent copyWithSection(StudyStreamSectionEvent section) {
    final updated = StreamingStudyGuideContent(
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
      totalSections: section.total,
      isFromCache: isFromCache,
    );
    return updated.copyWith(sectionsLoaded: updated._distinctSectionsLoaded);
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
