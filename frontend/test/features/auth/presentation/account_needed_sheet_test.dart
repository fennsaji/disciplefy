import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/guest_route_gate.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_link_panel.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/account_needed_sheet.dart';

import '../../../helpers/text_fit.dart';
import '../../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

void main() {
  late FakeTranslationService translations;
  late _MockGuest guest;
  late _MockFlags flags;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    guest = _MockGuest();
    flags = _MockFlags();
    when(() => guest.isGuest).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
  });

  tearDown(() async {
    AccountLinkPanel.debugShowApple = null;
    await sl.reset();
  });

  /// A button that calls [requireAccount] and keeps its result.
  Future<Future<bool>> tapGo(WidgetTester tester, AccountReason reason,
      {bool dark = false}) async {
    late Future<bool> result;
    await tester.pumpWidget(welcomeApp(
      dark: dark,
      screen: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => result = requireAccount(c, reason),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return result;
  }

  group('AccountReasons.fromQuery', () {
    test('maps every router and backend reason', () {
      expect(AccountReasons.fromQuery('generate'), AccountReason.generate);
      expect(AccountReasons.fromQuery('discipler'), AccountReason.discipler);
      expect(AccountReasons.fromQuery('community'), AccountReason.community);
      expect(AccountReasons.fromQuery('memory_verses'),
          AccountReason.memoryVerses);
      expect(AccountReasons.fromQuery('other_path'), AccountReason.otherPath);
      expect(AccountReasons.fromQuery('second_path'), AccountReason.secondPath);
    });

    test('null or blank is no reason; unknown is the generic one', () {
      expect(AccountReasons.fromQuery(null), isNull);
      expect(AccountReasons.fromQuery(''), isNull);
      expect(AccountReasons.fromQuery('pricing'), AccountReason.other);
    });

    test('wire values match the router table', () {
      expect(AccountReason.generate.wireValue, AccountReasons.generate);
      expect(AccountReason.discipler.wireValue, AccountReasons.discipler);
      expect(AccountReason.community.wireValue, AccountReasons.community);
      expect(AccountReason.memoryVerses.wireValue, AccountReasons.memoryVerses);
      expect(AccountReason.otherPath.wireValue, AccountReasons.otherPath);
    });
  });

  group('requireAccount', () {
    testWidgets('guest sees the sheet; Continue as guest returns false',
        (tester) async {
      final result = await tapGo(tester, AccountReason.discipler);
      expect(find.text('Discipler needs an account'), findsOneWidget);
      expect(find.text('Ask Discipler and join groups'), findsOneWidget);
      // A guest only ever gets one path; an account opens all of them.
      expect(find.text('Unlock every learning path'), findsOneWidget);
      expect(find.text('Start a second path any time'), findsNothing);
      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      expect(find.text('Discipler needs an account'), findsNothing);
    });

    testWidgets('non-guest passes straight through', (tester) async {
      when(() => guest.isGuest).thenReturn(false);
      final result = await tapGo(tester, AccountReason.community);
      expect(await result, isTrue);
      expect(find.text('Groups need an account'), findsNothing);
    });

    testWidgets('guest mode off: always true, no sheet', (tester) async {
      when(() => flags.guestMode).thenReturn(false);
      final result = await tapGo(tester, AccountReason.community);
      expect(await result, isTrue);
      expect(find.text('Groups need an account'), findsNothing);
    });

    testWidgets('linking with Google closes the sheet and returns true',
        (tester) async {
      when(() => guest.linkGoogle())
          .thenAnswer((_) async => LinkOutcome.linked);
      final result = await tapGo(tester, AccountReason.community);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.text('Groups need an account'), findsNothing);
    });

    testWidgets('a merge into an existing account also returns true',
        (tester) async {
      when(() => guest.linkGoogle())
          .thenAnswer((_) async => LinkOutcome.mergedIntoExisting);
      final result = await tapGo(tester, AccountReason.generate);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('cancelled keeps the sheet open', (tester) async {
      when(() => guest.linkGoogle())
          .thenAnswer((_) async => LinkOutcome.cancelled);
      await tapGo(tester, AccountReason.community);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Groups need an account'), findsOneWidget);
      expect(find.byKey(const Key('account_note')), findsNothing);
    });

    testWidgets('merge failed: not linked yet, sheet stays with a note',
        (tester) async {
      when(() => guest.linkGoogle())
          .thenAnswer((_) async => LinkOutcome.mergeFailed);
      final result = await tapGo(tester, AccountReason.community);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Signed in. Your progress moves over soon.'),
          findsOneWidget);
      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('redirecting (web) keeps the sheet', (tester) async {
      when(() => guest.linkGoogle())
          .thenAnswer((_) async => LinkOutcome.redirecting);
      await tapGo(tester, AccountReason.community);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Groups need an account'), findsOneWidget);
    });

    testWidgets('an error shows a short note', (tester) async {
      when(() => guest.linkGoogle()).thenThrow(Exception('boom'));
      await tapGo(tester, AccountReason.community);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't sign up. Please try again."), findsOneWidget);
    });

    testWidgets('email link pending shows Check your email with the address',
        (tester) async {
      when(() => guest.linkEmail(
            email: 'a@b.co',
            password: any(named: 'password'),
            fullName: any(named: 'fullName'),
          )).thenAnswer((_) async => LinkOutcome.emailConfirmationSent);
      useSurface(tester, const Size(400, 1000));
      final result = await tapGo(tester, AccountReason.community);
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('account_email_name')), 'Anu Mathew');
      await tester.enterText(
          find.byKey(const Key('account_email_address')), 'a@b.co');
      await tester.enterText(
          find.byKey(const Key('account_email_password')), 'secret123');
      await tester.tap(find.byKey(const Key('account_email_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Check your email to confirm: a@b.co'), findsOneWidget);
      verify(() => guest.linkEmail(
            email: 'a@b.co',
            password: 'secret123',
            fullName: 'Anu Mathew',
          )).called(1);
      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('the email form validates before linking', (tester) async {
      useSurface(tester, const Size(400, 1000));
      await tapGo(tester, AccountReason.community);
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account_email_submit')));
      await tester.pumpAndSettle();
      verifyNever(() => guest.linkEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            fullName: any(named: 'fullName'),
          ));
    });
  });

  group('sheet', () {
    testWidgets('titles follow the reason', (tester) async {
      const expected = {
        AccountReason.community: 'Groups need an account',
        AccountReason.discipler: 'Discipler needs an account',
        AccountReason.otherPath: 'Your next path needs an account',
        AccountReason.secondPath: 'Your next path needs an account',
        AccountReason.generate: 'Create an account to generate studies',
        AccountReason.memoryVerses: 'Memory verses need an account',
        AccountReason.saveProgress:
            'Sign up to save your progress and continue',
        AccountReason.other: 'Create a free account',
      };
      for (final entry in expected.entries) {
        await tapGo(tester, entry.key);
        expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
        await tester.tap(find.text('Continue as guest'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a second show while open does not stack another sheet',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(welcomeApp(
        screen: Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      ));
      final first = AccountNeededSheet.show(ctx, AccountReason.community);
      final second = AccountNeededSheet.show(ctx, AccountReason.discipler);
      await tester.pumpAndSettle();
      expect(identical(first, second), isTrue);
      expect(find.byType(AccountNeededSheet), findsOneWidget);
      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();
      expect(await first, isFalse);
    });

    testWidgets('Apple is hidden off iOS and shown when allowed',
        (tester) async {
      await tapGo(tester, AccountReason.community);
      expect(find.text('Continue with Apple'), findsNothing);
      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();

      AccountLinkPanel.debugShowApple = true;
      when(() => guest.linkApple()).thenAnswer((_) async => LinkOutcome.linked);
      final result = await tapGo(tester, AccountReason.community);
      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('buttons are 40px tall', (tester) async {
      AccountLinkPanel.debugShowApple = true;
      await tapGo(tester, AccountReason.community);
      for (final key in ['account_google', 'account_apple', 'account_email']) {
        expect(tester.getSize(find.byKey(Key(key))).height, 40, reason: key);
      }
    });
  });

  group('no cut-off text at 320px', () {
    setUpAll(loadAppFonts);
    for (final language in AppLanguage.values) {
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        testWidgets('sheet ${language.code} $theme', (tester) async {
          AccountLinkPanel.debugShowApple = true;
          useSurface(tester, const Size(320, 900));
          translations.language = language;
          await tapGo(tester, AccountReason.discipler, dark: dark);
          await tester.tap(find.byKey(const Key('account_email')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }
  });
}
