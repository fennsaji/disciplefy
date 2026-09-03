import 'package:disciplefy_bible_study/core/navigation/go_router_study_navigator.dart';
import 'package:disciplefy_bible_study/core/navigation/study_navigator.dart';
import 'package:flutter_test/flutter_test.dart';

/// A study guide opened from a push notification has nothing beneath it, so
/// back-navigation falls through to the source-based fallback. The source
/// strings the notification service emits must map to a real enum value —
/// they used to hit `orElse: saved` and strand the user on the empty Saved
/// Guides screen.
void main() {
  final navigator = GoRouterStudyNavigator();

  test('notification source parses to notification, not saved', () {
    expect(
      navigator.parseNavigationSource('notification'),
      StudyNavigationSource.notification,
    );
  });

  test('every source string the notification service emits is recognised', () {
    // Keep in sync with the `source=` values in notification_service.dart.
    for (final source in ['notification']) {
      expect(
        navigator.parseNavigationSource(source),
        isNot(StudyNavigationSource.saved),
        reason: '"$source" falls through to the saved-guides fallback',
      );
    }
  });

  test('unknown sources still fall back to saved', () {
    expect(
      navigator.parseNavigationSource('something_else'),
      StudyNavigationSource.saved,
    );
  });
}
