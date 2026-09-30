import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../helpers/text_fit.dart';

/// The coach mark follows the theme: a card bubble whose arrow matches it,
/// a gold step eyebrow and a pill "Got it" that still advances the tour.
void main() {
  setUpAll(loadAppFonts);

  Future<int> pumpTooltip(WidgetTester tester,
      {required bool dark, required Locale locale}) async {
    final key = GlobalKey();
    late BuildContext showcaseContext;
    var nextTaps = 0;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShowCaseWidget(
        builder: (context) => Scaffold(
          body: Builder(builder: (ctx) {
            showcaseContext = ctx;
            return Align(
              alignment: Alignment.bottomCenter,
              child: WalkthroughTooltip(
                showcaseKey: key,
                title: 'Community',
                description: 'Join fellowships and grow together',
                screen: WalkthroughScreen.home,
                stepNumber: 2,
                totalSteps: 5,
                onNext: () => nextTaps++,
                child: const SizedBox(width: 60, height: 50),
              ),
            );
          }),
        ),
      ),
    ));
    await tester.pump();
    ShowCaseWidget.of(showcaseContext).startShowCase([key]);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final gotIt = AppLocalizations.of(showcaseContext)!.walkthroughGotIt;
    await tester.tap(find.text(gotIt));
    await tester.pump();
    return nextTaps;
  }

  for (final dark in [false, true]) {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('ml')]) {
      testWidgets(
          '${dark ? 'dark' : 'light'} ${locale.languageCode}: themed bubble',
          (tester) async {
        final taps = await pumpTooltip(tester, dark: dark, locale: locale);
        expect(tester.takeException(), isNull);
        expect(taps, 1);

        final bubbleFill = dark ? const Color(0xFF17171C) : Colors.white;
        final bubble = find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == bubbleFill &&
            (w.decoration! as BoxDecoration).borderRadius != null);
        expect(bubble, findsWidgets);

        final step = tester.widget<Text>(find.text('2 / 5'));
        expect(step.style?.color,
            dark ? const Color(0xFFE3B154) : const Color(0xFF9A6B10));
        expectNoTruncatedText(tester);
      });
    }
  }
}
