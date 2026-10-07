import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/presentation/widgets/bottom_nav.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';

import '../../helpers/text_fit.dart';

/// The dock's labels in Hindi and Malayalam have taller lines than Inter;
/// every item must still lay out without overflow, without cutting text and
/// without shrinking a label below 12pt.
void main() {
  setUpAll(loadAppFonts);

  final fiveTabs = [
    DisciplefyBottomNav.defaultTabs[0],
    DisciplefyBottomNav.defaultTabs[1],
    DisciplefyBottomNav.disciplerTab,
    DisciplefyBottomNav.defaultTabs[2],
    DisciplefyBottomNav.defaultTabs[3],
  ];

  for (final width in [360.0, 390.0]) {
    for (final lang in ['en', 'hi', 'ml']) {
      for (final dark in [false, true]) {
        final name = '${width.toInt()}px $lang ${dark ? 'dark' : 'light'}';
        testWidgets('dock fits all five items: $name', (tester) async {
          tester.view.physicalSize = Size(width, 300);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ShowCaseWidget(
              builder: (_) => Scaffold(
                bottomNavigationBar: DisciplefyBottomNav(
                  currentIndex: 1,
                  tabs: fiveTabs,
                  onTap: (_) {},
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final l10n = AppLocalizations.of(
              tester.element(find.byType(DisciplefyBottomNav)))!;
          for (final tab in fiveTabs) {
            final label = tab.id == DisciplefyBottomNav.disciplerTab.id
                ? l10n.navDiscipler
                : l10n.navLabel(tab.id);
            expect(find.text(label), findsOneWidget, reason: label);
            // Shown at full size: the label's FittedBox must not shrink it
            // below the readable minimum.
            final text = find.text(label);
            final laidOut = tester.getSize(text).width;
            final painted =
                tester.getBottomRight(text).dx - tester.getTopLeft(text).dx;
            final effective =
                DisciplefyBottomNav.labelFontSize * painted / laidOut;
            expect(effective, greaterThanOrEqualTo(12 - 0.01),
                reason:
                    '$label is scaled to ${effective.toStringAsFixed(1)}pt');
          }
          expectNoTruncatedText(tester);
        });
      }
    }
  }
}
