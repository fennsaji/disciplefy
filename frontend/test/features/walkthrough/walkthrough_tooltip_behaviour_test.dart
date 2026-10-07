import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/presentation/widgets/bottom_nav.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../helpers/text_fit.dart';

class _FakeWalkthroughRepository implements WalkthroughRepository {
  final seen = <WalkthroughScreen>{};

  @override
  Future<bool> hasSeen(WalkthroughScreen screen) async => seen.contains(screen);

  @override
  Future<void> markSeen(WalkthroughScreen screen) async => seen.add(screen);

  @override
  Future<void> resetAll() async => seen.clear();

  @override
  Future<void> syncFromRemote() async {}

  @override
  Future<void> migrateToRemote() async {}
}

/// Behaviour of the walkthrough coach mark: it always stays on screen,
/// points at its target, and "Skip" ends the page's tour and marks it seen.
void main() {
  setUpAll(loadAppFonts);

  late _FakeWalkthroughRepository repo;
  setUp(() {
    repo = _FakeWalkthroughRepository();
    if (sl.isRegistered<WalkthroughRepository>()) {
      sl.unregister<WalkthroughRepository>();
    }
    sl.registerSingleton<WalkthroughRepository>(repo);
  });
  tearDown(() => sl.unregister<WalkthroughRepository>());

  const screenSize = Size(320, 640);
  const safeTop = 40.0;
  const safeBottom = 30.0;

  /// Pumps two tooltips on [screen] around targets placed by [alignment]
  /// and starts the tour. Returns the context below the ShowCaseWidget.
  Future<BuildContext> pumpTour(
    WidgetTester tester, {
    required Alignment alignment,
    TooltipPosition position = TooltipPosition.top,
    Locale locale = const Locale('en'),
    bool dark = false,
    WalkthroughScreen screen = WalkthroughScreen.memoryVerses,
    String description = 'Pick how you want to practise this verse today',
  }) async {
    final first = GlobalKey();
    final second = GlobalKey();
    late BuildContext showcaseContext;
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1;
    tester.view.padding =
        const FakeViewPadding(top: safeTop, bottom: safeBottom);
    tester.view.viewPadding =
        const FakeViewPadding(top: safeTop, bottom: safeBottom);
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
              alignment: alignment,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final key in [first, second])
                    WalkthroughTooltip(
                      showcaseKey: key,
                      title: 'Choose practice mode',
                      description: description,
                      screen: screen,
                      stepNumber: key == first ? 1 : 2,
                      totalSteps: 2,
                      tooltipPosition: position,
                      onNext: () => ShowCaseWidget.of(ctx).next(),
                      child: const SizedBox(width: 60, height: 50),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    ));
    await tester.pump();
    ShowCaseWidget.of(showcaseContext).startShowCase([first, second]);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    // The Showcase mounts once its target is measured laid out, a frame
    // after the step starts; its overlay follows a frame later.
    await tester.pump(const Duration(milliseconds: 500));
    return showcaseContext;
  }

  Rect bubbleRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const Key('walkthrough_tooltip_bubble')));

  void expectInsideSafeArea(Rect bubble) {
    expect(bubble.top, greaterThanOrEqualTo(safeTop));
    expect(bubble.bottom, lessThanOrEqualTo(screenSize.height - safeBottom));
    expect(bubble.left, greaterThanOrEqualTo(0));
    expect(bubble.right, lessThanOrEqualTo(screenSize.width));
  }

  testWidgets('a target at the top asking for "above" gets the bubble below',
      (tester) async {
    await pumpTour(tester, alignment: const Alignment(0, -0.9));
    final bubble = bubbleRect(tester);
    expectInsideSafeArea(bubble);
    expect(find.text('Choose practice mode'), findsOneWidget);
    final target = tester.getRect(find.byType(Row).last);
    expect(bubble.top, greaterThanOrEqualTo(target.bottom));
  });

  testWidgets('a target at the bottom asking for "below" gets it above',
      (tester) async {
    await pumpTour(tester,
        alignment: const Alignment(1, 0.95), position: TooltipPosition.bottom);
    final bubble = bubbleRect(tester);
    expectInsideSafeArea(bubble);
    final target = tester.getRect(find.byType(Row).last);
    expect(bubble.bottom, lessThanOrEqualTo(target.top));
  });

  testWidgets('the arrow points at the target centre', (tester) async {
    await pumpTour(tester, alignment: const Alignment(1, 0.6));
    final arrow = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.size == const Size(20, 10));
    final visible = tester
        .widgetList(arrow)
        .map((w) => tester.getCenter(find.byWidget(w)))
        .where((c) => c.dx >= 0 && c.dy >= 0)
        .toList();
    expect(visible, hasLength(1));
    // First target is the left box of the right-aligned pair.
    expect(visible.single.dx, closeTo(screenSize.width - 120 + 30, 1));
  });

  testWidgets('Skip ends the tour and marks the page seen', (tester) async {
    final ctx = await pumpTour(tester, alignment: Alignment.center);
    await tester.tap(find.byKey(const Key('walkthrough_skip')));
    await tester.pump();
    await tester.pump();
    expect(repo.seen, {WalkthroughScreen.memoryVerses});
    expect(find.byKey(const Key('walkthrough_tooltip_bubble')), findsNothing);
    expect(ShowCaseWidget.activeTargetWidget(ctx), isNull);
  });

  testWidgets('Got it advances without marking seen', (tester) async {
    await pumpTour(tester, alignment: Alignment.center);
    await tester.tap(find.text('Got it →'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2 / 2'), findsOneWidget);
    expect(repo.seen, isEmpty);
  });

  for (final dark in [false, true]) {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('ml')]) {
      testWidgets(
          '320px ${dark ? 'dark' : 'light'} ${locale.languageCode}: '
          'all buttons fit uncut', (tester) async {
        final ctx = await pumpTour(tester,
            alignment: const Alignment(0, 0.7),
            locale: locale,
            dark: dark,
            screen: WalkthroughScreen.home);
        expect(tester.takeException(), isNull);
        final l10n = AppLocalizations.of(ctx)!;
        for (final label in [
          l10n.walkthroughGotIt,
          l10n.walkthroughWatchVideo,
          l10n.walkthroughSkip,
        ]) {
          final r = tester.getRect(find.text(label));
          expect(bubbleRect(tester).contains(r.topLeft), isTrue);
          expect(bubbleRect(tester).contains(r.bottomRight), isTrue);
        }
        expectInsideSafeArea(bubbleRect(tester));
        expectNoTruncatedText(tester);
      });
    }
  }

  testWidgets('home tour includes the Discipler tab with the right count',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext showcaseContext;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ShowCaseWidget(
        builder: (ctx) {
          showcaseContext = ctx;
          return Scaffold(
            bottomNavigationBar: DisciplefyBottomNav(
              currentIndex: 0,
              tabs: [
                DisciplefyBottomNav.defaultTabs[0],
                DisciplefyBottomNav.defaultTabs[1],
                DisciplefyBottomNav.disciplerTab,
                DisciplefyBottomNav.defaultTabs[2],
                DisciplefyBottomNav.defaultTabs[3],
              ],
              onTap: (_) {},
            ),
          );
        },
      ),
    ));
    await tester.pump();
    // Two body steps (the verse and the Memory Verses pill) before the dock.
    ShowcaseKeys.beginHomeTour([GlobalKey(), GlobalKey()]);
    addTearDown(() => ShowcaseKeys.beginHomeTour(const []));
    final navKeys = ShowcaseKeys.homeNavTabKeys;
    expect(navKeys.indexOf(ShowcaseKeys.homeDisciplerTab), 1);
    ShowCaseWidget.of(showcaseContext).startShowCase(navKeys);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('3 / 6'), findsOneWidget);
    await tester.tap(find.text('Got it →'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Talk to Discipler'), findsOneWidget);
    expect(find.text('Ask questions about the Bible by voice or text'),
        findsOneWidget);
    expect(find.text('4 / 6'), findsOneWidget);
  });
}
