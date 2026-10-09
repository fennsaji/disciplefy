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

  Future<double> dockHeight(WidgetTester tester) async =>
      tester.getSize(find.byType(DisciplefyBottomNav)).height;

  void expectOnlySelected(AppLocalizations l10n) {
    for (final tab in fiveTabs) {
      final label = labelOf(l10n, tab);
      expect(
          find.text(label), tab == fiveTabs[1] ? findsOneWidget : findsNothing,
          reason: label);
    }
  }

  testWidgets('en at 390 shows every label at 12pt+', (tester) async {
    final l10n = await pumpDock(tester, width: 390, lang: 'en', dark: false);
    expect(tester.takeException(), isNull);
    for (final tab in fiveTabs) {
      final label = labelOf(l10n, tab);
      expect(find.text(label), findsOneWidget, reason: label);
      expect(paintedFontSize(tester, find.text(label)),
          greaterThanOrEqualTo(12 - 0.01));
    }
    expectNoTruncatedText(tester);
  });

  // Measured with the real fonts: Hindi labels are short and Malayalam fits
  // 360 at 1x, so those still show every label; crowding comes from a
  // narrower dock or a larger text scale.
  final crowded = <(String, double, String, double)>[
    ('ml 320', 320, 'ml', 1),
    ('hi 320 x1.3', 320, 'hi', 1.3),
    ('ml 360 x1.3', 360, 'ml', 1.3),
    ('hi 360 x1.3', 360, 'hi', 1.3),
    ('en 390 x1.3', 390, 'en', 1.3),
  ];
  for (final c in crowded) {
    for (final dark in [false, true]) {
      testWidgets('crowded shows only the selected label: ${c.$1} dark=$dark',
          (tester) async {
        final l10n = await pumpDock(tester,
            width: c.$2, lang: c.$3, dark: dark, textScale: c.$4);
        expect(tester.takeException(), isNull);
        expectOnlySelected(l10n);
        final selected = find.text(labelOf(l10n, fiveTabs[1]));
        expect(
            paintedFontSize(tester, selected), greaterThanOrEqualTo(12 - 0.01));
        // Tap targets: equal slots, at least 48px.
        final slots = find.byType(Tooltip).evaluate().length;
        expect(slots, 5);
        for (final e in find.byType(Tooltip).evaluate()) {
          final size = tester.getSize(find.byWidget(e.widget));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        final widths = [
          for (final e in find.byType(Tooltip).evaluate())
            tester.getSize(find.byWidget(e.widget)).width
        ];
        for (final w in widths) {
          expect(w, closeTo(widths.first, 0.01));
        }
        expectNoTruncatedText(tester);
      });
    }
  }

  for (final c in [('ml', 360.0), ('hi', 360.0), ('hi', 320.0)]) {
    testWidgets('${c.$1} at ${c.$2.toInt()} fits, so every label shows',
        (tester) async {
      final l10n = await pumpDock(tester, width: c.$2, lang: c.$1, dark: false);
      expect(tester.takeException(), isNull);
      for (final tab in fiveTabs) {
        expect(find.text(labelOf(l10n, tab)), findsOneWidget);
      }
      expectNoTruncatedText(tester);
    });
  }

  testWidgets('every tab keeps its semantics label and a tooltip',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final l10n = await pumpDock(tester, width: 320, lang: 'ml', dark: false);
    for (final tab in fiveTabs) {
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(tab.semanticLabel))),
          findsOneWidget,
          reason: tab.id);
      expect(find.byTooltip(labelOf(l10n, tab)), findsOneWidget,
          reason: tab.id);
    }
    semantics.dispose();
  });

  testWidgets('dock height is identical in every mode', (tester) async {
    final heights = <double>[];
    for (final c in [
      (390.0, 'en', 1.0),
      (360.0, 'ml', 1.0),
      (320.0, 'hi', 1.0),
      (390.0, 'en', 1.3),
    ]) {
      await pumpDock(tester,
          width: c.$1, lang: c.$2, dark: false, textScale: c.$3);
      heights.add(await dockHeight(tester));
    }
    for (final h in heights) {
      expect(h, closeTo(heights.first, 0.01), reason: '$heights');
    }
  });
}
