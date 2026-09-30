import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_community_section.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

const _languages = [
  AppLanguage.english,
  AppLanguage.hindi,
  AppLanguage.malayalam,
];

void main() {
  late FakeTranslationService translations;

  setUpAll(() async {
    await loadAppFonts();
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDownAll(sl.reset);

  Widget app(Widget child, {required bool dark}) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );

  group('HomeLockedPathsCard at 320x640', () {
    for (final dark in [false, true]) {
      for (final language in _languages) {
        testWidgets('${dark ? 'dark' : 'light'} ${language.code}',
            (tester) async {
          useSurface(tester, const Size(320, 640));
          translations.language = language;
          addTearDown(() => translations.language = AppLanguage.english);
          await tester.pumpWidget(
            app(const HomeLockedPathsCard(), dark: dark),
          );

          expect(tester.takeException(), isNull);
          expect(
            find.text(
                translations.getTranslation('app_status.locked_paths_body')),
            findsOneWidget,
          );
          expectNoTruncatedText(tester);

          final palette = ReaderPalette.of(
              tester.element(find.byType(HomeLockedPathsCard)));
          final box = tester
              .widget<Container>(find
                  .descendant(
                    of: find.byType(HomeLockedPathsCard),
                    matching: find.byType(Container),
                  )
                  .first)
              .decoration! as BoxDecoration;
          expect(box.color, palette.card);
        });
      }
    }
  });

  group('HomeJoinPill', () {
    for (final dark in [false, true]) {
      testWidgets('${dark ? 'dark' : 'light'}: CTA stadium pill, tap joins',
          (tester) async {
        var taps = 0;
        await tester.pumpWidget(app(
          Align(
            alignment: Alignment.topLeft,
            child: HomeJoinPill(
              label: 'Join',
              isJoining: false,
              onPressed: () => taps++,
            ),
          ),
          dark: dark,
        ));
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        final palette =
            ReaderPalette.of(tester.element(find.byType(HomeJoinPill)));
        expect(button.style!.shape!.resolve({}), isA<StadiumBorder>());
        expect(button.style!.backgroundColor!.resolve({}), palette.ctaFill);

        await tester.tap(find.text('Join'));
        expect(taps, 1);
      });
    }

    testWidgets('shows a spinner and ignores taps while joining',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(
        Align(
          alignment: Alignment.topLeft,
          child: HomeJoinPill(
            label: 'Join',
            isJoining: true,
            onPressed: () => taps++,
          ),
        ),
        dark: false,
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });
  });
}
