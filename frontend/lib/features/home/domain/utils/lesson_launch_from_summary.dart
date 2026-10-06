import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/utils/lesson_launch.dart';

/// Study-guide URL for the next lesson of [s], with the same query keys as
/// the path-detail launcher.
///
/// Throws [ArgumentError] when the path has no next lesson.
String buildLessonLaunchFromSummary(
  ActivePathSummary s,
  StudyMode mode,
  String language,
) {
  final next = s.next;
  if (next == null) {
    throw ArgumentError.value(s.pathId, 's', 'path has no next lesson');
  }
  return buildLessonLocation(
    input: next.title,
    inputType: next.inputType,
    topicId: next.topicId,
    description: next.description,
    pathDescription: s.description,
    discipleLevel: s.discipleLevel,
    ref: LessonRef(
      pathId: s.pathId,
      pathTitle: s.title,
      lessonNumber: next.number,
      lessonTotal: next.total > 0 ? next.total : s.lessonTotal,
    ),
    mode: mode,
    language: language,
  );
}
