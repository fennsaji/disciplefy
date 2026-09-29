import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/pages/language_selection_screen.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/widgets/language_selection_card.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

void main() {
  late FakeTranslationService translations;
  late FakeLanguagePreferenceService languageService;

  setUp(() {
    translations = FakeTranslationService();
    languageService = FakeLanguagePreferenceService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<LanguagePreferenceService>(languageService);
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpLanguage(WidgetTester tester, {required bool dark}) async {
    await tester.pumpWidget(welcomeApp(
      screen: const LanguageSelectionScreen(),
      path: '/language-selection',
      dark: dark,
    ));
    await tester.pumpAndSettle();
  }

  LanguageSelectionCard card(WidgetTester tester, AppLanguage language) =>
      tester.widget<LanguageSelectionCard>(
          find.byKey(Key('language_option_${language.code}')));

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: shows eyebrow, title and three options',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await pumpLanguage(tester, dark: dark);

      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('Welcome to Disciplefy!'), findsOneWidget);
      expect(find.byType(LanguageSelectionCard), findsNWidgets(3));
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
      expect(find.text('Malayalam'), findsOneWidget);
      expect(card(tester, AppLanguage.english).isSelected, isTrue);
      expect(tester.takeException(), isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets('$theme/${language.code}: fits 320x640 without overflow',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        translations.language = language;
        await pumpLanguage(tester, dark: dark);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('picking a language and Continue saves it and goes home',
      (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpLanguage(tester, dark: true);

    await tester.tap(find.byKey(const Key('language_option_ml')));
    await tester.pump();
    expect(card(tester, AppLanguage.malayalam).isSelected, isTrue);
    expect(card(tester, AppLanguage.english).isSelected, isFalse);

    await tester.tap(find.byKey(const Key('language_continue')));
    await tester.pumpAndSettle();

    expect(languageService.saved, [AppLanguage.malayalam]);
    expect(find.text('stub:/'), findsOneWidget);
  });

  testWidgets('Skip for now saves English and goes home', (tester) async {
    useSurface(tester, const Size(390, 844));
    await pumpLanguage(tester, dark: false);

    await tester.tap(find.byKey(const Key('language_skip')));
    await tester.pumpAndSettle();

    expect(languageService.saved, [AppLanguage.english]);
    expect(find.text('stub:/'), findsOneWidget);
  });

  group('no cut-off text at 320px', () {
    setUpAll(loadAppFonts);
    for (final language in AppLanguage.values) {
      testWidgets(language.code, (tester) async {
        useSurface(tester, const Size(320, 1400));
        translations.language = language;
        await pumpLanguage(tester, dark: true);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }
  });
}
