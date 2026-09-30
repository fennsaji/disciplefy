import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/http_service.dart';
import 'package:disciplefy_bible_study/features/profile_setup/presentation/pages/profile_setup_screen.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class MockHttpService extends Mock implements HttpService {}

void main() {
  late FakeTranslationService translations;
  late MockHttpService http;

  setUpAll(loadAppFonts);

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    http = MockHttpService();
    sl.registerSingleton<HttpService>(http);
  });

  tearDown(() => sl.reset());

  Future<void> pumpScreen(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(welcomeApp(
      screen: const ProfileSetupScreen(),
      path: '/profile-setup',
      dark: dark,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    final button = find.byKey(const Key('profile_setup_continue'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: shows eyebrow, title, fields, chips and CTA',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpScreen(tester, dark: dark);

      expect(find.text('YOUR PROFILE'), findsOneWidget);
      expect(find.text('Tell us about yourself'), findsOneWidget);
      expect(find.byKey(const Key('profile_setup_photo')), findsOneWidget);
      expect(find.byKey(const Key('profile_setup_first_name')), findsOneWidget);
      expect(find.byKey(const Key('profile_setup_last_name')), findsOneWidget);
      expect(find.byKey(const Key('profile_setup_age_18-25')), findsOneWidget);
      expect(find.byKey(const Key('profile_setup_interest_prayer')),
          findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('$theme: empty names are rejected without a request',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpScreen(tester, dark: dark);

      await tapContinue(tester);
      expect(find.text('First name is required'), findsOneWidget);
      expect(find.text('Last name is required'), findsOneWidget);
      verifyZeroInteractions(http);
    });

    testWidgets('$theme: missing age group and interests warn in order',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpScreen(tester, dark: dark);
      await tester.enterText(
          find.byKey(const Key('profile_setup_first_name')), 'Ruth');
      await tester.enterText(
          find.byKey(const Key('profile_setup_last_name')), 'Naomi');

      await tapContinue(tester);
      expect(find.text('Please select your age group'), findsOneWidget);

      // Clear the floating snackbar so it cannot cover the chip.
      final age = find.byKey(const Key('profile_setup_age_18-25'));
      ScaffoldMessenger.of(tester.element(age)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.ensureVisible(age);
      await tester.tap(age);
      await tapContinue(tester);
      expect(find.text('Please select at least one interest'), findsOneWidget);
      verifyZeroInteractions(http);
    });

    testWidgets('$theme: interest chips toggle their selected state',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpScreen(tester, dark: dark);
      final chip = find.byKey(const Key('profile_setup_interest_prayer'));
      await tester.ensureVisible(chip);

      bool selected() =>
          tester.getSemantics(chip).flagsCollection.isSelected.toBoolOrNull()!;

      expect(selected(), isFalse);
      await tester.tap(chip);
      await tester.pump();
      expect(selected(), isTrue);
      await tester.tap(chip);
      await tester.pump();
      expect(selected(), isFalse);
    });

    for (final language in AppLanguage.values) {
      testWidgets('$theme/${language.code}: fits 320x640', (tester) async {
        useSurface(tester, const Size(320, 640));
        translations.language = language;
        await pumpScreen(tester, dark: dark);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }
  }
}
