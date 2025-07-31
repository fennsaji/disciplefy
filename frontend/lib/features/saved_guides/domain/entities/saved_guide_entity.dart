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
  
  // Legacy content field for backward compatibility
  final String content;
  
  final GuideType type;
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
    this.verseReference,
    this.topicName,
    this.summary,
    this.interpretation,
    this.context,
    this.relatedVerses,
    this.reflectionQuestions,
    this.prayerPoints,
  });

  SavedGuideEntity copyWith({
    String? id,
    String? title,
    String? content,
    GuideType? type,
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
  }) => SavedGuideEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
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

  /// Returns true if this entity has structured content
  bool get hasStructuredContent => 
      summary != null || interpretation != null || context != null ||
      relatedVerses != null || reflectionQuestions != null || prayerPoints != null;

  /// Gets the content preview for display in lists
  String get contentPreview {
    if (hasStructuredContent && summary != null && summary!.isNotEmpty) {
      return summary!.length > 120 ? '${summary!.substring(0, 120)}...' : summary!;
    }
    
    // Fallback to parsing legacy content format
    if (content.contains('**Summary:**')) {
      final summaryMatch = RegExp(r'\*\*Summary:\*\*\s*([^\*]+)', dotAll: true)
          .firstMatch(content);
      if (summaryMatch != null) {
        final summaryText = summaryMatch.group(1)?.trim() ?? '';
        return summaryText.length > 120 ? '${summaryText.substring(0, 120)}...' : summaryText;
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
      ];
}