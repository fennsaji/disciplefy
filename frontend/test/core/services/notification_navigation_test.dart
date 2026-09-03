import 'package:disciplefy_bible_study/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression: a memory-verse push used to open the review screen, which
/// needs a verse id a push cannot carry. Opened without one, its back button
/// built '/memory-verses/practice/' from the empty id and hit "Page not
/// found" (issue report, 3 Sept 2026). Both memory-verse push types now land
/// on the memory verse list.
void main() {
  late GoRouter router;
  late NotificationService service;

  Widget stub(String label) => Scaffold(body: Text(label));

  setUp(() {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => stub('home')),
        GoRoute(path: '/memory-verses', builder: (_, __) => stub('list')),
        GoRoute(
            path: '/memory-verse-review', builder: (_, __) => stub('review')),
        GoRoute(
            path: '/memory-verses/practice/:verseId',
            builder: (_, __) => stub('practice')),
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

  for (final type in ['memory_verse_reminder', 'memory_verse_overdue']) {
    testWidgets('$type push opens the memory verse list', (tester) async {
      await pumpApp(tester);

      service.navigateFromNotificationData({'type': type});
      await tester.pumpAndSettle();

      expect(currentPath(), '/memory-verses');
      expect(find.text('list'), findsOneWidget);
      expect(find.text('not-found'), findsNothing);
    });
  }

  testWidgets('memory verse push never lands on a practice route',
      (tester) async {
    await pumpApp(tester);

    service.navigateFromNotificationData({'type': 'memory_verse_overdue'});
    await tester.pumpAndSettle();

    expect(currentPath(), isNot(startsWith('/memory-verses/practice')));
    expect(currentPath(), isNot('/memory-verse-review'));
  });
}
