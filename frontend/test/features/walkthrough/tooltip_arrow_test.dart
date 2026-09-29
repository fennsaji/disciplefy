import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

/// The Community step asks for a right-aligned arrow so it points at the
/// rightmost tab. The arrow sat in a shrink-wrapped column, so the alignment
/// was ignored and the arrow always pointed at the middle of the bubble.
void main() {
  Future<double> arrowOffsetFromBubbleCentre(
      WidgetTester tester, Alignment alignment) async {
    final key = GlobalKey();
    late BuildContext showcaseContext;
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShowCaseWidget(
        builder: (context) => Scaffold(
          body: Builder(builder: (ctx) {
            showcaseContext = ctx;
            return Align(
              alignment: Alignment.bottomRight,
              child: WalkthroughTooltip(
                showcaseKey: key,
                title: 'Community',
                description: 'Join fellowships',
                screen: WalkthroughScreen.home,
                stepNumber: 5,
                totalSteps: 5,
                onNext: () {},
                arrowAlignment: alignment,
                child: const SizedBox(width: 60, height: 50),
              ),
            );
          }),
        ),
      ),
    ));
    await tester.pump(); // ShowCaseWidget builds its child after a frame
    ShowCaseWidget.of(showcaseContext).startShowCase([key]);
    // The showcase pulses forever, so settle for a fixed time instead.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final arrow = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.size == const Size(20, 10));
    expect(arrow, findsOneWidget);
    final bubble =
        find.ancestor(of: arrow, matching: find.byType(Column)).first;
    return tester.getCenter(arrow).dx - tester.getCenter(bubble).dx;
  }

  testWidgets('a right-aligned arrow sits right of the bubble centre',
      (tester) async {
    final offset =
        await arrowOffsetFromBubbleCentre(tester, const Alignment(0.8, 0));
    expect(offset, greaterThan(60));
  });

  testWidgets('the default arrow stays centred', (tester) async {
    final offset = await arrowOffsetFromBubbleCentre(tester, Alignment.center);
    expect(offset.abs(), lessThan(1));
  });
}
