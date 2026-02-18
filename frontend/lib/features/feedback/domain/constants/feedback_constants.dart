/// Feedback category constants
///
/// IMPORTANT: These must match the database check constraint in the feedback table.
/// Database allows: 'general', 'bug_report', 'feature_request', 'content_feedback', 'study_guide', 'memory_verse'
class FeedbackCategories {
  /// General feedback category
  static const String general = 'general';

  /// Bug report category
  static const String bugReport = 'bug_report';

  /// Feature request category
  static const String featureRequest = 'feature_request';

  /// Content feedback category (for study guides, etc.)
  static const String contentFeedback = 'content_feedback';

  /// Study guide specific feedback
  static const String studyGuide = 'study_guide';

  /// Memory verse specific feedback
  static const String memoryVerse = 'memory_verse';

  /// All valid categories
  static const List<String> validCategories = [
    general,
    bugReport,
    featureRequest,
    contentFeedback,
    studyGuide,
    memoryVerse,
  ];

  /// Validate if a category is valid
  static bool isValid(String category) => validCategories.contains(category);
}
