import 'package:equatable/equatable.dart';

/// Where a study guide sits inside a learning path ("Lesson 2 of 8").
class LessonRef extends Equatable {
  final String pathId;
  final String pathTitle;
  final int lessonNumber;
  final int lessonTotal;

  const LessonRef({
    required this.pathId,
    required this.pathTitle,
    required this.lessonNumber,
    required this.lessonTotal,
  });

  bool get isLast => lessonNumber >= lessonTotal;

  Map<String, String> toQuery() => {
        'path_id': pathId,
        'path_title': pathTitle,
        'lesson_number': '$lessonNumber',
        'lesson_total': '$lessonTotal',
      };

  static LessonRef? fromQuery(Map<String, String> q) {
    final id = q['path_id'];
    final n = int.tryParse(q['lesson_number'] ?? '');
    final total = int.tryParse(q['lesson_total'] ?? '');
    if (id == null || id.isEmpty || n == null || total == null) return null;
    if (n < 1 || total < 1 || n > total) return null;
    return LessonRef(
      pathId: id,
      pathTitle: q['path_title'] ?? '',
      lessonNumber: n,
      lessonTotal: total,
    );
  }

  @override
  List<Object?> get props => [pathId, pathTitle, lessonNumber, lessonTotal];
}
