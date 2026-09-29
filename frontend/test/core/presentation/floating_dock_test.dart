import 'dart:io';

import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/presentation/widgets/app_shell.dart';
import 'package:disciplefy_bible_study/core/presentation/widgets/bottom_nav.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

/// The floating dock: five labelled destinations, selection shown lightly
/// (gold pill + gold label), Discipler a fixed gold button that only gains a
/// ring when it is the selected tab.
void main() {
  setUpAll(() async {
    // Real fonts so the "labels never cut" checks measure real widths.
    final loader = FontLoader('Inter');
    for (final f in ['Regular', 'Medium', 'SemiBold']) {
      final bytes = File('assets/fonts/Inter-$f.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  final fiveTabs = [
    DisciplefyBottomNav.defaultTabs[0],
    DisciplefyBottomNav.defaultTabs[1],
    DisciplefyBottomNav.disciplerTab,
    DisciplefyBottomNav.defaultTabs[2],
    DisciplefyBottomNav.defaultTabs[3],
  ];

  Future<List<int>> pump(
    WidgetTester tester, {
    required int selected,
    List<NavTab>? tabs,
    ThemeData? theme,
    Locale locale = const Locale('en'),
    double width = 390,
  }) async {
    final taps = <int>[];
    tester.view.physicalSize = Size(width, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShowCaseWidget(
        builder: (_) => Scaffold(
          bottomNavigationBar: DisciplefyBottomNav(
            currentIndex: selected,
            tabs: tabs ?? fiveTabs,
            onTap: taps.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return taps;
  }

  Color labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color ??
      DefaultTextStyle.of(tester.element(find.text(label))).style.color!;

  bool ringVisible(WidgetTester tester) {
    final box = tester
        .widget<AnimatedContainer>(find.byKey(const Key('nav_discipler_ring')));
    final border = (box.decoration! as BoxDecoration).border! as Border;
    return border.top.color != Colors.transparent;
  }

  testWidgets('five labelled destinations with Discipler in the middle',
      (tester) async {
    await pump(tester, selected: 0);
    final xs = [
      for (final l in ['Home', 'Generate', 'Discipler', 'Topics', 'Community'])
        tester.getCenter(find.text(l)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    // Labels share one baseline even though the Discipler button is taller.
    final ys = [
      for (final l in ['Home', 'Discipler', 'Community'])
        tester.getBottomLeft(find.text(l)).dy,
    ];
    expect(ys.toSet().length, 1);
  });

  testWidgets('icons and button share one centre line, centred in the dock',
      (tester) async {
    await pump(tester, selected: 0);
    final iconYs = [
      for (final icon in [Icons.home, Icons.auto_awesome_outlined])
        tester.getCenter(find.byIcon(icon)).dy,
      tester.getCenter(find.byKey(const Key('nav_discipler_ring'))).dy,
    ];
    for (final y in iconYs) {
      expect((y - iconYs.first).abs(), lessThan(0.5));
    }

    // The item row is centred vertically inside the dock.
    final dock = tester.getRect(find
        .ancestor(
            of: find.byType(Row).last,
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).borderRadius != null))
        .first);
    final homeLabel = tester.getRect(find.text('Home'));
    final ring = tester.getRect(find.byKey(const Key('nav_discipler_ring')));
    final above = ring.top - dock.top;
    final below = dock.bottom - homeLabel.bottom;
    expect((above - below).abs(), lessThan(4),
        reason: 'above $above vs below $below');
  });

  testWidgets('a regular tab selected: gold label, Discipler has no ring',
      (tester) async {
    await pump(tester, selected: 3); // Topics
    expect(labelColor(tester, 'Topics'), AppColors.brandGold);
    expect(labelColor(tester, 'Home'), isNot(AppColors.brandGold));
    expect(ringVisible(tester), isFalse);
  });

  testWidgets('Discipler selected: ring and gold label, no tab pill',
      (tester) async {
    await pump(tester, selected: 2);
    expect(ringVisible(tester), isTrue);
    expect(labelColor(tester, 'Discipler'), AppColors.brandGold);
    for (final l in ['Home', 'Generate', 'Topics', 'Community']) {
      expect(labelColor(tester, l), isNot(AppColors.brandGold), reason: l);
    }
  });

  testWidgets('light theme uses the deep gold for the selected tab',
      (tester) async {
    await pump(tester, selected: 0, theme: AppTheme.lightTheme);
    expect(labelColor(tester, 'Home'), AppColors.brandGoldDeep);
  });

  testWidgets('taps report the visible tab index, Discipler included',
      (tester) async {
    final taps = await pump(tester, selected: 0);
    await tester.tap(find.text('Discipler'));
    await tester.tap(find.text('Community'));
    await tester.tap(find.text('Home')); // re-tap is reported too
    expect(taps, [2, 4, 0]);
  });

  testWidgets('works without the Discipler tab (feature hidden)',
      (tester) async {
    await pump(tester, selected: 1, tabs: DisciplefyBottomNav.defaultTabs);
    expect(find.text('Discipler'), findsNothing);
    expect(labelColor(tester, 'Generate'), AppColors.brandGold);
  });

  testWidgets("a tab's floating button stays above the floating dock",
      (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const dockKey = Key('dock');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        extendBody: true,
        bottomNavigationBar: const SizedBox(key: dockKey, height: 100),
        body: ClearOfFloatingDock(
          child: Scaffold(
            body: const SizedBox.expand(),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              label: const Text('Join a Fellowship'),
            ),
          ),
        ),
      ),
    ));
    final fabBottom = tester.getRect(find.byType(FloatingActionButton)).bottom;
    final dockTop = tester.getRect(find.byKey(dockKey)).top;
    expect(fabBottom, lessThanOrEqualTo(dockTop));
  });

  for (final (name, theme) in [
    ('dark', AppTheme.darkTheme),
    ('light', AppTheme.lightTheme),
  ]) {
    for (final code in ['en', 'hi', 'ml']) {
      testWidgets('$name/$code at 320px: fits, no label cut', (tester) async {
        await pump(tester,
            selected: 4, theme: theme, locale: Locale(code), width: 320);
        expect(tester.takeException(), isNull);
        for (final p in tester
            .renderObjectList<RenderParagraph>(find.byType(RichText))) {
          expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
        }
      });
    }
  }
}
