import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/study_topics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mocktail/mocktail.dart' as mocktail;

import 'study_topics_reset_flow_test.mocks.dart';

/// Mocked with `bloc_test`'s [MockBloc]/`mocktail` (not `mockito`) so we can
/// drive its `stream` via `whenListen` — the exact pattern the reset flow's
/// `bloc.stream.firstWhere(...)` await depends on.
class _MockLearningPathsBloc
    extends MockBloc<LearningPathsEvent, LearningPathsState>
    implements LearningPathsBloc {}

class _MockGamificationBloc
    extends MockBloc<GamificationEvent, GamificationState>
    implements GamificationBloc {}

// Short, human-sized stand-ins for the translation keys this flow touches.
// Popup menus and dialogs size themselves to their real (short) copy; an
// identity stub that returns the raw dotted key overflows those fixed-width
// layouts and fails the test for reasons unrelated to the reset flow itself.
const _resetMenuLabel = 'Reset Progress';
const _cancelLabel = 'Cancel';
const _confirmWord = 'RESET';
const _successMessage = 'Reset complete';
const _genericErrorMessage = 'Something went wrong. Please try again.';

/// Tests for the reset-progress flow wired up in `_handleResetProgress`
/// (`study_topics_screen.dart`), covering the menu tap -> confirm dialog ->
/// bloc dispatch -> feedback pipeline.
///
/// `StudyTopicsAppBar` (not the full `StudyTopicsScreen`) is the widget under
/// test: `StudyTopicsScreen` pulls in `SubscriptionRepository`,
/// `SystemConfigService`, `LanguagePreferenceService`, `WalkthroughRepository`
/// and a live `ShowCaseWidget`, none of which this flow touches.
/// `StudyTopicsAppBar` is a public widget in the same file, hosts the 3-dot
/// menu and `_handleResetProgress` directly, and only needs a
/// `LearningPathsBloc` provided above it — so it is the narrowest widget that
/// still exercises the real wiring end to end.
@GenerateMocks([TranslationService])
void main() {
  late MockTranslationService mockTranslationService;
  late _MockLearningPathsBloc learningPathsBloc;
  late _MockGamificationBloc gamificationBloc;

  setUpAll(() {
    // Only the keys this flow actually renders get a short mapped string;
    // everything else falls back to the key's last segment (harmless —
    // nothing in this test looks for it). The reset-success message is a
    // translated key, while the error message asserted in the failure test
    // is the bloc's own raw string, untouched by i18n.
    mockTranslationService = MockTranslationService();
    when(mockTranslationService.getTranslation(any, any)).thenAnswer(
      (invocation) {
        final key = invocation.positionalArguments[0] as String;
        switch (key) {
          case TranslationKeys.studyTopicsContentLanguage:
            return 'Language';
          case TranslationKeys.studyTopicsResetProgress:
            return _resetMenuLabel;
          case TranslationKeys.resetProgressCancel:
            return _cancelLabel;
          case TranslationKeys.resetProgressConfirmWord:
            return _confirmWord;
          case TranslationKeys.studyTopicsResetSuccess:
            return _successMessage;
          case TranslationKeys.resetProgressTypeToConfirm:
            return 'Type {word} to confirm';
          case TranslationKeys.resetProgressErrorGeneric:
            return _genericErrorMessage;
          default:
            // Fall back to the key's last segment rather than the full
            // dotted key: the AppBar renders several other menu items
            // (language, study mode) this test doesn't assert on, and the
            // full key overflows their fixed-width PopupMenuItem rows.
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
    learningPathsBloc = _MockLearningPathsBloc();
    gamificationBloc = _MockGamificationBloc();

    if (sl.isRegistered<GamificationBloc>()) {
      sl.unregister<GamificationBloc>();
    }
    sl.registerLazySingleton<GamificationBloc>(() => gamificationBloc);
  });

  tearDown(() {
    learningPathsBloc.close();
    gamificationBloc.close();
  });

  Future<void> pumpAppBar(WidgetTester tester, {String language = 'en'}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LearningPathsBloc>.value(
          value: learningPathsBloc,
          child: Scaffold(
            appBar: StudyTopicsAppBar(language: language),
          ),
        ),
      ),
    );
  }

  /// Opens the 3-dot menu and taps "Reset Progress", landing on the
  /// confirmation dialog.
  ///
  /// Note: `BlocProvider` subscribes to `bloc.stream` itself (to know when to
  /// rebuild), and it does so the moment the first descendant reads the
  /// bloc — which happens right here, since `_handleResetProgress` calls
  /// `context.read<LearningPathsBloc>()` as soon as the menu item is tapped.
  /// Any state stub fed to `whenListen` as a *finite* stream (e.g.
  /// `Stream.fromIterable`) would already be fully drained by that early
  /// subscriber before the reset flow's own `bloc.stream.firstWhere(...)`
  /// ever subscribes later on confirm — see `stubResetOutcome` below, which
  /// avoids that by only emitting in response to `add()`.
  Future<void> openResetDialog(WidgetTester tester,
      {String language = 'en'}) async {
    await pumpAppBar(tester, language: language);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_resetMenuLabel));
    await tester.pumpAndSettle();
  }

  /// Types the confirm word into the dialog's text field.
  Future<void> typeConfirmWord(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField),
      _confirmWord,
    );
    await tester.pump();
  }

  /// Wires `learningPathsBloc` so that dispatching
  /// `ResetLearningProgressRequested` emits [outcome] on its state stream —
  /// mirroring how the real bloc only produces a new state in reaction to
  /// the event, rather than pre-loading a canned stream that an earlier,
  /// unrelated subscriber (see [openResetDialog]) could drain prematurely.
  void stubResetOutcome(WidgetTester tester, LearningPathsState outcome) {
    final controller = StreamController<LearningPathsState>.broadcast();
    addTearDown(controller.close);

    whenListen<LearningPathsState>(
      learningPathsBloc,
      controller.stream,
      initialState: const LearningPathsInitial(),
    );
    mocktail
        .when(
            () => learningPathsBloc.add(const ResetLearningProgressRequested()))
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
    await tester.tap(
      find.widgetWithText(FilledButton, _resetMenuLabel),
    );
    await tester.pump(); // process the dialog pop and the bloc await chain
    await tester.pump(const Duration(milliseconds: 750)); // snackbar enters
  }

  group('cancelling the reset confirmation', () {
    testWidgets('dispatches nothing when the user taps Cancel', (tester) async {
      await openResetDialog(tester);
      await typeConfirmWord(tester);

      await tester.tap(find.text(_cancelLabel));
      await tester.pumpAndSettle();

      mocktail.verifyNever(() => learningPathsBloc.add(
            const ResetLearningProgressRequested(),
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

      mocktail.verifyNever(() => learningPathsBloc.add(
            const ResetLearningProgressRequested(),
          ));
    });
  });

  group('confirming the reset', () {
    testWidgets(
        'dispatches ResetLearningProgressRequested exactly once, shows '
        'success feedback on LearningPathsResetSuccess, and reloads the list '
        '(and personalized paths) in the real study-content language — not '
        "LoadLearningPaths' 'en' default", (tester) async {
      // A non-default language proves the reload actually threads the real
      // study-content language through, rather than happening to match by
      // coincidence with the 'en' default.
      await openResetDialog(tester, language: 'hi');

      stubResetOutcome(
        tester,
        const LearningPathsResetSuccess(
          result: ResetProgressResult(scope: 'learning_paths', counts: {}),
        ),
      );

      await typeConfirmWord(tester);
      await tapConfirm(tester);

      mocktail
          .verify(() => learningPathsBloc.add(
                const ResetLearningProgressRequested(),
              ))
          .called(1);

      expect(
        find.text(_successMessage),
        findsOneWidget,
      );

      // Finding 3: reload must use 'hi' (the language passed to the AppBar),
      // not the bare `LoadLearningPaths(forceRefresh: true)` which defaults
      // to 'en' and would silently revert a Hindi user's list to English.
      mocktail
          .verify(() => learningPathsBloc.add(
                const LoadLearningPaths(forceRefresh: true, language: 'hi'),
              ))
          .called(1);
      // The For You section's personalized paths are dropped from state by
      // a reload from LearningPathsResetSuccess (not LearningPathsLoaded) —
      // this re-fetch is what makes it recover.
      mocktail
          .verify(() => learningPathsBloc.add(
                const LoadPersonalizedPaths(language: 'hi'),
              ))
          .called(1);
    });
  });

  group('reset failure', () {
    testWidgets(
        'shows a localized error message (not the raw untranslated failure '
        'string) on LearningPathsResetError', (tester) async {
      const failureMessage = 'Could not reach the reset service right now.';

      await openResetDialog(tester);

      stubResetOutcome(
        tester,
        const LearningPathsResetError(
          message: failureMessage,
          code: 'SOME_UNMAPPED_CODE',
        ),
      );

      await typeConfirmWord(tester);
      await tapConfirm(tester);

      // The generic localized message is shown instead of the raw failure
      // string — Finding 4: hi/ml users must never see a hardcoded English
      // string straight from the data layer.
      expect(find.text(_genericErrorMessage), findsOneWidget);
      expect(find.text(failureMessage), findsNothing);
      expect(
        find.text(_successMessage),
        findsNothing,
      );
    });
  });
}
