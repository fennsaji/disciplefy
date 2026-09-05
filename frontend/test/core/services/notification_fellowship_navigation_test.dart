import 'package:disciplefy_bible_study/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression: the community pushes the backend sends were missing from the
/// `validTypes` allowlist in _navigateFromNotification, so every one of them
/// fell through to the "unknown type" branch and force-navigated to '/'.
/// Tapping "X commented on your post" dumped the user on the home screen
/// instead of the thread.
void main() {
  late GoRouter router;
  late NotificationService service;

  const fellowshipId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

  Widget stub(String label) => Scaffold(body: Text(label));

  setUp(() {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => stub('home')),
        GoRoute(path: '/community', builder: (_, __) => stub('community')),
        GoRoute(
            path: '/community/:fellowshipId',
            builder: (_, __) => stub('fellowship')),
        GoRoute(
            path: '/community/:fellowshipId/feed',
            builder: (_, __) => stub('feed')),
        GoRoute(
            path: '/community/:fellowshipId/members',
            builder: (_, __) => stub('members')),
      ],
      errorBuilder: (_, __) => stub('not-found'),
    );
    service = NotificationService(
      // Never touched by navigation; a client with no session is enough.
      supabaseClient: SupabaseClient('http://localhost', 'anon'),
      router: router,
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  String currentPath() => router.routerDelegate.currentConfiguration.uri.path;

  group('post activity opens the feed', () {
    for (final type in [
      'fellowship_new_post',
      'fellowship_new_comment',
      'fellowship_reaction',
      'fellowship_question',
    ]) {
      testWidgets('$type opens the fellowship feed', (tester) async {
        await pumpApp(tester);

        service.navigateFromNotificationData({
          'type': type,
          'fellowship_id': fellowshipId,
        });
        await tester.pumpAndSettle();

        expect(currentPath(), '/community/$fellowshipId/feed');
      });
    }
  });

  // 'meeting_invite' is deliberately absent: that value only ever goes into
  // the notification_logs row. The push itself carries
  // 'fellowship_meeting_invite'.
  group('meeting pushes open the fellowship home', () {
    for (final type in [
      'fellowship_meeting_reminder',
      'fellowship_meeting',
      'fellowship_meeting_cancelled',
      'fellowship_meeting_invite',
    ]) {
      testWidgets('$type opens the fellowship', (tester) async {
        await pumpApp(tester);

        service.navigateFromNotificationData({
          'type': type,
          'fellowship_id': fellowshipId,
        });
        await tester.pumpAndSettle();

        expect(currentPath(), '/community/$fellowshipId');
      });
    }
  });

  testWidgets('fellowship_member_joined opens the member list', (tester) async {
    await pumpApp(tester);

    service.navigateFromNotificationData({
      'type': 'fellowship_member_joined',
      'fellowship_id': fellowshipId,
    });
    await tester.pumpAndSettle();

    expect(currentPath(), '/community/$fellowshipId/members');
  });

  testWidgets('a community push with no fellowship_id falls back to the list',
      (tester) async {
    await pumpApp(tester);

    service.navigateFromNotificationData({'type': 'fellowship_new_comment'});
    await tester.pumpAndSettle();

    expect(currentPath(), '/community');
  });

  testWidgets('a genuinely unknown type still falls back to home',
      (tester) async {
    await pumpApp(tester);

    service.navigateFromNotificationData({'type': 'not_a_real_push_type'});
    await tester.pumpAndSettle();

    expect(currentPath(), '/');
  });
}
