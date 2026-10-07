import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/utils/logger.dart';

/// Hive `app_settings` flags of the quiet first run.
///
/// A person who came through the new first run (it stores the picked goal)
/// gets no notification prompts until lesson 1 is done. Everyone else,
/// including every existing user, never has the goal key and so is never held
/// back: prompts behave exactly as before for them.
class FirstRunFlags {
  FirstRunFlags._();

  static const String _boxName = 'app_settings';

  /// Set (true) when the lesson-complete page first shows.
  static const String firstLessonCompletedKey = 'first_lesson_completed';

  /// Stored by the first-run cubit when a goal is picked.
  static const String _goalKey = 'first_run_goal';

  /// Marks lesson 1 as done. Never throws.
  static Future<void> markFirstLessonCompleted() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      final box = Hive.box(_boxName);
      if (box.get(firstLessonCompletedKey) == true) return;
      await box.put(firstLessonCompletedKey, true);
    } catch (e) {
      Logger.warning('Could not save first lesson flag',
          tag: 'FIRST_RUN', context: {'error': e.runtimeType.toString()});
    }
  }

  /// False only while a new first-run user has not finished lesson 1.
  static bool get notificationPromptsAllowed {
    try {
      if (!Hive.isBoxOpen(_boxName)) return true;
      final box = Hive.box(_boxName);
      if (box.get(firstLessonCompletedKey) == true) return true;
      return box.get(_goalKey) == null;
    } catch (_) {
      return true;
    }
  }
}
