import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
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
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/usecases/usecase.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_event.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_event.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/saved_guides_state.dart';
import 'package:disciplefy_bible_study/features/saved_guides/presentation/bloc/unified_saved_guides_bloc.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/datasources/study_local_data_source.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/repositories/token_cost_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/usecases/get_default_study_language.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/study_bloc.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/study_event.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/study_state.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/generate_simple_screen.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/generate_study_screen.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/generate_tab_page.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/services/study_launch_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/generate_hero.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/simple/depth_switch.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/simple/verse_of_day_row.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/user_subscription_status.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/out_of_credits_sheet.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

import '../../../../helpers/fit_matrix.dart';
import '../../../../helpers/text_fit.dart';

class _MockTokenBloc extends MockBloc<TokenEvent, TokenState>
    implements TokenBloc {}

class _MockStudyBloc extends MockBloc<StudyEvent, StudyState>
    implements StudyBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _MockDailyVerseBloc extends MockBloc<DailyVerseEvent, DailyVerseState>
    implements DailyVerseBloc {}

class _MockSavedGuidesBloc extends MockBloc<SavedGuidesEvent, SavedGuidesState>
    implements UnifiedSavedGuidesBloc {}

class _MockTokenCosts extends Mock implements TokenCostRepository {}

class _FakeLanguageService extends Fake implements LanguagePreferenceService {
  final AppLanguage language;
  final String? savedMode;
  final bool cached;
  _FakeLanguageService(this.language, {this.savedMode, this.cached = true});

  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();

  @override
  Future<AppLanguage> getSelectedLanguage() async => language;

  @override
  Future<AppLanguage> getStudyContentLanguage() async => language;

  @override
  Future<bool> isStudyContentLanguageDefault() async => true;

  @override
  Future<String?> getStudyModePreferenceRaw() async => savedMode;

  @override
  String? peekStudyModePreferenceRaw() =>
      cached ? savedMode : throw StateError('not cached');

  @override
  Future<void> saveStudyContentLanguage(AppLanguage? language) async {}
}

class _FakeDefaultLanguage extends Fake implements GetDefaultStudyLanguage {
  @override
  Future<Either<Failure, StudyLanguage>> call(NoParams params) async =>
      const Right(StudyLanguage.english);
}

class _FakeSystemConfig extends Fake implements SystemConfigService {
  final bool singleInput;
  _FakeSystemConfig({this.singleInput = true});

  @override
  bool isFeatureEnabled(String featureKey, String planType) =>
      featureKey == RolloutFlags.generateSingleInputKey && singleInput;

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

TokenStatus _status(int total, {bool premium = false}) => TokenStatus(
      availableTokens: total,
      purchasedTokens: 0,
      totalTokens: total,
      dailyLimit: 20,
      totalConsumedToday: 0,
      userPlan: premium ? UserPlan.premium : UserPlan.free,
      lastReset: DateTime(2026),
      nextResetTime: DateTime(2026, 1, 2),
      authenticationType: AuthenticationType.authenticated,
      isPremium: premium,
      unlimitedUsage: premium,
      canPurchaseTokens: false,
      planDescription: '',
    );

final _verse = DailyVerseEntity(
  id: 'v1',
  reference: 'Psalm 23:1',
  referenceTranslations: const ReferenceTranslations(
      en: 'Psalm 23:1', hi: 'भजन संहिता 23:1', ml: 'സങ്കീർത്തനം 23:1'),
  translations: const DailyVerseTranslations(
    esv: 'The LORD is my shepherd; I shall not want.',
    hindi: 'यहोवा मेरा चरवाहा है, मुझे कुछ घटी न होगी।',
    malayalam: 'യഹോവ എന്റെ ഇടയനാകുന്നു; എനിക്കു മുട്ടുണ്ടാകയില്ല.',
  ),
  date: DateTime(2026, 10, 6),
);

const _modeCosts = {'quick': 10, 'standard': 20};

late _MockTokenCosts _costRepo;

Future<void> _register({
  AppLanguage language = AppLanguage.english,
  bool singleInput = true,
  String? savedMode,
  bool cached = true,
}) async {
  SharedPreferences.setMockInitialValues(
      {'user_language_preference': language.code});
  final prefs = await SharedPreferences.getInstance();
  final languageService =
      _FakeLanguageService(language, savedMode: savedMode, cached: cached);
  final savedGuides = _MockSavedGuidesBloc();
  when(() => savedGuides.state).thenReturn(SavedGuidesInitial());
  _costRepo = _MockTokenCosts();
  when(() => _costRepo.getTokenCost(any(), any())).thenAnswer(
      (inv) async => Right(_modeCosts[inv.positionalArguments[1]] ?? 30));
  final config = _FakeSystemConfig(singleInput: singleInput);

  await GetIt.instance.reset();
  GetIt.instance
    ..registerSingleton<LanguagePreferenceService>(languageService)
    ..registerSingleton<TranslationService>(
        TranslationService(languageService, prefs))
    ..registerSingleton<SystemConfigService>(config)
    ..registerSingleton<RolloutFlags>(RolloutFlags(config))
    ..registerSingleton<StudyNavigator>(_FakeNavigator())
    ..registerSingleton<TokenCostRepository>(_costRepo)
    ..registerSingleton<GetDefaultStudyLanguage>(_FakeDefaultLanguage())
    ..registerSingleton<WalkthroughRepository>(_FakeWalkthrough())
    ..registerSingleton<StudyLocalDataSource>(_FakeLocalData())
    ..registerSingleton<StudyLaunchService>(
        StudyLaunchService(_FakeLocalData()))
    ..registerSingleton<SubscriptionRepository>(_FakeSubscriptions())
    ..registerSingleton<UnifiedSavedGuidesBloc>(savedGuides);
}

Widget _app({
  bool dark = true,
  int credits = 50,
  Widget? home,
  bool premium = false,
  double textScale = 1,
}) {
  final tokenBloc = _MockTokenBloc();
  when(() => tokenBloc.state).thenReturn(TokenLoaded(
      tokenStatus: _status(credits, premium: premium),
      lastUpdated: DateTime(2026)));
  final studyBloc = _MockStudyBloc();
  when(() => studyBloc.state).thenReturn(StudyInitial());
  final connectivity = _MockConnectivityBloc();
  when(() => connectivity.state).thenReturn(ConnectivityOnline());
  final verses = _MockDailyVerseBloc();
  when(() => verses.state).thenReturn(DailyVerseLoaded(
    verse: _verse,
    currentLanguage: VerseLanguage.english,
    preferredLanguage: VerseLanguage.english,
  ));

  final router = GoRouter(
    initialLocation: AppRoutes.generateStudy,
    routes: [
      GoRoute(
        path: AppRoutes.generateStudy,
        builder: (_, __) => home ?? const GenerateSimpleScreen(),
      ),
      GoRoute(
        path: '/study-guide-v2',
        builder: (_, state) => Scaffold(body: Text('guide:${state.uri}')),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<TokenBloc>.value(value: tokenBloc),
      BlocProvider<StudyBloc>.value(value: studyBloc),
      BlocProvider<ConnectivityBloc>.value(value: connectivity),
      BlocProvider<DailyVerseBloc>.value(value: verses),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

Future<void> pumpSimple(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.english,
  bool dark = true,
  int credits = 50,
  Size size = const Size(390, 1400),
  bool premium = false,
  String? savedMode,
  double textScale = 1,
}) async {
  await _register(language: language, savedMode: savedMode);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(
      dark: dark, credits: credits, premium: premium, textScale: textScale));
  await tester.pumpAndSettle();
}

/// Types into the input and lets the debounced detection run.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _tapGenerate(WidgetTester tester) async {
  final button = find.byKey(const Key('generate_simple_button'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(''));
  tearDown(() => GetIt.instance.reset());

  testWidgets('typing a question tags it and shows cost under the button',
      (tester) async {
    await pumpSimple(tester);

    await _type(tester, 'What is the purpose of prayer?');
    expect(find.text('Question'), findsOneWidget);
    expect(find.text('Using 20 credits'), findsOneWidget);
    expect(find.text('Scripture'), findsNothing); // no type tabs
  });

  testWidgets('an unlimited plan never shows "Using N credits"',
      (tester) async {
    await pumpSimple(tester, premium: true);
    await _type(tester, 'What is the purpose of prayer?');
    expect(find.textContaining('Using'), findsNothing);
  });

  testWidgets('no type tabs, ≤3 chips, verse row, two depths + All 5',
      (tester) async {
    await pumpSimple(tester);
    expect(find.byType(InputTypeTabs), findsNothing);
    expect(find.byKey(const Key('suggestion_chip')), findsNWidgets(3));
    expect(find.byType(VerseOfDayRow), findsOneWidget);
    expect(find.byType(DepthSwitch), findsOneWidget);
    expect(find.text('All 5'), findsOneWidget);
  });

  testWidgets('the type tag cycles as a manual override', (tester) async {
    await pumpSimple(tester);
    await _type(tester, 'Romans 8');
    expect(find.text('Scripture'), findsOneWidget);
    await tester.tap(find.byKey(const Key('input_type_tag')));
    await tester.pump();
    expect(find.text('Topic'), findsOneWidget);
    await tester.tap(find.byKey(const Key('input_type_tag')));
    await tester.pump();
    expect(find.text('Question'), findsOneWidget);
  });

  testWidgets('editing the text drops the manual type', (tester) async {
    await pumpSimple(tester);
    await _type(tester, 'Romans 8');
    await tester.tap(find.byKey(const Key('input_type_tag')));
    await tester.pump();
    expect(find.text('Topic'), findsOneWidget);

    await _type(tester, 'Romans 8:28');
    expect(find.text('Scripture'), findsOneWidget);
    expect(find.text('Topic'), findsNothing);
  });

  testWidgets('a non-reference forced to scripture is blocked with a message',
      (tester) async {
    await pumpSimple(tester);
    await _type(tester, 'Forgiveness');
    // topic → question → scripture
    await tester.tap(find.byKey(const Key('input_type_tag')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('input_type_tag')));
    await tester.pump();
    expect(find.text('Scripture'), findsOneWidget);

    await _tapGenerate(tester);
    expect(find.textContaining('guide:'), findsNothing);
    expect(find.byKey(const Key('generate_simple_error')), findsOneWidget);
    expect(find.textContaining('valid scripture reference'), findsOneWidget);

    // Editing clears the message.
    await _type(tester, 'Forgiveness of sins');
    expect(find.byKey(const Key('generate_simple_error')), findsNothing);
  });

  testWidgets('a reference forced to scripture passes the check',
      (tester) async {
    await pumpSimple(tester);
    // "Psalms 23" shape passes the reference check whatever detection says.
    await _type(tester, 'Hope 3');
    while (tester
            .widget<Text>(find.descendant(
                of: find.byKey(const Key('input_type_tag')),
                matching: find.byType(Text)))
            .data !=
        'Scripture') {
      await tester.tap(find.byKey(const Key('input_type_tag')));
      await tester.pump();
    }
    await _tapGenerate(tester);

    expect(find.byKey(const Key('generate_simple_error')), findsNothing);
    final text = tester.widget<Text>(find.textContaining('guide:')).data!;
    expect(text, contains('type=scripture'));
    expect(text, contains('input=Hope%203'));
  });

  testWidgets('Generate opens the streaming guide directly', (tester) async {
    await pumpSimple(tester);
    await _type(tester, 'Romans 8');
    await _tapGenerate(tester);

    final guide = find.textContaining('guide:/study-guide-v2');
    expect(guide, findsOneWidget);
    final text = tester.widget<Text>(guide).data!;
    expect(text, contains('type=scripture'));
    expect(text, contains('mode=standard'));
    expect(text, contains('input=Romans%208'));
  });

  testWidgets('Quick depth picked on the switch is passed through',
      (tester) async {
    await pumpSimple(tester);
    await tester.tap(find.byKey(const ValueKey('depth_switch_quick')));
    await tester.pump();
    await _type(tester, 'Forgiveness');
    await _tapGenerate(tester);

    final text = tester.widget<Text>(find.textContaining('guide:')).data!;
    expect(text, contains('type=topic'));
    expect(text, contains('mode=quick'));
  });

  group('initial depth follows the saved default study mode', () {
    bool selected(WidgetTester tester, String mode) => tester
        .widgetList<Semantics>(find.ancestor(
            of: find.byKey(ValueKey('depth_switch_$mode')),
            matching: find.byType(Semantics)))
        .any((s) => s.properties.selected == true);

    Future<String> generated(WidgetTester tester) async {
      await _type(tester, 'Grace');
      await _tapGenerate(tester);
      return tester.widget<Text>(find.textContaining('guide:')).data!;
    }

    for (final unset in [null, 'recommended', 'ask']) {
      testWidgets('"$unset" falls back to Standard', (tester) async {
        await pumpSimple(tester, savedMode: unset);
        expect(selected(tester, 'standard'), isTrue);
        expect(selected(tester, 'quick'), isFalse);
        expect(await generated(tester), contains('mode=standard'));
      });
    }

    testWidgets('saved quick selects Quick', (tester) async {
      await pumpSimple(tester, savedMode: 'quick');
      expect(selected(tester, 'quick'), isTrue);
      expect(await generated(tester), contains('mode=quick'));
    });

    testWidgets('saved standard selects Standard', (tester) async {
      await pumpSimple(tester, savedMode: 'standard');
      expect(selected(tester, 'standard'), isTrue);
      expect(await generated(tester), contains('mode=standard'));
    });

    testWidgets('saved deep is named below the switch with its cost',
        (tester) async {
      await pumpSimple(tester, savedMode: 'deep');
      expect(selected(tester, 'quick'), isFalse);
      expect(selected(tester, 'standard'), isFalse);
      expect(find.text('Deep Dive · 12 min'), findsOneWidget);
      expect(find.text('Using 30 credits'), findsOneWidget);
      expect(await generated(tester), contains('mode=deep'));
    });

    testWidgets('without a cached value the saved mode is read before showing',
        (tester) async {
      await _register(savedMode: 'quick', cached: false);
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Visibility>(find.ancestor(
                  of: find.byType(DepthSwitch),
                  matching: find.byType(Visibility)))
              .visible,
          isTrue);
      expect(selected(tester, 'quick'), isTrue);
    });

    testWidgets('the cost line follows the saved mode', (tester) async {
      await pumpSimple(tester, savedMode: 'quick');
      await _type(tester, 'Grace');
      expect(find.text('Using 10 credits'), findsOneWidget);
    });
  });

  testWidgets('typed text keeps the field one line; the tag is solid gold',
      (tester) async {
    await pumpSimple(tester);
    await _type(tester, 'Romans 8');
    // The hidden hint used to keep its wrapped height and grow the field.
    expect(
        tester.getSize(find.byType(TextField)).height, lessThanOrEqualTo(48));
    final pill = tester.widget<Container>(find.descendant(
        of: find.byKey(const Key('input_type_tag')),
        matching: find.byType(Container)));
    expect((pill.decoration as ShapeDecoration).color, AppColors.brandGold);
  });

  testWidgets('a depth from "All 5" clears the switch and is named below it',
      (tester) async {
    await pumpSimple(tester);
    await tester.tap(find.byKey(const Key('generate_depth_all')));
    await tester.pumpAndSettle();
    // Compact sheet over the tab: every depth, language and the button.
    expect(find.text('Choose depth'), findsNWidgets(2));
    expect(find.byKey(const Key('all_depths_language')), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    final deep = find.byKey(const ValueKey('all_depths_deep'));
    await tester.ensureVisible(deep);
    await tester.pumpAndSettle();
    await tester.tap(deep);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('all_depths_generate')));
    await tester.pumpAndSettle();

    // Empty input: nothing starts, the depth is just remembered.
    expect(find.textContaining('guide:'), findsNothing);
    expect(find.text('Deep Dive · 12 min'), findsOneWidget);
    final switchSemantics = tester.widgetList<Semantics>(find.descendant(
        of: find.byType(DepthSwitch), matching: find.byType(Semantics)));
    expect(
        switchSemantics.where((s) => s.properties.selected == true), isEmpty);
    expect(find.text('Using 30 credits'), findsOneWidget);

    await _type(tester, 'Grace');
    await _tapGenerate(tester);
    expect(tester.widget<Text>(find.textContaining('guide:')).data,
        contains('mode=deep'));
  });

  testWidgets('choosing "Default" in the language menu is not ignored',
      (tester) async {
    await pumpSimple(tester);
    await tester.tap(find.byKey(const Key('generate_language_pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();
    expect(find.text('हिं'), findsOneWidget);

    await tester.tap(find.byKey(const Key('generate_language_pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Default'));
    await tester.pumpAndSettle();
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('Generate is disabled until the input is valid', (tester) async {
    await pumpSimple(tester);
    await _tapGenerate(tester);
    expect(find.textContaining('guide:'), findsNothing);
    await _type(tester, 'x');
    await _tapGenerate(tester);
    expect(find.textContaining('guide:'), findsNothing);
  });

  testWidgets('not enough credits opens the honest sheet', (tester) async {
    await _register();
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(credits: 5));
    await tester.pumpAndSettle();

    await _type(tester, 'Forgiveness');
    await _tapGenerate(tester);

    expect(find.byType(OutOfCreditsSheet), findsOneWidget);
    expect(find.textContaining('guide:'), findsNothing);
  });

  testWidgets('verse of the day row starts immediately', (tester) async {
    await pumpSimple(tester);
    await tester.tap(find.byType(VerseOfDayRow));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.textContaining('guide:')).data!;
    expect(text, contains('input=Psalm%2023%3A1'));
    expect(text, contains('type=scripture'));
    expect(text, contains('mode=standard'));
  });

  testWidgets('a suggestion chip fills the input', (tester) async {
    await pumpSimple(tester);
    await tester.tap(find.byKey(const Key('suggestion_chip')).first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('John 3:16'), findsOneWidget);
    expect(find.text('Scripture'), findsOneWidget);
  });

  testWidgets('prefill starts with the text in the input', (tester) async {
    await _register();
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(_app(home: const GenerateSimpleScreen(prefill: 'Hope')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hope');
    expect(find.text('Topic'), findsOneWidget);
  });

  group('Generate tab picks the screen by flag', () {
    for (final on in [true, false]) {
      testWidgets('generate_single_input ${on ? 'on' : 'off'}', (tester) async {
        await _register();
        await GetIt.instance.unregister<RolloutFlags>();
        GetIt.instance.registerSingleton<RolloutFlags>(
            RolloutFlags(_FakeSystemConfig(singleInput: on)));
        tester.view.physicalSize = const Size(390, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(home: const GenerateTabPage()));
        await tester.pumpAndSettle();

        expect(find.byType(GenerateSimpleScreen),
            on ? findsOneWidget : findsNothing);
        expect(find.byType(GenerateStudyScreen),
            on ? findsNothing : findsOneWidget);
      });
    }
  });

  group('the input field keeps one height', () {
    setUpAll(loadAppFonts);

    for (final language in AppLanguage.values) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('320px ${language.code} ${scale}x: empty = typed',
            (tester) async {
          await pumpSimple(tester,
              language: language,
              size: const Size(320, 1400),
              textScale: scale);
          final field = find.byKey(const Key('generate_simple_field'));
          final empty = tester.getSize(field).height;
          expect(empty, 56);
          // The title, subtitle and chips fit; the hint may only ellipsize
          // at 1.3x.
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester, allow: {
            if (scale > 1)
              tester
                  .widget<TextField>(find.byType(TextField))
                  .decoration!
                  .hintText!,
            _verse.translations.esv,
            _verse.translations.hindi,
            _verse.translations.malayalam,
          });

          await _type(tester,
              'What does the Bible say about forgiveness and grace today?');
          expect(tester.getSize(field).height, empty);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byTooltip('Delete'));
          await tester.pumpAndSettle();
          expect(tester.getSize(field).height, empty);
        });
      }
    }

    for (final width in [320.0, 360.0]) {
      for (final language in AppLanguage.values) {
        for (final scale in [1.0, 1.3]) {
          testWidgets(
              'depth switch stays one line: ${width.toInt()}px '
              '${language.code} ${scale}x', (tester) async {
            await pumpSimple(tester,
                language: language, size: Size(width, 1400), textScale: scale);
            for (final mode in ['quick', 'standard']) {
              final segment = find.byKey(ValueKey('depth_switch_$mode'));
              // 40 is the segment's minimum: taller means it wrapped.
              expect(tester.getSize(segment).height, 40,
                  reason: '$mode wrapped');
            }
            expect(tester.takeException(), isNull);
            // At normal size nothing in the switch is cut off.
            if (scale == 1.0) {
              // The verse row ellipsizes by design.
              expectNoTruncatedText(tester,
                  ignoreUnder: [find.byType(VerseOfDayRow)]);
            }
          });
        }
      }
    }

    testWidgets('the depth switch uses the short minute form', (tester) async {
      await pumpSimple(tester, language: AppLanguage.malayalam);
      expect(find.text('3 മി'), findsOneWidget);
      expect(find.text('8 മി'), findsOneWidget);
    });

    testWidgets('a subtitle under the title says what to type', (tester) async {
      await pumpSimple(tester);
      expect(find.byKey(const Key('generate_simple_subtitle')), findsOneWidget);
      expect(find.text('Type a verse, a topic or a question'), findsOneWidget);
      expect(find.text('e.g. John 3:16, grace'), findsOneWidget);
      final title =
          tester.getBottomLeft(find.text('What shall we study today?'));
      final subtitle =
          tester.getTopLeft(find.byKey(const Key('generate_simple_subtitle')));
      expect(subtitle.dy, greaterThanOrEqualTo(title.dy));
    });
  });

  group('no cut-off text at 360px and 320px', () {
    setUpAll(loadAppFonts);

    for (final width in fitWidths) {
      for (final language in AppLanguage.values) {
        for (final dark in [true, false]) {
          testWidgets(
              '${width.toInt()}px ${language.code} ${dark ? 'dark' : 'light'}',
              (tester) async {
            await pumpSimple(tester,
                language: language, dark: dark, size: Size(width, 1400));
            expect(tester.takeException(), isNull);
            expectNoTruncatedText(tester, allow: {
              _verse.translations.esv,
              _verse.translations.hindi,
              _verse.translations.malayalam,
            });

            await _type(tester, 'What is the purpose of prayer?');
            expect(tester.takeException(), isNull);
            expectNoTruncatedText(tester);

            // "All 5" sheet: every depth row and the button fit too.
            await tester.tap(find.byKey(const Key('generate_depth_all')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expectNoTruncatedText(tester);
          });
        }
      }
    }
  });
}
