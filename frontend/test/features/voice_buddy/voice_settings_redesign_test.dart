import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/pricing_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/domain/entities/voice_preferences_entity.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_preferences_bloc.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_preferences_event.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/bloc/voice_preferences_state.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/pages/voice_preferences_page.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/pages/voice_preferences_page_wrapper.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/language_selector.dart';
import 'package:disciplefy_bible_study/features/voice_buddy/presentation/widgets/monthly_limit_exceeded_dialog.dart';

import '../../helpers/welcome_test_harness.dart';
import '../settings/text_fit.dart';

class _MockPrefsBloc
    extends MockBloc<VoicePreferencesEvent, VoicePreferencesState>
    implements VoicePreferencesBloc {}

class _FakePricing extends Fake implements PricingService {
  @override
  String getVoiceQuotaLabel(String planCode) => '10 conversations/month';

  @override
  String getFormattedPricePerMonth(String planCode, {String? provider}) =>
      '₹99/month';
}

const _prefs = VoicePreferencesEntity(userId: 'u1', continuousMode: false);

void main() {
  late FakeTranslationService translations;

  setUpAll(() => registerFallbackValue(const LoadVoicePreferences()));

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<PricingService>(_FakePricing());
  });

  tearDown(() async => sl.reset());

  /// Home screen with an "open" button that pushes [page], so the page can
  /// be popped.
  Widget app(Widget page, {required bool dark}) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => page)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/pricing',
          builder: (_, state) =>
              Scaffold(body: Text('stub:pricing:${state.extra}')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  Future<void> open(WidgetTester tester, Widget page,
      {bool dark = true, bool settle = true}) async {
    await tester.pumpWidget(app(page, dark: dark));
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Scrolls the settings list top to bottom, checking text at every stop.
  Future<void> scrollThroughChecking(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      expectNoTruncatedText(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
    }
    expectNoTruncatedText(tester);
  }

  group('VoicePreferencesPage', () {
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets(
            '${language.code} ${dark ? 'dark' : 'light'}: fits 320x640 with every setting',
            (tester) async {
          translations.language = language;
          useSurface(tester, const Size(320, 640));
          await open(
              tester, const VoicePreferencesPage(initialPreferences: _prefs),
              dark: dark);
          await scrollThroughChecking(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('shows every section, incl. study memory', (tester) async {
      useSurface(tester, const Size(390, 3000));
      await open(
          tester, const VoicePreferencesPage(initialPreferences: _prefs));

      for (final text in [
        'Voice Settings',
        'LANGUAGE',
        'Preferred language',
        'Default',
        'Auto-detect language',
        'VOICE OUTPUT',
        'Female',
        'Male',
        'Speaking Rate',
        'Pitch',
        'INTERACTION',
        'Auto-play responses',
        'Show transcription',
        'Continuous mode',
        'STUDY MEMORY',
        'Use study context',
        'Cite Scripture references',
        'NOTIFICATIONS',
        'Quota alerts',
        'Reset to Defaults',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      // No Save until something changes.
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('edits reach onSave from the top-bar Save', (tester) async {
      useSurface(tester, const Size(390, 3000));
      VoicePreferencesEntity? saved;
      await open(
        tester,
        VoicePreferencesPage(
          initialPreferences: _prefs,
          onSave: (p) => saved = p,
        ),
      );

      await tester.tap(find.text('Use study context'));
      await tester.tap(find.text('Cite Scripture references'));
      await tester.tap(find.text('Continuous mode'));
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.useStudyContext, isFalse);
      expect(saved!.citeScriptureReferences, isFalse);
      expect(saved!.continuousMode, isTrue);
      expect(saved!.ttsVoiceGender, VoiceGender.male);
    });

    testWidgets('language row opens the sheet and applies the choice',
        (tester) async {
      useSurface(tester, const Size(390, 3000));
      VoicePreferencesEntity? saved;
      await open(
        tester,
        VoicePreferencesPage(
          initialPreferences: _prefs,
          onSave: (p) => saved = p,
        ),
      );

      await tester.tap(find.text('Preferred language'));
      await tester.pumpAndSettle();
      expect(find.text('Speak with Discipler in'), findsOneWidget);
      expect(find.text('Uses your app language (English)'), findsOneWidget);
      expect(find.byType(VoiceLanguageOptionCard), findsNWidgets(4));

      await tester.tap(find.text('Malayalam'));
      await tester.pumpAndSettle();
      expect(find.text('Speak with Discipler in'), findsNothing);
      expect(find.text(VoiceLanguage.malayalam.displayName), findsOneWidget);

      await tester.tap(find.text('Save'));
      expect(saved!.preferredLanguage, 'ml-IN');
    });

    testWidgets(
        'slider values sit at the right edge; tracks span the content width',
        (tester) async {
      useSurface(tester, const Size(390, 3000));
      await open(
          tester, const VoicePreferencesPage(initialPreferences: _prefs));

      final sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(2));
      final rows = {'Speaking Rate': 'Slow', 'Pitch': 'Normal'};
      var i = 0;
      for (final MapEntry(key: title, value: label) in rows.entries) {
        final slider = sliders.at(i++);
        final titleRect = tester.getRect(find.text(title));
        final valueRect = tester.getRect(find.text(label));
        final sliderRect = tester.getRect(slider);
        // Value flush with the row's right edge, title with its left.
        expect(valueRect.right, moreOrLessEquals(sliderRect.right),
            reason: '$title value');
        expect(titleRect.left, moreOrLessEquals(sliderRect.left),
            reason: '$title title');
        // Same line as the title, not in the middle of the row.
        expect(valueRect.left, greaterThan(sliderRect.center.dx));
        // No default side inset, so the track lines up with the title.
        expect(tester.widget<Slider>(slider).padding?.horizontal, 0);
      }
    });

    testWidgets('reset confirm restores defaults', (tester) async {
      useSurface(tester, const Size(390, 3000));
      VoicePreferencesEntity? saved;
      await open(
        tester,
        VoicePreferencesPage(
          initialPreferences: _prefs.copyWith(speakingRate: 1.8),
          onSave: (p) => saved = p,
        ),
      );

      await tester.tap(find.text('Reset to Defaults'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Settings?'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Settings?'), findsNothing);

      await tester.tap(find.text('Save'));
      expect(saved, VoicePreferencesEntity.defaults('u1'));
    });

    testWidgets('reset cancel keeps settings', (tester) async {
      useSurface(tester, const Size(390, 3000));
      await open(
          tester, const VoicePreferencesPage(initialPreferences: _prefs));
      await tester.tap(find.text('Reset to Defaults'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsNothing);
    });

    group('unsaved changes', () {
      Future<void> editThenBack(WidgetTester tester,
          {void Function(VoicePreferencesEntity)? onSave}) async {
        useSurface(tester, const Size(390, 3000));
        await open(
          tester,
          VoicePreferencesPage(initialPreferences: _prefs, onSave: onSave),
        );
        await tester.tap(find.text('Quota alerts'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Unsaved Changes'), findsOneWidget);
      }

      testWidgets('Discard leaves the page', (tester) async {
        await editThenBack(tester);
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget);
        expect(find.byType(VoicePreferencesPage), findsNothing);
      });

      testWidgets('Cancel stays on the page', (tester) async {
        await editThenBack(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(VoicePreferencesPage), findsOneWidget);
      });

      testWidgets('Save hands the edits to onSave and stays', (tester) async {
        VoicePreferencesEntity? saved;
        await editThenBack(tester, onSave: (p) => saved = p);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(saved!.notifyDailyQuotaReached, isFalse);
        expect(find.byType(VoicePreferencesPage), findsOneWidget);
      });

      for (final language in AppLanguage.values) {
        testWidgets('${language.code}: dialog fits 320x640', (tester) async {
          translations.language = language;
          useSurface(tester, const Size(320, 640));
          await open(
              tester, const VoicePreferencesPage(initialPreferences: _prefs));
          await tester.tap(find.byType(Switch).first);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expectNoTruncatedText(tester);
          expect(tester.takeException(), isNull);
        });
      }
    });
  });

  group('VoiceLanguageSheet', () {
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets('${language.code} ${dark ? 'dark' : 'light'}: fits 320x640',
            (tester) async {
          translations.language = language;
          useSurface(tester, const Size(320, 640));
          VoiceLanguage? picked;
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => picked = await VoiceLanguageSheet.show(
                    context,
                    selectedLanguage: VoiceLanguage.defaultLang,
                  ),
                  child: const Text('sheet'),
                ),
              ),
            ),
          ));
          await tester.tap(find.text('sheet'));
          await tester.pumpAndSettle();
          expectNoTruncatedText(tester);
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('English'));
          await tester.pumpAndSettle();
          expect(picked, VoiceLanguage.english);
        });
      }
    }
  });

  group('MonthlyLimitExceededDialog', () {
    Future<void> showDialogIn(WidgetTester tester,
        {required bool dark, String tier = 'standard'}) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, __) => Scaffold(
              body: TextButton(
                onPressed: () => MonthlyLimitExceededDialog.show(
                  context,
                  conversationsUsed: 3,
                  limit: 3,
                  tier: tier,
                  month: '2026-09',
                ),
                child: const Text('limit'),
              ),
            ),
          ),
          GoRoute(
            path: '/pricing',
            builder: (_, state) =>
                Scaffold(body: Text('stub:pricing:${state.extra}')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
      ));
      await tester.tap(find.text('limit'));
      await tester.pumpAndSettle();
    }

    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets('${language.code} ${dark ? 'dark' : 'light'}: fits 320x640',
            (tester) async {
          translations.language = language;
          useSurface(tester, const Size(320, 640));
          await showDialogIn(tester, dark: dark);
          expectNoTruncatedText(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('shows usage and plans; View plans opens pricing',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await showDialogIn(tester, dark: true);

      expect(find.text('Monthly Limit Reached'), findsOneWidget);
      expect(
        find.text('You\'ve used all 3 voice conversations for this month.'),
        findsOneWidget,
      );
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('3 of 3 used'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Standard: '), findsOneWidget);
      expect(find.textContaining('Plus: '), findsOneWidget);
      expect(find.textContaining('Premium: '), findsOneWidget);

      await tester.tap(find.text('View plans'));
      await tester.pumpAndSettle();
      expect(find.text('stub:pricing:{preselectedPlan: plus}'), findsOneWidget);
    });

    testWidgets('plus tier preselects premium', (tester) async {
      useSurface(tester, const Size(390, 844));
      await showDialogIn(tester, dark: false, tier: 'plus');
      await tester.tap(find.text('View plans'));
      await tester.pumpAndSettle();
      expect(
          find.text('stub:pricing:{preselectedPlan: premium}'), findsOneWidget);
    });

    testWidgets('Maybe later closes it', (tester) async {
      useSurface(tester, const Size(390, 844));
      await showDialogIn(tester, dark: true);
      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle();
      expect(find.byType(MonthlyLimitExceededDialog), findsNothing);
      expect(find.text('limit'), findsOneWidget);
    });
  });

  group('VoicePreferencesPageWrapper', () {
    late _MockPrefsBloc bloc;

    setUp(() => bloc = _MockPrefsBloc());

    testWidgets('loading shows a spinner under the title', (tester) async {
      when(() => bloc.state).thenReturn(const VoicePreferencesLoading());
      await open(tester, VoicePreferencesPageWrapper(bloc: bloc),
          settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Voice Settings'), findsOneWidget);
    });

    testWidgets('error retries loading', (tester) async {
      when(() => bloc.state)
          .thenReturn(const VoicePreferencesError(message: 'x'));
      await open(tester, VoicePreferencesPageWrapper(bloc: bloc));
      await tester.tap(find.text('Retry'));
      verify(() => bloc.add(const LoadVoicePreferences())).called(1);
    });

    testWidgets('Save dispatches UpdateVoicePreferences; spinner while saving',
        (tester) async {
      useSurface(tester, const Size(390, 3000));
      whenListen(
        bloc,
        const Stream<VoicePreferencesState>.empty(),
        initialState: const VoicePreferencesLoaded(preferences: _prefs),
      );
      await open(tester, VoicePreferencesPageWrapper(bloc: bloc));
      await tester.tap(find.text('Quota alerts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      verify(() => bloc.add(UpdateVoicePreferences(
          _prefs.copyWith(notifyDailyQuotaReached: false)))).called(1);
    });
  });
}
