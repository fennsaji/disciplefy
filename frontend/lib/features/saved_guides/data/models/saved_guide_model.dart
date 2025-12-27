import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/saved_guide_entity.dart';
import '../../../study_generation/domain/entities/study_guide.dart';

part 'saved_guide_model.g.dart';

@HiveType(typeId: 1)
@JsonSerializable()
class SavedGuideModel extends SavedGuideEntity {
  @HiveField(0)
  @override
  final String id;

  @HiveField(1)
  @override
  final String title;

  @HiveField(2)
  @override
  final String content;

  // New structured content fields
  @override
  @HiveField(9)
  final String? summary;

  @override
  @HiveField(10)
  final String? interpretation;

  @override
  @HiveField(11)
  final String? context;

  @override
  @HiveField(12)
  final List<String>? relatedVerses;

  @override
  @HiveField(13)
  final List<String>? reflectionQuestions;

  @override
  @HiveField(14)
  final List<String>? prayerPoints;

  // Reflection enhancement fields
  @override
  @HiveField(15)
  final List<String>? interpretationInsights;

  @override
  @HiveField(16)
  final String? contextQuestion;

  @override
  @HiveField(17)
  final String? summaryQuestion;

  @override
  @HiveField(18)
  final String? relatedVersesQuestion;

  @override
  @HiveField(19)
  final String? reflectionQuestion;

  @override
  @HiveField(20)
  final String? prayerQuestion;

  @override
  @HiveField(21)
  final List<String>? summaryInsights;

  @override
  @HiveField(22)
  final List<String>? reflectionAnswers;

  @HiveField(3)
  @JsonKey(name: 'type')
  final String typeString;

  @HiveField(4)
  @override
  final DateTime createdAt;

  @HiveField(5)
  @override
  final DateTime lastAccessedAt;

  @HiveField(6)
  @override
  final bool isSaved;

  @HiveField(7)
  @override
  final String? verseReference;

  @HiveField(8)
  @override
  final String? topicName;

  const SavedGuideModel({
    required this.id,
    required this.title,
    required this.content,
    required this.typeString,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.isSaved,
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
  }) : super(
          id: id,
          title: title,
          content: content,
          type: typeString == 'verse' ? GuideType.verse : GuideType.topic,
          createdAt: createdAt,
          lastAccessedAt: lastAccessedAt,
          isSaved: isSaved,
          verseReference: verseReference,
          topicName: topicName,
          summary: summary,
          interpretation: interpretation,
          context: context,
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
        );

  factory SavedGuideModel.fromJson(Map<String, dynamic> json) =>
      _$SavedGuideModelFromJson(json);

  Map<String, dynamic> toJson() => _$SavedGuideModelToJson(this);

  factory SavedGuideModel.fromEntity(SavedGuideEntity entity) =>
      SavedGuideModel(
        id: entity.id,
        title: entity.title,
        content: entity.content,
        typeString: entity.type == GuideType.verse ? 'verse' : 'topic',
        createdAt: entity.createdAt,
        lastAccessedAt: entity.lastAccessedAt,
        isSaved: entity.isSaved,
        verseReference: entity.verseReference,
        topicName: entity.topicName,
        summary: entity.summary,
        interpretation: entity.interpretation,
        context: entity.context,
        relatedVerses: entity.relatedVerses,
        reflectionQuestions: entity.reflectionQuestions,
        prayerPoints: entity.prayerPoints,
        interpretationInsights: entity.interpretationInsights,
        summaryInsights: entity.summaryInsights,
        reflectionAnswers: entity.reflectionAnswers,
        contextQuestion: entity.contextQuestion,
        summaryQuestion: entity.summaryQuestion,
        relatedVersesQuestion: entity.relatedVersesQuestion,
        reflectionQuestion: entity.reflectionQuestion,
        prayerQuestion: entity.prayerQuestion,
      );

  /// Create model from API response
  /// Updated to handle new cached architecture response format with structured content.
  factory SavedGuideModel.fromApiResponse(Map<String, dynamic> json) {
    final inputData = json['input'] as Map<String, dynamic>? ?? {};
    final contentData = json['content'] as Map<String, dynamic>? ?? {};
    final inputType = inputData['type'] as String? ?? 'topic';
    final inputValue = inputData['value'] as String? ?? 'Study Guide';

    // Extract structured content from API response
    final summary = contentData['summary'] as String? ?? '';
    final interpretation = contentData['interpretation'] as String? ?? '';
    final context = contentData['context'] as String? ?? '';
    final relatedVerses =
        (contentData['relatedVerses'] as List<dynamic>?)?.cast<String>() ??
            <String>[];
    final reflectionQuestions =
        (contentData['reflectionQuestions'] as List<dynamic>?)
                ?.cast<String>() ??
            <String>[];
    final prayerPoints =
        (contentData['prayerPoints'] as List<dynamic>?)?.cast<String>() ??
            <String>[];

    // Extract reflection enhancement fields
    final interpretationInsights =
        (contentData['interpretationInsights'] as List<dynamic>?)
                ?.cast<String>() ??
            <String>[];
    final summaryInsights =
        (contentData['summaryInsights'] as List<dynamic>?)?.cast<String>() ??
            <String>[];
    final reflectionAnswers =
        (contentData['reflectionAnswers'] as List<dynamic>?)?.cast<String>() ??
            <String>[];
    final contextQuestion = contentData['contextQuestion'] as String? ?? '';
    final summaryQuestion = contentData['summaryQuestion'] as String? ?? '';
    final relatedVersesQuestion =
        contentData['relatedVersesQuestion'] as String? ?? '';
    final reflectionQuestion =
        contentData['reflectionQuestion'] as String? ?? '';
    final prayerQuestion = contentData['prayerQuestion'] as String? ?? '';

    return SavedGuideModel(
      id: json['id'] as String,
      title: inputValue,
      // Create minimal content for backward compatibility if needed
      content: summary.isNotEmpty
          ? summary
          : (interpretation.isNotEmpty
              ? interpretation
              : 'Study Guide Content'),
      typeString: inputType,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessedAt: DateTime.parse(json['updatedAt'] as String),
      isSaved: json['isSaved'] as bool? ?? false,
      verseReference: inputType == 'scripture' ? inputValue : null,
      topicName: inputType == 'topic' ? inputValue : null,
      // Store structured content (this is the proper way)
      summary: summary.isNotEmpty ? summary : null,
      interpretation: interpretation.isNotEmpty ? interpretation : null,
      context: context.isNotEmpty ? context : null,
      relatedVerses: relatedVerses.isNotEmpty ? relatedVerses : null,
      reflectionQuestions:
          reflectionQuestions.isNotEmpty ? reflectionQuestions : null,
      prayerPoints: prayerPoints.isNotEmpty ? prayerPoints : null,
      // Store reflection enhancement fields
      interpretationInsights:
          interpretationInsights.isNotEmpty ? interpretationInsights : null,
      summaryInsights: summaryInsights.isNotEmpty ? summaryInsights : null,
      reflectionAnswers:
          reflectionAnswers.isNotEmpty ? reflectionAnswers : null,
      contextQuestion: contextQuestion.isNotEmpty ? contextQuestion : null,
      summaryQuestion: summaryQuestion.isNotEmpty ? summaryQuestion : null,
      relatedVersesQuestion:
          relatedVersesQuestion.isNotEmpty ? relatedVersesQuestion : null,
      reflectionQuestion:
          reflectionQuestion.isNotEmpty ? reflectionQuestion : null,
      prayerQuestion: prayerQuestion.isNotEmpty ? prayerQuestion : null,
    );
  }

  SavedGuideEntity toEntity() => SavedGuideEntity(
        id: id,
        title: title,
        content: content,
        type: typeString == 'verse' ? GuideType.verse : GuideType.topic,
        createdAt: createdAt,
        lastAccessedAt: lastAccessedAt,
        isSaved: isSaved,
        verseReference: verseReference,
        topicName: topicName,
        summary: summary,
        interpretation: interpretation,
        context: context,
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
      );

  @override
  SavedGuideModel copyWith({
    String? id,
    String? title,
    String? content,
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
    GuideType? type,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    bool? isSaved,
    String? verseReference,
    String? topicName,
  }) =>
      SavedGuideModel(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        typeString: type != null
            ? (type == GuideType.verse ? 'verse' : 'topic')
            : typeString,
        createdAt: createdAt ?? this.createdAt,
        lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
        isSaved: isSaved ?? this.isSaved,
        verseReference: verseReference ?? this.verseReference,
        topicName: topicName ?? this.topicName,
        // Support for structured content updates
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

  /// Convert to StudyGuide with structured content only
  ///
  /// This method now only uses structured content fields and provides
  /// sensible defaults for missing data, eliminating the fragile string parsing.
  StudyGuide toStudyGuide() => StudyGuide(
        id: id,
        input: verseReference ?? topicName ?? title,
        inputType: typeString == 'verse' ? 'scripture' : 'topic',
        summary: summary ?? _extractSummaryFromContent(),
        interpretation: interpretation ?? _extractInterpretationFromContent(),
        context: context ?? _extractContextFromContent(),
        relatedVerses: relatedVerses ?? _extractRelatedVersesFromContent(),
        reflectionQuestions:
            reflectionQuestions ?? _extractReflectionQuestionsFromContent(),
        prayerPoints: prayerPoints ?? _extractPrayerPointsFromContent(),
        interpretationInsights: interpretationInsights,
        summaryInsights: summaryInsights,
        reflectionAnswers: reflectionAnswers,
        contextQuestion: contextQuestion,
        summaryQuestion: summaryQuestion,
        relatedVersesQuestion: relatedVersesQuestion,
        reflectionQuestion: reflectionQuestion,
        prayerQuestion: prayerQuestion,
        language: 'en', // Default language
        createdAt: createdAt,
        isSaved: isSaved,
      );

  /// Extract summary from content as fallback (safer than full parsing)
  String _extractSummaryFromContent() {
    if (content.isEmpty) return 'No summary available';

    // Look for summary section with simple, safer extraction
    final summaryMatch = RegExp(r'\*\*Summary:\*\*\s*([^\*]+)', dotAll: true)
        .firstMatch(content);
    if (summaryMatch != null) {
      return summaryMatch.group(1)?.trim().split('\n').first ??
          'No summary available';
    }

    // Fallback: Use first paragraph of content
    final firstParagraph = content.trim().split('\n\n').first;
    return firstParagraph.length > 200
        ? '${firstParagraph.substring(0, 200)}...'
        : firstParagraph;
  }

  /// Extract interpretation from content as fallback
  String _extractInterpretationFromContent() {
    if (content.isEmpty) return 'No interpretation available';

    final interpretationMatch =
        RegExp(r'\*\*Interpretation:\*\*\s*([^\*]+)', dotAll: true)
            .firstMatch(content);
    if (interpretationMatch != null) {
      return interpretationMatch.group(1)?.trim().split('\n').first ??
          'No interpretation available';
    }

    return 'No interpretation available';
  }

  /// Extract context from content as fallback
  String _extractContextFromContent() {
    if (content.isEmpty) return 'No context available';

    final contextMatch = RegExp(r'\*\*Context:\*\*\s*([^\*]+)', dotAll: true)
        .firstMatch(content);
    if (contextMatch != null) {
      return contextMatch.group(1)?.trim().split('\n').first ??
          'No context available';
    }

    return 'No context available';
  }

  /// Extract related verses from content as fallback
  List<String> _extractRelatedVersesFromContent() {
    if (content.isEmpty) return <String>[];

    final versesMatch =
        RegExp(r'\*\*Related Verses:\*\*\s*((?:•[^\*\n]+\n?)+)', dotAll: true)
            .firstMatch(content);
    if (versesMatch != null) {
      final versesText = versesMatch.group(1) ?? '';
      return versesText
          .split('\n')
          .where((line) => line.trim().startsWith('•'))
          .map((line) => line.trim().replaceFirst('•', '').trim())
          .where((verse) => verse.isNotEmpty)
          .take(5) // Limit to 5 verses for safety
          .toList();
    }

    return <String>[];
  }

  /// Extract reflection questions from content as fallback
  List<String> _extractReflectionQuestionsFromContent() {
    if (content.isEmpty) return <String>[];

    final questionsMatch = RegExp(
            r'\*\*Reflection Questions:\*\*\s*((?:•[^\*\n]+\n?)+)',
            dotAll: true)
        .firstMatch(content);
    if (questionsMatch != null) {
      final questionsText = questionsMatch.group(1) ?? '';
      return questionsText
          .split('\n')
          .where((line) => line.trim().startsWith('•'))
          .map((line) => line.trim().replaceFirst('•', '').trim())
          .where((question) => question.isNotEmpty)
          .take(5) // Limit to 5 questions for safety
          .toList();
    }

    return <String>[];
  }

  /// Extract prayer points from content as fallback
  List<String> _extractPrayerPointsFromContent() {
    if (content.isEmpty) return <String>[];

    final prayerMatch =
        RegExp(r'\*\*Prayer Points:\*\*\s*((?:•[^\*\n]+\n?)+)', dotAll: true)
            .firstMatch(content);
    if (prayerMatch != null) {
      final prayerText = prayerMatch.group(1) ?? '';
      return prayerText
          .split('\n')
          .where((line) => line.trim().startsWith('•'))
          .map((line) => line.trim().replaceFirst('•', '').trim())
          .where((point) => point.isNotEmpty)
          .take(5) // Limit to 5 points for safety
          .toList();
    }

    return <String>[];
  }
}
