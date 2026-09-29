import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/widgets/onboarding_previews.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

void main() {
  late Directory tempDir;
  late MockAuthBloc authBloc;
  late FakeTranslationService translations;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('onboarding_test');
    Hive.init(tempDir.path);
    // In-memory box: writes complete without real disk I/O, so the screen's
    // awaited Hive writes resolve inside the test's fake-async zone.
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

  Future<void> pumpOnboarding(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(welcomeApp(
      screen: const OnboardingScreen(),
      path: '/onboarding',
      dark: dark,
      bloc: authBloc,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding_continue')));
    await tester.pumpAndSettle();
  }

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: first slide shows its preview, copy and Continue',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpOnboarding(tester, dark: dark);

      expect(find.byType(DailyVersePreview), findsOneWidget);
      expect(find.text('DAILY VERSE'), findsOneWidget);
      expect(find.text("Start each day with God's Word"), findsOneWidget);
      expect(find.text('Psalm 119:105'), findsWidgets);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets(
          '$theme/${language.code}: every slide fits 320x640 without overflow',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        translations.language = language;
        await pumpOnboarding(tester, dark: dark);

        final previews = [
          DailyVersePreview,
          StudyGuidePreview,
          DisciplerChatPreview,
          MemoryReviewPreview,
        ];
        for (var i = 0; i < previews.length; i++) {
          expect(find.byType(previews[i]), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (i < previews.length - 1) await tapContinue(tester);
        }
      });
    }
  }

  testWidgets('Continue advances slides and the last one reads Get Started',
      (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpOnboarding(tester, dark: true);

    await tapContinue(tester);
    expect(find.byType(StudyGuidePreview), findsOneWidget);
    expect(find.text('Personalized insights for your journey'), findsOneWidget);

    await tapContinue(tester);
    expect(find.byType(DisciplerChatPreview), findsOneWidget);

    await tapContinue(tester);
    expect(find.byType(MemoryReviewPreview), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Get Started completes onboarding and goes to login.
    await tapContinue(tester);
    expect(find.text('stub:/login'), findsOneWidget);
    expect(Hive.box('app_settings').get('onboarding_completed'), isTrue);
    expect(Hive.box('app_settings').get('auto_activate_free_plan'), isTrue);
  });

  testWidgets('Skip completes onboarding and goes to login', (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpOnboarding(tester, dark: false);

    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();

    expect(find.text('stub:/login'), findsOneWidget);
    expect(Hive.box('app_settings').get('onboarding_completed'), isTrue);
  });

  group('no cut-off text at 320px', () {
    setUpAll(loadAppFonts);
    for (final language in AppLanguage.values) {
      testWidgets('${language.code}: every slide', (tester) async {
        useSurface(tester, const Size(320, 1200));
        translations.language = language;
        await pumpOnboarding(tester, dark: true);
        // The phone-screen previews are miniature illustrations.
        final previews = [
          find.byType(DailyVersePreview),
          find.byType(StudyGuidePreview),
          find.byType(DisciplerChatPreview),
          find.byType(MemoryReviewPreview),
        ];
        for (var i = 0; i < 4; i++) {
          expectNoTruncatedText(tester, ignoreUnder: previews);
          if (i < 3) await tapContinue(tester);
        }
      });
    }
  });
}
