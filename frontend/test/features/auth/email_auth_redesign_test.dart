import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/pages/email_auth_screen.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/terms_acceptance_checkbox.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

void main() {
  late MockAuthBloc authBloc;
  late FakeTranslationService translations;

  setUpAll(() {
    registerFallbackValue(const GoogleSignInRequested());
  });

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    authBloc = MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: const UnauthenticatedState());
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpEmailAuth(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(welcomeApp(
      screen: const EmailAuthScreen(),
      path: '/email-auth',
      dark: dark,
      bloc: authBloc,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> toggleMode(WidgetTester tester) async {
    final toggle = find.byKey(const Key('email_auth_toggle_mode'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.byKey(const Key('email_auth_submit'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: sign in shows eyebrow, title, fields and switch line',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpEmailAuth(tester, dark: dark);

      expect(find.text('WELCOME BACK'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Create one'), findsOneWidget);
      expect(find.byKey(const Key('email_auth_name')), findsNothing);
      expect(find.byType(LegalLinksLine), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets(
          '$theme/${language.code}: both modes fit 320x640 without overflow',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        translations.language = language;
        await pumpEmailAuth(tester, dark: dark);
        expect(tester.takeException(), isNull);

        await toggleMode(tester);
        expect(find.byKey(const Key('email_auth_name')), findsOneWidget);
        // Validation errors must also fit.
        await submit(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('toggles to create account and back', (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpEmailAuth(tester, dark: true);

    await toggleMode(tester);
    expect(find.text('JOIN DISCIPLEFY'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.byType(LegalLinksLine), findsOneWidget);

    await toggleMode(tester);
    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.byKey(const Key('email_auth_name')), findsNothing);
  });

  testWidgets('invalid input shows validation messages and dispatches nothing',
      (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpEmailAuth(tester, dark: false);

    await tester.enterText(
        find.byKey(const Key('email_auth_email')), 'not-an-email');
    await submit(tester);

    expect(find.text('Please enter a valid email address'), findsOneWidget);
    verifyNever(() => authBloc.add(any()));
  });

  testWidgets('sign in dispatches EmailSignInRequested', (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpEmailAuth(tester, dark: true);

    await tester.enterText(
        find.byKey(const Key('email_auth_email')), 'fenn@example.com');
    await tester.enterText(
        find.byKey(const Key('email_auth_password')), 'secret123');
    await submit(tester);

    verify(() => authBloc.add(const EmailSignInRequested(
          email: 'fenn@example.com',
          password: 'secret123',
        ))).called(1);
  });

  testWidgets('create account dispatches EmailSignUpRequested', (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpEmailAuth(tester, dark: false);
    await toggleMode(tester);

    await tester.enterText(find.byKey(const Key('email_auth_name')), 'Fenn');
    await tester.enterText(
        find.byKey(const Key('email_auth_email')), 'fenn@example.com');
    await tester.enterText(
        find.byKey(const Key('email_auth_password')), 'secret123');
    await submit(tester);

    verify(() => authBloc.add(const EmailSignUpRequested(
          email: 'fenn@example.com',
          password: 'secret123',
          fullName: 'Fenn',
        ))).called(1);
  });

  testWidgets('password visibility toggles', (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpEmailAuth(tester, dark: true);

    EditableText field() => tester.widget<EditableText>(find.descendant(
        of: find.byKey(const Key('email_auth_password')),
        matching: find.byType(EditableText)));

    expect(field().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  group('no cut-off text at 320px', () {
    setUpAll(loadAppFonts);
    for (final language in AppLanguage.values) {
      testWidgets(language.code, (tester) async {
        useSurface(tester, const Size(320, 1400));
        translations.language = language;
        await pumpEmailAuth(tester, dark: true);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
        await toggleMode(tester);
        expectNoTruncatedText(tester);
      });
    }
  });
}
