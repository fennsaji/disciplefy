import 'package:flutter/foundation.dart';

import 'package:disciplefy_bible_study/core/router/app_routes.dart';

/// When the app-level achievement pop-up may show.
///
/// Pop-ups wait in the gamification queue while a study guide is open, so
/// they never cover the lesson, and on the Lesson complete page until that
/// page has been shown and says they may appear ([release]); a guest's page
/// (with its sign-up block) never does, so their pop-ups wait until they
/// leave it. Any other route shows pop-ups as they arrive, one at a time.
class AchievementPopupGate {
  AchievementPopupGate._();

  static bool _released = false;

  /// True where pop-ups wait: a study guide (`/study-guide`,
  /// `/study-guide/<id>`, `/study-guide-v2`), and the Lesson complete page
  /// until it has called [release].
  static bool holdsAt(String location) {
    final path = location.split('?').first.split('#').first;
    if (path == AppRoutes.lessonComplete) return !_released;
    return path == AppRoutes.studyGuide ||
        path.startsWith('${AppRoutes.studyGuide}/') ||
        path == AppRoutes.studyGuideV2 ||
        path.startsWith('${AppRoutes.studyGuideV2}/');
  }

  /// Days after signing up during which no achievement pop-up shows.
  static const int newUserQuietDays = 7;

  /// Owner rule: no achievement pop-ups for a guest or for a new account
  /// (created less than [newUserQuietDays] ago, or of unknown age). Their
  /// achievements are still earned; only the pop-up is skipped.
  static bool suppressedFor({
    required bool isGuest,
    required DateTime? accountCreatedAt,
    required DateTime now,
  }) {
    if (isGuest || accountCreatedAt == null) return true;
    return now.difference(accountCreatedAt) <
        const Duration(days: newUserQuietDays);
  }

  /// Whether to open the pop-up for the head of the queue now.
  static bool shouldShow({
    required String location,
    required bool hasPending,
    required bool alreadyShowing,
  }) =>
      hasPending && !alreadyShowing && !holdsAt(location);

  static final ValueNotifier<int> _flushRequests = ValueNotifier(0);

  /// Ticks each time waiting pop-ups should be shown (if the route allows).
  static ValueListenable<int> get flushRequests => _flushRequests;

  /// Shows the waiting pop-ups, unless the current route still holds them.
  static void flush() => _flushRequests.value++;

  /// The Lesson complete page is on screen: let the waiting pop-ups show
  /// over it.
  static void release() {
    _released = true;
    flush();
  }

  /// The Lesson complete page is closing: hold again on the next one.
  static void endRelease() => _released = false;

  @visibleForTesting
  static void reset() => _released = false;
}
