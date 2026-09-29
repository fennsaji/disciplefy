import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/pages/login_screen.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/terms_acceptance_checkbox.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

void main() {
  late Directory tempDir;
  late MockAuthBloc authBloc;
  late FakeTranslationService translations;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('login_redesign_test');
    Hive.init(tempDir.path);
    await Hive.openBox('app_settings', bytes: Uint8List(0));
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('app_settings').clear();
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    authBloc = MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: const UnauthenticatedState());
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpLogin(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(welcomeApp(
      screen: const LoginScreen(),
      path: '/login',
      dark: dark,
      bloc: authBloc,
    ));
    await tester.pumpAndSettle();
  }

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: shows welcome, feature chips, buttons and terms',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpLogin(tester, dark: dark);

      expect(find.text('Welcome to Disciplefy'), findsOneWidget);
      expect(find.text("What you'll get:"), findsOneWidget);
      for (final chip in [
        'Study guides',
        'Daily verse',
        'Talk to Discipler',
        'Memory verses',
      ]) {
        expect(find.text(chip), findsOneWidget);
      }
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Email'), findsOneWidget);
      expect(find.text('English · Hindi · Malayalam'), findsOneWidget);
      expect(find.byType(LegalLinksLine), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets('$theme/${language.code}: fits 320x640 without overflow',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        translations.language = language;
        await pumpLogin(tester, dark: dark);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Google tap records terms and dispatches GoogleSignInRequested',
      (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpLogin(tester, dark: true);

    // The square test glyphs are far wider than Inter, so the page is
    // taller here than on a phone.
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    verify(() => authBloc.add(const GoogleSignInRequested())).called(1);
    expect(Hive.box('app_settings').get('terms_accepted'), isTrue);
  });

  testWidgets('Email tap records terms and opens email auth', (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpLogin(tester, dark: false);

    await tester.ensureVisible(find.text('Continue with Email'));
    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();

    expect(find.text('stub:/email-auth'), findsOneWidget);
    expect(Hive.box('app_settings').get('terms_accepted'), isTrue);
  });

  testWidgets('loading disables sign-in buttons and shows a spinner',
      (tester) async {
    useSurface(tester, const Size(390, 844));
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: const AuthLoadingState());
    await tester.pumpWidget(welcomeApp(
      screen: const LoginScreen(),
      path: '/login',
      dark: true,
      bloc: authBloc,
    ));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (final button
        in tester.widgetList<OutlinedButton>(find.byType(OutlinedButton))) {
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('auth error shows the generic error snackbar', (tester) async {
    useSurface(tester, const Size(390, 844));
    whenListen(
      authBloc,
      Stream<AuthState>.fromIterable(
          const [AuthErrorState(message: 'Network error')]),
      initialState: const UnauthenticatedState(),
    );
    await pumpLogin(tester, dark: false);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
  });

  testWidgets('feature chips keep their one-line descriptions', (tester) async {
    useSurface(tester, const Size(390, 1400));
    await pumpLogin(tester, dark: true);
    for (final detail in [
      'Personalized insights for any verse or topic',
      'Start each day with inspiring scripture and instant study guides',
      'Talk with your Bible companion',
      'Memorize Scripture with spaced repetition',
    ]) {
      expect(find.text(detail), findsOneWidget);
    }
  });

  group('no cut-off text at 320px', () {
    setUpAll(loadAppFonts);
    for (final language in AppLanguage.values) {
      testWidgets(language.code, (tester) async {
        useSurface(tester, const Size(320, 1600));
        translations.language = language;
        await pumpLogin(tester, dark: true);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }
  });

  testWidgets(
      'with the feature descriptions the sign-in buttons stay on screen '
      'on a 390x844 phone', (tester) async {
    await loadAppFonts();
    useSurface(tester, const Size(390, 844));
    await pumpLogin(tester, dark: true);
    expect(tester.getBottomLeft(find.text('Continue with Email')).dy,
        lessThan(844));
  });
}
