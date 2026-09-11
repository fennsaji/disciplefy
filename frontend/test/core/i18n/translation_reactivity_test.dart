import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';

import 'translation_reactivity_test.mocks.dart';

/// Reads a translated string through `context.tr`. Deliberately `const` so a
/// rebuild of the surrounding app does NOT rebuild it: only a real dependency
/// on the ambient locale can. That is the whole point — screens sitting on the
/// navigator stack are not reconstructed when the language changes, so if
/// `context.tr` registers no dependency they keep rendering the old language.
class _JoinActionLabel extends StatelessWidget {
  const _JoinActionLabel();

  @override
  Widget build(BuildContext context) =>
      Text(context.tr('community.join_action'));
}

@GenerateMocks([LanguagePreferenceService])
void main() {
  late StreamController<AppLanguage> languageChanges;
  late MockLanguagePreferenceService languageService;
  late TranslationService translationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    languageChanges = StreamController<AppLanguage>.broadcast();
    languageService = MockLanguagePreferenceService();
    when(languageService.languageChanges)
        .thenAnswer((_) => languageChanges.stream);
    when(languageService.getSelectedLanguage())
        .thenAnswer((_) async => AppLanguage.english);

    translationService = TranslationService(languageService, prefs);

    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<TranslationService>(translationService);
  });

  tearDown(() async {
    await languageChanges.close();
    await GetIt.instance.reset();
  });

  /// Drives the app the way the real one does: `LocaleService` and
  /// `TranslationService` both listen to the same language stream, so the
  /// locale handed to MaterialApp and the service's own language move together.
  /// Settles after pumping: the global Material/Cupertino delegates resolve
  /// their resources asynchronously, so the very first frame of a MaterialApp
  /// renders before any localized text exists.
  Future<void> pumpAppInLocale(
      WidgetTester tester, ValueNotifier<Locale> locale) async {
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, value, _) => MaterialApp(
          locale: value,
          // The app's own delegates, so the harness supports hi/ml exactly as
          // production does.
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _JoinActionLabel(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'a context.tr string follows a language change without being rebuilt by its parent',
      (tester) async {
    final locale = ValueNotifier<Locale>(const Locale('en'));
    await pumpAppInLocale(tester, locale);
    expect(find.text('Join fellowship'), findsOneWidget);

    languageChanges.add(AppLanguage.hindi);
    await tester.pump(); // let the service consume the stream event
    locale.value = const Locale('hi');
    await tester.pumpAndSettle();

    expect(find.text('फेलोशिप में जुड़ें'), findsOneWidget,
        reason: 'context.tr must depend on the ambient locale, or screens '
            'already built keep rendering the previous language');
    expect(find.text('Join fellowship'), findsNothing);
  });

  testWidgets('a third language switch is picked up too', (tester) async {
    final locale = ValueNotifier<Locale>(const Locale('en'));
    await pumpAppInLocale(tester, locale);

    languageChanges.add(AppLanguage.malayalam);
    await tester.pump();
    locale.value = const Locale('ml');
    await tester.pumpAndSettle();

    expect(find.text('ഫെല്ലോഷിപ്പിൽ ചേരുക'), findsOneWidget);
  });

  testWidgets('tr still works with no Localizations ancestor', (tester) async {
    // Guards the fix itself: resolving the locale must not throw where the
    // widget is built outside a MaterialApp (dialogs, tests, isolated widgets).
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: _JoinActionLabel(),
      ),
    );

    expect(find.text('Join fellowship'), findsOneWidget);
  });
}
