import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';

/// Parses [ActivePathSummary] from the recommended-path JSON. Defensive:
/// missing or malformed fields (older backend, stale cache) never throw.
class ActivePathSummaryModel {
  const ActivePathSummaryModel._();

  /// Mode used when the backend does not name one.
  static const String defaultMode = 'standard';

  static ActivePathSummary fromJson(Map<String, dynamic> pathJson) {
    final total = _int(pathJson['topics_count']);
    final nextJson = pathJson['next_lesson'];
    final next =
        nextJson is Map ? _next(Map<String, dynamic>.from(nextJson)) : null;
    // The backend does not send recommended_mode yet; Task 8 chooses the mode.
    final mode = pathJson['recommended_mode'];

    return ActivePathSummary(
      pathId: _str(pathJson['id']),
      title: _str(pathJson['title']),
      shortTitle: pathJson['short_title'] is String
          ? pathJson['short_title'] as String
          : null,
      description: _str(pathJson['description']),
      discipleLevel: _str(pathJson['disciple_level']),
      lessonTotal: total,
      lessonsCompleted: _int(pathJson['topics_completed']),
      next: next,
      milestoneNumbers: _ints(pathJson['milestone_positions']),
      recommendedMode: mode is String && mode.isNotEmpty ? mode : defaultMode,
      nextLessonNumber: pathJson['next_lesson_number'] is num
          ? (pathJson['next_lesson_number'] as num).toInt()
          : null,
      nextLessonNumberKnown: pathJson.containsKey('next_lesson_number'),
    );
  }

  static NextLesson? _next(Map<String, dynamic> json) {
    final id = _str(json['topic_id']);
    if (id.isEmpty) return null;
    return NextLesson(
      topicId: id,
      title: _str(json['title']),
      description: _str(json['description']),
      inputType: _str(json['input_type'], 'topic'),
      number: _int(json['lesson_number']),
      total: _int(json['lesson_total']),
    );
  }

  static String _str(Object? v, [String fallback = '']) =>
      v is String ? v : fallback;

  static int _int(Object? v) => v is num ? v.toInt() : 0;

  static List<int> _ints(Object? v) =>
      v is List ? v.whereType<num>().map((e) => e.toInt()).toList() : const [];
}
