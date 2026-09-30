import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/pages/password_reset_screen.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

void main() {
  late MockAuthBloc authBloc;
  late FakeTranslationService translations;
  late StreamController<AuthState> states;

  setUpAll(() async {
    registerFallbackValue(const GoogleSignInRequested());
    await loadAppFonts();
  });

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    authBloc = MockAuthBloc();
    states = StreamController<AuthState>.broadcast();
    whenListen(authBloc, states.stream,
        initialState: const UnauthenticatedState());
  });

  tearDown(() async {
    await states.close();
    await sl.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(welcomeApp(
      screen: const PasswordResetScreen(),
      path: '/password-reset',
      dark: dark,
      bloc: authBloc,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> showSuccess(WidgetTester tester) async {
    states.add(const PasswordResetSentState(email: 'a@b.co'));
    await tester.pumpAndSettle();
  }

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: form shows eyebrow, title, field and actions',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpScreen(tester, dark: dark);

      expect(find.text('ACCOUNT RECOVERY'), findsOneWidget);
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.byKey(const Key('password_reset_email')), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$theme: invalid email is rejected; valid one is sent',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpScreen(tester, dark: dark);

      await tester.tap(find.byKey(const Key('password_reset_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      verifyNever(() => authBloc.add(any()));

      await tester.enterText(
          find.byKey(const Key('password_reset_email')), 'reader@mail.com');
      await tester.tap(find.byKey(const Key('password_reset_submit')));
      await tester.pumpAndSettle();
      verify(() => authBloc.add(
          const PasswordResetRequested(email: 'reader@mail.com'))).called(1);
    });

    testWidgets('$theme: sent state shows confirmation; resend returns',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpScreen(tester, dark: dark);
      await showSuccess(tester);

      expect(find.text('Check Your Email'), findsOneWidget);
      expect(find.byKey(const Key('password_reset_done')), findsOneWidget);

      await tester.tap(find.byKey(const Key('password_reset_resend')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('password_reset_email')), findsOneWidget);
    });

    testWidgets('$theme: an error shows the app snackbar', (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpScreen(tester, dark: dark);
      states.add(const AuthErrorState(message: 'boom'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('boom'), findsNothing);
    });

    for (final language in AppLanguage.values) {
      testWidgets('$theme/${language.code}: both states fit 320x640',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        translations.language = language;
        await pumpScreen(tester, dark: dark);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);

        await showSuccess(tester);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }
  }
}
