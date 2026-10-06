import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/services/study_launch_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/navigation/study_navigator.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/usecases/usecase.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_event.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_state.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/unified_saved_guides_bloc.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/datasources/study_local_data_source.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/repositories/token_cost_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/usecases/get_default_study_language.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/study_bloc.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/study_event.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/study_state.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/generate_study_screen.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/user_subscription_status.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

import '../../helpers/text_fit.dart';

class _MockTokenBloc extends MockBloc<TokenEvent, TokenState>
    implements TokenBloc {}

class _MockStudyBloc extends MockBloc<StudyEvent, StudyState>
    implements StudyBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _MockSavedGuidesBloc extends MockBloc<SavedGuidesEvent, SavedGuidesState>
    implements UnifiedSavedGuidesBloc {}

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  final String? savedMode;
  final AppLanguage language;
  _FakeLanguageService({this.savedMode, this.language = AppLanguage.english});

  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => language;

  @override
  Future<String?> getStudyModePreferenceRaw() async => savedMode;

  @override
  Future<bool> isStudyContentLanguageDefault() async => true;

  final List<AppLanguage?> savedContentLanguages = [];

  @override
  Future<void> saveStudyContentLanguage(AppLanguage? language) async =>
      savedContentLanguages.add(language);
}

class _FakeDefaultLanguage extends Fake implements GetDefaultStudyLanguage {
  @override
  Future<Either<Failure, StudyLanguage>> call(NoParams params) async =>
      const Right(StudyLanguage.english);
}

const _costs = {
  StudyMode.quick: 10,
  StudyMode.standard: 20,
  StudyMode.deep: 30,
  StudyMode.lectio: 20,
  StudyMode.sermon: 40,
};

class _FakeTokenCosts extends Fake implements TokenCostRepository {
  @override
  Future<Either<Failure, int>> getTokenCost(
          String language, String mode) async =>
      Right(_costs[studyModeFromString(mode)]!);
}

class _FakeSystemConfig extends Fake implements SystemConfigService {
  @override
  bool shouldHideFeature(String featureKey, String planType) => false;

  @override
  bool isFeatureLocked(String featureKey, String planType) => false;

  @override
  bool hasFeatureAccess(String featureKey, String planType) => true;
}

class _FakeSubscriptions extends Fake implements SubscriptionRepository {
  @override
  Future<Either<Failure, UserSubscriptionStatus>>
      getSubscriptionStatus() async => const Left(ServerFailure());
}

class _FakeWalkthrough extends Fake implements WalkthroughRepository {
  @override
  Future<bool> hasSeen(WalkthroughScreen screen) async => true;

  @override
  Future<void> markSeen(WalkthroughScreen screen) async {}
}

class _FakeLocalData extends Fake implements StudyLocalDataSource {
  @override
  Future<List<StudyGuide>> getCachedStudyGuides() async => const [];
}

class _FakeNavigator extends Fake implements StudyNavigator {}

Future<void> _register({
  String? savedMode,
  AppLanguage language = AppLanguage.english,
}) async {
  SharedPreferences.setMockInitialValues(
      {'user_language_preference': language.code});
  final prefs = await SharedPreferences.getInstance();
  final languageService =
      _FakeLanguageService(savedMode: savedMode, language: language);
  final savedGuides = _MockSavedGuidesBloc();
  when(() => savedGuides.state).thenReturn(SavedGuidesInitial());

  await GetIt.instance.reset();
  GetIt.instance
    ..registerSingleton<LanguagePreferenceService>(languageService)
    ..registerSingleton<TranslationService>(
        TranslationService(languageService, prefs))
    ..registerSingleton<SystemConfigService>(_FakeSystemConfig())
    ..registerSingleton<StudyNavigator>(_FakeNavigator())
    ..registerSingleton<TokenCostRepository>(_FakeTokenCosts())
    ..registerSingleton<GetDefaultStudyLanguage>(_FakeDefaultLanguage())
    ..registerSingleton<WalkthroughRepository>(_FakeWalkthrough())
    ..registerSingleton<StudyLocalDataSource>(_FakeLocalData())
    ..registerSingleton<StudyLaunchService>(
        StudyLaunchService(_FakeLocalData()))
    ..registerSingleton<SubscriptionRepository>(_FakeSubscriptions())
    ..registerSingleton<UnifiedSavedGuidesBloc>(savedGuides);
}

Widget _app({required bool dark, Stream<StudyState>? studyStates}) {
  final tokenBloc = _MockTokenBloc();
  when(() => tokenBloc.state).thenReturn(const TokenInitial());
  final studyBloc = _MockStudyBloc();
  if (studyStates != null) {
    whenListen(studyBloc, studyStates, initialState: StudyInitial());
  } else {
    when(() => studyBloc.state).thenReturn(StudyInitial());
  }
  final connectivity = _MockConnectivityBloc();
  when(() => connectivity.state).thenReturn(ConnectivityOnline());

  final router = GoRouter(
    initialLocation: AppRoutes.generateStudy,
    routes: [
      GoRoute(
        path: AppRoutes.generateStudy,
        builder: (_, __) => const GenerateStudyScreen(),
      ),
      GoRoute(
        path: '/study-guide-v2',
        builder: (_, state) =>
            Scaffold(body: Text('guide:${state.uri.queryParameters['mode']}')),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<TokenBloc>.value(value: tokenBloc),
      BlocProvider<StudyBloc>.value(value: studyBloc),
      BlocProvider<ConnectivityBloc>.value(value: connectivity),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void _usePhone(WidgetTester tester, {double width = 320}) {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _enterTopic(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _tapGenerate(WidgetTester tester) async {
  final button = find.byKey(const Key('generate_study_button'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => GetIt.instance.reset());

  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme: Generate tab lays out at 320pt', (tester) async {
      await _register();
      _usePhone(tester);
      await tester.pumpWidget(_app(dark: dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('GENERATE A STUDY'), findsOneWidget);
      expect(find.text('What shall we study today?'), findsOneWidget);
      expect(find.text('Choose depth'), findsOneWidget);
      expect(find.text('All 5'), findsOneWidget);
      expect(find.text('Generate study'), findsOneWidget);
    });
  }

  testWidgets('generate uses the depth picked inline', (tester) async {
    await _register();
    _usePhone(tester, width: 390);
    await tester.pumpWidget(_app(dark: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('depth_card_quick')));
    await tester.pump();
    await _enterTopic(tester, 'Forgiveness');
    // The button carries the picked depth's cost.
    expect(
      find.descendant(
        of: find.byKey(const Key('generate_study_button')),
        matching: find.text('10'),
      ),
      findsOneWidget,
    );
    await _tapGenerate(tester);

    expect(find.text('guide:quick'), findsOneWidget);
  });

  testWidgets('saved preference seeds the inline depth', (tester) async {
    await _register(savedMode: 'deep');
    _usePhone(tester, width: 390);
    await tester.pumpWidget(_app(dark: false));
    await tester.pumpAndSettle();

    await _enterTopic(tester, 'Hope');
    await _tapGenerate(tester);

    expect(find.text('guide:deep'), findsOneWidget);
  });

  testWidgets('"All 5" chooser: its choice becomes the depth and starts',
      (tester) async {
    await _register();
    _usePhone(tester, width: 390);
    await tester.pumpWidget(_app(dark: true));
    await tester.pumpAndSettle();

    await _enterTopic(tester, 'Forgiveness');
    await tester.tap(find.byKey(const Key('generate_depth_all')));
    await tester.pumpAndSettle();

    expect(find.text('FORGIVENESS'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('mode_option_lectio')), 120,
        scrollable: find.byType(Scrollable).last);
    await tester
        .ensureVisible(find.byKey(const ValueKey('mode_option_lectio')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode_option_lectio')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mode_selection_start')));
    await tester.pumpAndSettle();

    expect(find.text('guide:lectio'), findsOneWidget);
  });

  testWidgets('Generate has no Talk to Discipler entry (it has its own tab)',
      (tester) async {
    await _register();
    _usePhone(tester, width: 390);
    await tester.pumpWidget(_app(dark: true));
    await tester.pumpAndSettle();

    expect(find.text('Talk to Discipler'), findsNothing);
  });

  group('language menu', () {
    for (final dark in [true, false]) {
      testWidgets(
          'uses the palette card and still switches language '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        await _register();
        _usePhone(tester);
        await tester.pumpWidget(_app(dark: dark));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('generate_language_pill')));
        await tester.pumpAndSettle();

        final palette = ReaderPalette.of(
            tester.element(find.byKey(const Key('generate_language_pill'))));
        final menu = tester.widget<Material>(find
            .ancestor(of: find.text('हिन्दी'), matching: find.byType(Material))
            .last);
        expect(menu.color, palette.card);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('हिन्दी'));
        await tester.pumpAndSettle();
        expect(find.text('हिं'), findsOneWidget);
        final service =
            GetIt.instance<LanguagePreferenceService>() as _FakeLanguageService;
        expect(service.savedContentLanguages, [AppLanguage.hindi]);
      });
    }
  });

  group('no cut-off text at 320px', () {
    setUpAll(loadAppFonts);

    for (final language in AppLanguage.values) {
      testWidgets(language.code, (tester) async {
        await _register(language: language);
        tester.view.physicalSize = const Size(320, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(dark: language != AppLanguage.hindi));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }
  });

  group('generation failed dialog', () {
    setUpAll(loadAppFonts);

    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets('fits 320x640 ${language.code} ${dark ? 'dark' : 'light'}',
            (tester) async {
          await _register(language: language);
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_app(
            dark: dark,
            studyStates: Stream.value(const StudyGenerationFailure(
                failure: ServerFailure(message: 'Server hiccup'))),
          ));
          await tester.pumpAndSettle();

          expect(find.byType(PopupDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
          expect(find.byKey(const Key('generate_error_try_again')),
              findsOneWidget);

          await tester.tap(find.byKey(const Key('generate_error_ok')));
          await tester.pumpAndSettle();
          expect(find.byType(PopupDialog), findsNothing);
        });
      }
    }

    testWidgets('rate limit offers token management instead of retry',
        (tester) async {
      await _register();
      _usePhone(tester);
      await tester.pumpWidget(_app(
        dark: true,
        studyStates: Stream.value(
            const StudyGenerationFailure(failure: RateLimitFailure())),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('generate_error_manage_tokens')),
          findsOneWidget);
      expect(find.byKey(const Key('generate_error_try_again')), findsNothing);
    });
  });
}
