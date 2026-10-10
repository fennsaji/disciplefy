import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/lesson_discipler_gate.dart';

import '../../../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

void main() {
  setUp(() {
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    final guest = _MockGuest();
    final flags = _MockFlags();
    when(() => guest.isGuest).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
  });

  tearDown(() async => sl.reset());

  group('lessonShowsFollowUpChat', () {
    test('hidden for a guest, whatever the plan says', () {
      expect(
          lessonShowsFollowUpChat(planShowsChat: true, isGuest: true), isFalse);
      expect(lessonShowsFollowUpChat(planShowsChat: false, isGuest: true),
          isFalse);
    });

    test('a full account follows the plan (shown, or locked for upgrade)', () {
      expect(
          lessonShowsFollowUpChat(planShowsChat: true, isGuest: false), isTrue);
      expect(lessonShowsFollowUpChat(planShowsChat: false, isGuest: false),
          isFalse);
    });
  });

  group('lessonDisciplerGate', () {
    Future<Future<bool>> tapAsk(WidgetTester tester,
        {required bool guest}) async {
      late Future<bool> result;
      await tester.pumpWidget(welcomeApp(
        screen: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => result = lessonDisciplerGate(c, isGuest: guest),
              child: const Text('Ask Discipler'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Ask Discipler'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('a guest gets the Discipler account sheet, never an upgrade',
        (tester) async {
      final result = await tapAsk(tester, guest: true);
      expect(find.text('Discipler needs an account'), findsOneWidget);
      expect(find.text('Tap to upgrade'), findsNothing);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('a full account goes straight on', (tester) async {
      final result = await tapAsk(tester, guest: false);
      expect(find.text('Discipler needs an account'), findsNothing);
      expect(await result, isTrue);
    });
  });

  group('lessonListenGate', () {
    Future<Future<bool>> tapListen(WidgetTester tester,
        {required bool guest}) async {
      late Future<bool> result;
      await tester.pumpWidget(welcomeApp(
        screen: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => result = lessonListenGate(c, isGuest: guest),
              child: const Text('Listen'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Listen'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('a guest gets the account sheet with account wording',
        (tester) async {
      final result = await tapListen(tester, guest: true);
      expect(find.text('Listening needs an account'), findsOneWidget);
      expect(find.textContaining('pgrade'), findsNothing);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('a full account goes straight on', (tester) async {
      final result = await tapListen(tester, guest: false);
      expect(find.text('Listening needs an account'), findsNothing);
      expect(await result, isTrue);
    });
  });
}
