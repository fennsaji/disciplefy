import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/router/guest_route_gate.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_query_listener.dart';

import '../../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

void main() {
  late _MockGuest guest;
  late _MockFlags flags;
  late GoRouter router;
  late int homeBuilds;

  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    guest = _MockGuest();
    flags = _MockFlags();
    when(() => guest.isGuest).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
    homeBuilds = 0;
  });

  tearDown(() async => sl.reset());

  Widget app(String initial) {
    router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, state) {
            homeBuilds++;
            return AccountQueryListener(
              reason: state.uri.queryParameters[AccountReasons.queryParam],
              child: const Scaffold(body: Text('home')),
            );
          },
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }

  String location() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('opens the sheet once for the reason and clears the query',
      (tester) async {
    await tester.pumpWidget(app('/?account=memory_verses'));
    await tester.pumpAndSettle();
    expect(find.text('Memory verses need an account'), findsOneWidget);
    expect(find.byType(AccountNeededSheet), findsOneWidget);

    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountNeededSheet), findsNothing);
    expect(location(), '/');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('rebuilds with the same query do not reopen it', (tester) async {
    await tester.pumpWidget(app('/?account=community'));
    await tester.pumpAndSettle();
    final buildsWithSheet = homeBuilds;

    // Force rebuilds of Home while the sheet is up.
    tester.element(find.text('home')).markNeedsBuild();
    await tester.pumpAndSettle();
    expect(homeBuilds, greaterThanOrEqualTo(buildsWithSheet));
    expect(find.byType(AccountNeededSheet), findsOneWidget);

    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountNeededSheet), findsNothing);
  });

  testWidgets('a later tap with the same reason opens it again',
      (tester) async {
    await tester.pumpWidget(app('/'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountNeededSheet), findsNothing);

    router.go('/?account=memory_verses');
    await tester.pumpAndSettle();
    expect(find.byType(AccountNeededSheet), findsOneWidget);
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    router.go('/?account=memory_verses');
    await tester.pumpAndSettle();
    expect(find.byType(AccountNeededSheet), findsOneWidget);
  });

  testWidgets('a full account gets no sheet; the query is still cleared',
      (tester) async {
    when(() => guest.isGuest).thenReturn(false);
    await tester.pumpWidget(app('/?account=discipler'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountNeededSheet), findsNothing);
    expect(location(), '/');
  });

  testWidgets('no query: nothing happens', (tester) async {
    await tester.pumpWidget(app('/'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountNeededSheet), findsNothing);
  });
}
