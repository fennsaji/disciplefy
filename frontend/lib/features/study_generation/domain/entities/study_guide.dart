import 'package:equatable/equatable.dart';

/// Domain entity representing a Bible study guide.
/// 
/// This entity encapsulates all the information about a generated study guide,
/// following the Jeff Reed methodology with standardized sections.
class StudyGuide extends Equatable {
  /// Unique identifier for the study guide.
  final String id;
  
  /// The original input (verse reference or topic).
  final String input;
  
  /// The type of input ('scripture' or 'topic').
  final String inputType;
  
  /// The main content/summary of the study guide.
  final String summary;
  
  /// Historical and literary context of the passage.
  final String context;
  
  /// List of related Bible verses for further study.
  final List<String> relatedVerses;
  
  /// Questions for personal reflection and discussion.
  final List<String> reflectionQuestions;
  
  /// Suggested points for prayer based on the study.
  final List<String> prayerPoints;
  
  /// Language code of the study guide.
  final String language;
  
  /// Timestamp when the study guide was created.
  final DateTime createdAt;
  
  /// Optional user ID if the guide was saved by an authenticated user.
  final String? userId;

  /// Creates a new StudyGuide instance.
  /// 
  /// All fields except [userId] are required to ensure the study guide
  /// contains complete information for meaningful Bible study.
  const StudyGuide({
    required this.id,
    required this.input,
    required this.inputType,
    required this.summary,
    required this.context,
    required this.relatedVerses,
    required this.reflectionQuestions,
    required this.prayerPoints,
    required this.language,
    required this.createdAt,
    this.userId,
  });

  /// Creates a copy of this study guide with optionally modified fields.
  /// 
  /// This method is useful for updating specific fields while maintaining
  /// immutability of the entity.
  StudyGuide copyWith({
    String? id,
    String? input,
    String? inputType,
    String? summary,
    String? context,
    List<String>? relatedVerses,
    List<String>? reflectionQuestions,
    List<String>? prayerPoints,
    String? language,
    DateTime? createdAt,
    String? userId,
  }) {
    return StudyGuide(
      id: id ?? this.id,
      input: input ?? this.input,
      inputType: inputType ?? this.inputType,
      summary: summary ?? this.summary,
      context: context ?? this.context,
      relatedVerses: relatedVerses ?? this.relatedVerses,
      reflectionQuestions: reflectionQuestions ?? this.reflectionQuestions,
      prayerPoints: prayerPoints ?? this.prayerPoints,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }

  /// Gets the title of the study guide based on input type and content.
  /// 
  /// For scripture inputs, returns the verse reference.
  /// For topic inputs, returns a formatted title.
  String get title {
    if (inputType == 'scripture') {
      return input;
    } else {
      return 'Study on: $input';
    }
  }

  /// Checks if this study guide is complete with all required sections.
  /// 
  /// A complete study guide must have non-empty content for all sections.
  bool get isComplete {
    return summary.isNotEmpty &&
           context.isNotEmpty &&
           relatedVerses.isNotEmpty &&
           reflectionQuestions.isNotEmpty &&
           prayerPoints.isNotEmpty;
  }

  /// Estimates the reading time for this study guide in minutes.
  /// 
  /// Based on average reading speed of 200 words per minute.
  int get estimatedReadingTimeMinutes {
    final totalWords = _countWords(summary) +
                      _countWords(context) +
                      relatedVerses.fold(0, (sum, verse) => sum + _countWords(verse)) +
                      reflectionQuestions.fold(0, (sum, q) => sum + _countWords(q)) +
                      prayerPoints.fold(0, (sum, point) => sum + _countWords(point));
    
    return (totalWords / 200).ceil().clamp(1, 60); // Min 1, max 60 minutes
  }

  /// Counts the number of words in a given text.
  int _countWords(String text) {
    return text.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  @override
  List<Object?> get props => [
        id,
        input,
        inputType,
        summary,
        context,
        relatedVerses,
        reflectionQuestions,
        prayerPoints,
        language,
        createdAt,
        userId,
      ];

  @override
  String toString() {
    return 'StudyGuide{id: $id, title: $title, language: $language, complete: $isComplete}';
  }
}