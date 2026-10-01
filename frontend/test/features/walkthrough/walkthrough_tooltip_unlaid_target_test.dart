import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

class _Repo implements WalkthroughRepository {
  @override
  Future<bool> hasSeen(WalkthroughScreen screen) async => false;
  @override
  Future<void> markSeen(WalkthroughScreen screen) async {}
  @override
  Future<void> resetAll() async {}
  @override
  Future<void> syncFromRemote() async {}
  @override
  Future<void> migrateToRemote() async {}
}

/// Never lays out its child, like a subtree caught before its first layout
/// (e.g. a tab's SlideTransition inserted this frame).
class _NeverLaysOut extends SingleChildRenderObjectWidget {
  const _NeverLaysOut({super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNeverLaysOut();
}

class _RenderNeverLaysOut extends RenderProxyBox {
  @override
  void performLayout() => size = constraints.smallest;
  @override
  void paint(PaintingContext context, Offset offset) {}
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}
}

void main() {
  setUp(() {
    if (sl.isRegistered<WalkthroughRepository>()) {
      sl.unregister<WalkthroughRepository>();
    }
    sl.registerSingleton<WalkthroughRepository>(_Repo());
  });
  tearDown(() => sl.unregister<WalkthroughRepository>());

  testWidgets('a step whose target is not laid out never measures it',
      (tester) async {
    final shown = GlobalKey();
    final hidden = GlobalKey();
    late BuildContext ctx;
    Widget tip(GlobalKey key, int step) => WalkthroughTooltip(
          showcaseKey: key,
          title: 'Title $step',
          description: 'Description',
          screen: WalkthroughScreen.memoryVerses,
          stepNumber: step,
          totalSteps: 2,
          onNext: () => ShowCaseWidget.of(ctx).next(),
          child: const SizedBox(width: 60, height: 50),
        );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShowCaseWidget(
        builder: (context) => Scaffold(
          body: Builder(builder: (c) {
            ctx = c;
            return Column(children: [
              tip(shown, 1),
              _NeverLaysOut(
                child: FractionalTranslation(
                  translation: const Offset(0, 1),
                  child: tip(hidden, 2),
                ),
              ),
            ]);
          }),
        ),
      ),
    ));
    await tester.pump();

    ShowCaseWidget.of(ctx).startShowCase([shown, hidden]);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Title 1'), findsOneWidget);

    // Advance onto the target that is not laid out: no Showcase, no throw.
    ShowCaseWidget.of(ctx).next();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(Showcase), findsNothing);
  });
}
