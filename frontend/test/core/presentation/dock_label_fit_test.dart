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

  Future<AppLocalizations> pumpDock(WidgetTester tester,
      {required double width,
      required String lang,
      required bool dark,
      double textScale = 1}) async {
    tester.view.physicalSize = Size(width, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
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
    return AppLocalizations.of(
        tester.element(find.byType(DisciplefyBottomNav)))!;
  }

  String labelOf(AppLocalizations l10n, NavTab tab) =>
      tab.id == DisciplefyBottomNav.disciplerTab.id
          ? l10n.navDiscipler
          : l10n.navLabel(tab.id);

  /// Size the label is painted at, after any scale-down.
  double paintedFontSize(WidgetTester tester, Finder text) {
    final laidOut = tester.getSize(text).width;
    final painted = tester.getBottomRight(text).dx - tester.getTopLeft(text).dx;
    final style = tester.widget<Text>(text).style;
    final base = (style?.fontSize ?? DisciplefyBottomNav.labelFontSize) *
        (tester.widget<Text>(text).textScaler == TextScaler.noScaling
            ? 1
            : MediaQuery.textScalerOf(tester.element(text)).scale(1));
    return base * painted / laidOut;
  }

  for (final width in [360.0, 390.0]) {
    for (final lang in ['en', 'hi', 'ml']) {
      for (final dark in [false, true]) {
        final name = '${width.toInt()}px $lang ${dark ? 'dark' : 'light'}';
        testWidgets('dock fits all five items: $name', (tester) async {
          final l10n =
              await pumpDock(tester, width: width, lang: lang, dark: dark);

          expect(tester.takeException(), isNull);
          for (final tab in fiveTabs) {
            final label = labelOf(l10n, tab);
            expect(find.text(label), findsOneWidget, reason: label);
            // Shown at full size: the label must not be scaled below the
            // readable minimum.
            final effective = paintedFontSize(tester, find.text(label));
            expect(effective, greaterThanOrEqualTo(12 - 0.01),
                reason:
                    '$label is scaled to ${effective.toStringAsFixed(1)}pt');
          }
          expectNoTruncatedText(tester);
        });
      }
    }
  }

  // The narrowest supported phone, at the default and the 130% in-app text
  // size: labels keep a gap between them, never overlap, never go below the
  // 11pt floor and never overflow the dock.
  for (final scale in [1.0, 1.3]) {
    for (final lang in ['en', 'hi', 'ml']) {
      for (final dark in [false, true]) {
        final name = '320px x$scale $lang ${dark ? 'dark' : 'light'}';
        testWidgets('dock labels never collide: $name', (tester) async {
          final l10n = await pumpDock(tester,
              width: 320, lang: lang, dark: dark, textScale: scale);

          expect(tester.takeException(), isNull);
          final dock = tester.getRect(find.byType(DisciplefyBottomNav));
          final rects = <Rect>[];
          for (final tab in fiveTabs) {
            final label = labelOf(l10n, tab);
            final text = find.text(label);
            expect(text, findsOneWidget, reason: label);
            final rect = tester.getRect(text);
            expect(rect.left, greaterThanOrEqualTo(dock.left), reason: label);
            expect(rect.right, lessThanOrEqualTo(dock.right), reason: label);
            final effective = paintedFontSize(tester, text);
            expect(
                effective,
                greaterThanOrEqualTo(
                    DisciplefyBottomNav.minLabelFontSize - 0.01),
                reason:
                    '$label is scaled to ${effective.toStringAsFixed(1)}pt');
            rects.add(rect);
          }
          rects.sort((a, b) => a.left.compareTo(b.left));
          for (var i = 1; i < rects.length; i++) {
            expect(rects[i].left - rects[i - 1].right,
                greaterThanOrEqualTo(2 * DisciplefyBottomNav.slotGap - 0.01),
                reason: 'labels ${i - 1} and $i touch or overlap');
          }
          // The shipped labels fit by scaling; none needs the ellipsis.
          expectNoTruncatedText(tester);
        });
      }
    }
  }
}
