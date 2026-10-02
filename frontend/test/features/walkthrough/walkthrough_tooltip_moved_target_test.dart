import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:flutter/material.dart';
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

/// Moves [child] (keeping its state) under a new [SlideTransition] when
/// [wrapped] flips, the way a route transition re-wraps a page.
class _Mover extends StatefulWidget {
  const _Mover({super.key, required this.child});
  final Widget child;
  @override
  State<_Mover> createState() => _MoverState();
}

class _MoverState extends State<_Mover> {
  final GlobalKey _subtree = GlobalKey();
  bool wrapped = false;
  void toggle() => setState(() => wrapped = !wrapped);

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _subtree, child: widget.child);
    if (!wrapped) return child;
    return SlideTransition(
      position: const AlwaysStoppedAnimation(Offset.zero),
      child: child,
    );
  }
}

void main() {
  setUp(() {
    if (sl.isRegistered<WalkthroughRepository>()) {
      sl.unregister<WalkthroughRepository>();
    }
    sl.registerSingleton<WalkthroughRepository>(_Repo());
  });
  tearDown(() => sl.unregister<WalkthroughRepository>());

  testWidgets(
      'a moved page with an active step never measures a target '
      'that is not laid out', (tester) async {
    final mover = GlobalKey<_MoverState>();
    final target = GlobalKey();
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _Mover(
        key: mover,
        // A nested navigator, like a tab branch: its overlay holds the
        // showcase and moves together with the target.
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ShowCaseWidget(
              builder: (_) => Scaffold(
                body: Center(
                  child: Builder(builder: (c) {
                    ctx = c;
                    return WalkthroughTooltip(
                      showcaseKey: target,
                      title: 'Title',
                      description: 'Description',
                      screen: WalkthroughScreen.memoryVerses,
                      stepNumber: 1,
                      totalSteps: 1,
                      onNext: () => ShowCaseWidget.of(c).next(),
                      child: const SizedBox(width: 60, height: 50),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    ShowCaseWidget.of(ctx).startShowCase([target]);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Title'), findsOneWidget);

    for (var round = 0; round < 2; round++) {
      mover.currentState!.toggle();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final e = tester.takeException();
        if (e != null) {
          debugPrint('DBG $e');
          debugPrint(
              'DBG ${(e as Error).stackTrace.toString().split('\n').take(25).join('\n')}');
        }
        expect(e, isNull);
      }
      expect(find.text('Title'), findsOneWidget);
    }
  });
}
