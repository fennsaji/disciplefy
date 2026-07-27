import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/review_statistics_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/memory_verses_home_page.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mocktail/mocktail.dart' as mocktail;

import 'memory_verses_reset_flow_test.mocks.dart';

/// Mocked with `bloc_test`'s [MockBloc]/`mocktail` (not `mockito`) so we can
/// drive `stream` via `whenListen` — the exact pattern the reset flow's
/// `bloc.stream.firstWhere(...)` await depends on.
class _MockMemoryVerseBloc extends MockBloc<MemoryVerseEvent, MemoryVerseState>
    implements MemoryVerseBloc {}

class _MockGamificationBloc
    extends MockBloc<GamificationEvent, GamificationState>
    implements GamificationBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

// Short, human-sized stand-ins for the translation keys this flow touches.
// Dialogs and buttons size themselves to their real (short) copy; an
// identity stub that returns the raw dotted key overflows those fixed-width
// layouts and fails the test for reasons unrelated to the reset flow itself.
const _resetMenuLabel = 'Reset All Verses';
const _cancelLabel = 'Cancel';
const _confirmWord = 'RESET';
const _confirmLabel = 'Delete All';
const _successMessage = 'All memory verses deleted';
const _genericErrorMessage = 'Something went wrong. Please try again.';

/// Tests for the reset-progress flow wired up in `_handleResetProgress`
/// (`memory_verses_home_page.dart`), covering the 3-dot menu tap -> confirm
/// dialog -> bloc dispatch -> feedback pipeline.
///
/// Unlike the equivalent Study Topics flow, `MemoryVersesHomePage` has no
/// narrow public widget hosting just the app bar (no `MemoryVersesAppBar`
/// equivalent) — `_showOptionsMenu`/`_handleResetProgress` are private
/// methods of `_MemoryVersesHomePageState`, invoked from the 3-dot
/// `IconButton` inside the page's own `build()`. So the full
/// `MemoryVersesHomePage` is pumped here; the deck is stubbed empty so the
/// body renders `_buildEmptyState()` (no verse cards, stats, or streak
/// widgets to wire up).
@GenerateMocks([TranslationService, WalkthroughRepository])
void main() {
  late MockTranslationService mockTranslationService;
  late MockWalkthroughRepository mockWalkthroughRepository;
  late _MockMemoryVerseBloc memoryVerseBloc;
  late _MockGamificationBloc gamificationBloc;
  late _MockConnectivityBloc connectivityBloc;

  setUpAll(() {
    // Only the keys this flow actually renders/taps get a short mapped
    // string; everything else falls back to the key's last segment.
    mockTranslationService = MockTranslationService();
    when(mockTranslationService.getTranslation(any, any)).thenAnswer(
      (invocation) {
        final key = invocation.positionalArguments[0] as String;
        switch (key) {
          case TranslationKeys.optionsMenuResetTitle:
            return _resetMenuLabel;
          case TranslationKeys.resetProgressCancel:
            return _cancelLabel;
          case TranslationKeys.resetProgressConfirmWord:
            return _confirmWord;
          case TranslationKeys.memoryResetConfirm:
            return _confirmLabel;
          case TranslationKeys.memoryResetSuccess:
            return _successMessage;
          case TranslationKeys.resetProgressTypeToConfirm:
            return 'Type {word} to confirm';
          case TranslationKeys.resetProgressErrorGeneric:
            return _genericErrorMessage;
          default:
            return key.split('.').last;
        }
      },
    );
    sl.registerLazySingleton<TranslationService>(() => mockTranslationService);
  });

  tearDownAll(() {
    sl.reset();
  });

  setUp(() {
    memoryVerseBloc = _MockMemoryVerseBloc();
    gamificationBloc = _MockGamificationBloc();
    connectivityBloc = _MockConnectivityBloc();
    mockWalkthroughRepository = MockWalkthroughRepository();

    when(mockWalkthroughRepository.hasSeen(any)).thenAnswer((_) async => true);

    if (sl.isRegistered<GamificationBloc>()) {
      sl.unregister<GamificationBloc>();
    }
    sl.registerLazySingleton<GamificationBloc>(() => gamificationBloc);

    if (sl.isRegistered<WalkthroughRepository>()) {
      sl.unregister<WalkthroughRepository>();
    }
    sl.registerLazySingleton<WalkthroughRepository>(
        () => mockWalkthroughRepository);

    // Empty deck — the cheapest state to render: `_buildLoadedState` checks
    // `statistics.totalVerses == 0` and returns `_buildEmptyState()`,
    // skipping verse cards, the streak strip, and daily-goal widgets that
    // this flow doesn't touch.
    const emptyState = DueVersesLoaded(
      verses: [],
      statistics: ReviewStatisticsEntity(
        totalVerses: 0,
        dueVerses: 0,
        reviewedToday: 0,
        upcomingReviews: 0,
        masteredVerses: 0,
        fullyMasteredVerses: 0,
      ),
    );
    whenListen<MemoryVerseState>(
      memoryVerseBloc,
      Stream<MemoryVerseState>.empty(),
      initialState: emptyState,
    );

    // Online — deliberately NOT disarming the page's pre-existing
    // `MemoryVerseError` catch-all listener (a page-wide handler that shows
    // a generic "Something went wrong" snackbar for ANY error on this bloc,
    // guarded by `if (!isOffline)`). The reset flow now emits its own
    // `MemoryProgressResetError` state instead of `MemoryVerseError` on
    // failure, so that catch-all no longer matches reset failures at all —
    // running online here is what actually proves the collision is gone at
    // the source, rather than merely disarmed in this test's setup.
    whenListen<ConnectivityState>(
      connectivityBloc,
      Stream<ConnectivityState>.empty(),
      initialState: ConnectivityOnline(),
    );
  });

  tearDown(() {
    memoryVerseBloc.close();
    gamificationBloc.close();
    connectivityBloc.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<MemoryVerseBloc>.value(value: memoryVerseBloc),
          BlocProvider<ConnectivityBloc>.value(value: connectivityBloc),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MemoryVersesHomePage(),
        ),
      ),
    );
    await tester.pump();
  }

  /// Opens the 3-dot options menu and taps "Reset All Verses", landing on
  /// the confirmation dialog.
  ///
  /// Note: `BlocProvider`/`BlocConsumer` subscribe to `bloc.stream`
  /// themselves as soon as the page mounts here. Any state stub fed to
  /// `whenListen` as a *finite* single-subscription stream is only
  /// listenable once — see `stubResetOutcome` below, which swaps in a fresh
  /// broadcast stream on confirm so the reset flow's own later
  /// `bloc.stream.firstWhere(...)` subscription can still observe it.
  Future<void> openResetDialog(WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_resetMenuLabel));
    await tester.pumpAndSettle();
  }

  /// Types the confirm word into the dialog's text field.
  Future<void> typeConfirmWord(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), _confirmWord);
    await tester.pump();
  }

  /// Wires `memoryVerseBloc` so that dispatching
  /// `ResetMemoryProgressRequested` emits [outcome] on its state stream —
  /// mirroring how the real bloc only produces a new state in reaction to
  /// the event, rather than pre-loading a canned stream that an earlier,
  /// unrelated subscriber (see [openResetDialog]) could drain prematurely.
  void stubResetOutcome(WidgetTester tester, MemoryVerseState outcome) {
    final controller = StreamController<MemoryVerseState>.broadcast();
    addTearDown(controller.close);

    whenListen<MemoryVerseState>(
      memoryVerseBloc,
      controller.stream,
      initialState: memoryVerseBloc.state,
    );
    mocktail
        .when(() => memoryVerseBloc.add(const ResetMemoryProgressRequested()))
        .thenAnswer((_) => controller.add(outcome));
  }

  /// Taps the dialog's (destructive) confirm button and pumps just enough to
  /// let the dialog pop and the ensuing bloc-await/snackbar chain resolve.
  ///
  /// Deliberately does NOT use `pumpAndSettle`: a `SnackBar` auto-dismisses
  /// after its default 4s duration, and `pumpAndSettle` keeps pumping until
  /// every animation and timer is done — which would pump straight through
  /// the snackbar's full lifetime and leave it already gone by the time this
  /// helper returns, before the test ever gets to assert on it.
  Future<void> tapConfirm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, _confirmLabel));
    await tester.pump(); // process the dialog pop and the bloc await chain
    await tester.pump(const Duration(milliseconds: 750)); // snackbar enters
  }

  group('cancelling the reset confirmation', () {
    testWidgets('dispatches nothing when the user taps Cancel', (tester) async {
      await openResetDialog(tester);
      await typeConfirmWord(tester);

      await tester.tap(find.text(_cancelLabel));
      await tester.pumpAndSettle();

      mocktail.verifyNever(() => memoryVerseBloc.add(
            const ResetMemoryProgressRequested(),
          ));
    });

    testWidgets('dispatches nothing when the user dismisses via the barrier',
        (tester) async {
      await openResetDialog(tester);
      await typeConfirmWord(tester);

      // Tap the barrier away from its center so the dialog itself (centered
      // on the same point) does not absorb the tap.
      final barrier = find.byType(ModalBarrier).last;
      await tester.tapAt(tester.getTopLeft(barrier) + const Offset(5, 5));
      await tester.pumpAndSettle();

      mocktail.verifyNever(() => memoryVerseBloc.add(
            const ResetMemoryProgressRequested(),
          ));
    });
  });

  group('confirming the reset', () {
    testWidgets(
        'dispatches ResetMemoryProgressRequested exactly once and shows '
        'success feedback on MemoryProgressResetSuccess', (tester) async {
      await openResetDialog(tester);

      stubResetOutcome(
        tester,
        const MemoryProgressResetSuccess(
          result: ResetProgressResult(scope: 'memory_verses', counts: {}),
        ),
      );

      await typeConfirmWord(tester);
      await tapConfirm(tester);

      mocktail
          .verify(() => memoryVerseBloc.add(
                const ResetMemoryProgressRequested(),
              ))
          .called(1);

      expect(
        find.text(_successMessage),
        findsOneWidget,
      );
    });
  });

  group('reset failure', () {
    testWidgets(
        'shows a localized error message (not the raw untranslated failure '
        'string) on MemoryProgressResetError', (tester) async {
      const failureMessage = 'Could not reach the reset service right now.';

      await openResetDialog(tester);

      stubResetOutcome(
        tester,
        const MemoryProgressResetError(
          message: failureMessage,
          code: 'RESET_FAILED',
        ),
      );

      await typeConfirmWord(tester);
      await tapConfirm(tester);

      // The generic localized message is shown instead of the raw failure
      // string — hi/ml users must never see a hardcoded English string
      // straight from the data layer.
      expect(find.text(_genericErrorMessage), findsOneWidget);
      expect(find.text(failureMessage), findsNothing);
      expect(
        find.text(_successMessage),
        findsNothing,
      );
    });

    testWidgets(
        'an unrelated MemoryVerseError racing in mid-reset does not resolve '
        'the reset outcome', (tester) async {
      // Simulates the user tapping a verse to review/delete while the reset
      // round-trip is still outstanding: that unrelated operation's own
      // `MemoryVerseError` lands on the same bloc stream first, followed by
      // the reset's real (successful) outcome. The reset flow's
      // `bloc.stream.firstWhere` must skip the unrelated error and resolve
      // on the reset's own state — not report the unrelated failure as the
      // reset's result.
      const unrelatedErrorMessage = 'Failed to delete verse';

      await openResetDialog(tester);

      final controller = StreamController<MemoryVerseState>.broadcast();
      addTearDown(controller.close);
      whenListen<MemoryVerseState>(
        memoryVerseBloc,
        controller.stream,
        initialState: memoryVerseBloc.state,
      );
      mocktail
          .when(() => memoryVerseBloc.add(const ResetMemoryProgressRequested()))
          .thenAnswer((_) {
        controller.add(const MemoryVerseError(
          message: unrelatedErrorMessage,
          code: 'DELETE_FAILED',
        ));
        controller.add(const MemoryProgressResetSuccess(
          result: ResetProgressResult(scope: 'memory_verses', counts: {}),
        ));
      });

      await typeConfirmWord(tester);
      await tapConfirm(tester);

      // The reset's own success snackbar reflects the real outcome...
      expect(find.text(_successMessage), findsOneWidget);
      // ...and the unrelated error is never reported as the reset's result
      // (it may still surface via the page's own generic catch-all listener,
      // which is not what this assertion is about).
      expect(find.text(unrelatedErrorMessage), findsNothing);
    });
  });
}
