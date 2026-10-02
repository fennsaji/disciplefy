import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

void main() {
  setUp(() {
    if (sl.isRegistered<WalkthroughRepository>()) {
      sl.unregister<WalkthroughRepository>();
    }
    sl.registerSingleton<WalkthroughRepository>(_Repo());
  });
  tearDown(() => sl.unregister<WalkthroughRepository>());

  Future<void> frames(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> backGesture(
    WidgetTester tester,
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
  }

  /// Pushes a page running a one-step walkthrough and starts it.
  Future<void> pumpTourPage(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final target = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Text('Previous page')),
    ));
    await tester.pump();
    late BuildContext ctx;
    navigator.currentState!.push(MaterialPageRoute<void>(
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
    ));
    await frames(tester);
    ShowCaseWidget.of(ctx).startShowCase([target]);
    await frames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Title'), findsOneWidget);
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
        'nested navigator tour survives a root route push/pop on $platform',
        (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final root = GlobalKey<NavigatorState>();
        final target = GlobalKey();
        late BuildContext ctx;
        await tester.pumpWidget(MaterialApp(
          navigatorKey: root,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Navigator(
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
        ));
        await frames(tester);
        ShowCaseWidget.of(ctx).startShowCase([target]);
        await frames(tester);
        expect(find.text('Title'), findsOneWidget);
        for (final route in <Route<void>>[
          MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('B'))),
          PageRouteBuilder<void>(
              pageBuilder: (_, __, ___) => const Scaffold(body: Text('C'))),
          MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const Scaffold(body: Text('D'))),
        ]) {
          root.currentState!.push(route);
          await frames(tester, 2);
          expect(tester.takeException(), isNull);
          await frames(tester);
          expect(tester.takeException(), isNull);
          root.currentState!.pop();
          await frames(tester, 2);
          expect(tester.takeException(), isNull);
          await frames(tester);
          expect(tester.takeException(), isNull);
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  // A predictive back swipe re-wraps the page in new transition widgets. The
  // page keeps its state, so the active step's target is moved under render
  // boxes that have not been laid out yet while showcaseview measures it.
  for (final commit in [false, true]) {
    testWidgets(
        'a back swipe ${commit ? 'that pops' : 'that is cancelled'} on a page '
        'with an active walkthrough step does not throw', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpTourPage(tester);

        await backGesture(tester, 'startBackGesture', {
          'touchOffset': [5.0, 300.0],
          'progress': 0.0,
          'swipeEdge': 0,
        });
        await frames(tester, 3);
        expect(tester.takeException(), isNull);

        await backGesture(tester, 'updateBackGestureProgress', {
          'x': 100.0,
          'y': 300.0,
          'progress': 0.35,
          'swipeEdge': 0,
        });
        await frames(tester, 3);
        expect(tester.takeException(), isNull);

        await backGesture(
            tester, commit ? 'commitBackGesture' : 'cancelBackGesture');
        await frames(tester, 10);
        expect(tester.takeException(), isNull);

        if (commit) {
          expect(find.text('Previous page'), findsOneWidget);
          expect(find.text('Title'), findsNothing);
        } else {
          // The step comes back once the page is settled again.
          expect(find.text('Title'), findsOneWidget);
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
