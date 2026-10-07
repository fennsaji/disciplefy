import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';

/// Data for `nux.lesson_started` / `nux.lesson_completed`: the path id, the
/// lesson number, the mode name and whether it is the first-run lesson.
/// Never the path or lesson title.
Map<String, Object?> buildLessonEventData({
  required LessonRef lesson,
  required StudyMode mode,
  required bool firstRun,
}) =>
    {
      'path_id': lesson.pathId,
      'lesson_number': lesson.lessonNumber,
      'mode': mode.name,
      'first_run': firstRun,
    };

/// Sends a path lesson's start and completion, each at most once for the
/// screen that owns it.
class LessonEventTracker {
  final Map<String, Object?> _data;
  bool _started = false;
  bool _completed = false;

  LessonEventTracker({
    required LessonRef lesson,
    required StudyMode mode,
    required bool firstRun,
  }) : _data = buildLessonEventData(
            lesson: lesson, mode: mode, firstRun: firstRun);

  /// The lesson's guide began loading (generated or from the cache).
  void started() {
    if (_started) return;
    _started = true;
    ActivationAnalytics.maybeTrack(NuxEvent.lessonStarted, _data);
  }

  /// The lesson's completion was recorded on the server.
  void completed() {
    if (_completed) return;
    _completed = true;
    ActivationAnalytics.maybeTrack(NuxEvent.lessonCompleted, _data);
  }
}
