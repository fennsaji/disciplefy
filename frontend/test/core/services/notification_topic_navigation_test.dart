import 'package:disciplefy_bible_study/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 'recommended_topic', 'for_you' and 'continue_learning' all name a topic to
/// generate a fresh study guide for — 'continue_learning' points at the next
/// topic in the user's most recently active learning path rather than a
/// personalized pick, but the client side is identical for all three
/// (product decision, 4 Sept 2026, replacing the old "reopen an unfinished
/// guide" behavior). This locks in that the three share one code path and
/// none of them regress to the old per-type navigation.
void main() {
  late GoRouter router;
  late NotificationService service;

  Widget stub(String label) => Scaffold(body: Text(label));

  setUp(() {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => stub('home')),
        GoRoute(path: '/study-guide-v2', builder: (_, __) => stub('generate')),
        GoRoute(path: '/study-topics', builder: (_, __) => stub('topics')),
      ],
      errorBuilder: (_, __) => stub('not-found'),
    );
    service = NotificationService(
      supabaseClient: SupabaseClient('http://localhost', 'anon'),
      router: router,
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  String currentPath() => router.routerDelegate.currentConfiguration.uri.path;
  Map<String, String> currentQuery() =>
      router.routerDelegate.currentConfiguration.uri.queryParameters;

  for (final type in ['recommended_topic', 'for_you', 'continue_learning']) {
    testWidgets('$type with a topic generates a fresh guide', (tester) async {
      await pumpApp(tester);

      service.navigateFromNotificationData({
        'type': type,
        'topic_id': 'topic-1',
        'topic_title': 'Unity in Christ',
        'topic_description': 'A study on unity',
        'path_id':
            'path-1', // present for continue_learning, harmless for the rest
      });
      await tester.pumpAndSettle();

      expect(currentPath(), '/study-guide-v2');
      final q = currentQuery();
      expect(q['input'], 'Unity in Christ');
      expect(q['type'], 'topic');
      expect(q['source'], 'notification');
      expect(q['topic_id'], 'topic-1');
      expect(find.text('generate'), findsOneWidget);
    });

    testWidgets('$type with no topic title falls back to Topics',
        (tester) async {
      await pumpApp(tester);

      service.navigateFromNotificationData({'type': type});
      await tester.pumpAndSettle();

      expect(currentPath(), '/study-topics');
    });
  }
}
