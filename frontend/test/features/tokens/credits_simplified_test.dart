import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/repositories/token_cost_repository.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/pages/token_management_page.dart';

import '../../helpers/text_fit.dart';
import '../../helpers/welcome_test_harness.dart';

class _MockTokenBloc extends MockBloc<TokenEvent, TokenState>
    implements TokenBloc {}

class _MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

class _FakeSystemConfig extends Fake implements SystemConfigService {
  @override
  bool get isTokenPurchaseEnabled => true;

  @override
  bool get isNewSubscriptionsEnabled => true;
}

/// Costs per content language, as the backend's static table.
class _FakeCosts extends Fake implements TokenCostRepository {
  final List<String> asked = [];
  bool fail = false;

  static const _table = {
    'en': {'quick': 10, 'standard': 20, 'deep': 30},
    'hi': {'quick': 15, 'standard': 30, 'deep': 45},
    'ml': {'quick': 15, 'standard': 30, 'deep': 45},
  };

  @override
  Future<Either<Failure, int>> getTokenCost(
      String language, String mode) async {
    asked.add('$language:$mode');
    final cost = _table[language]?[mode];
    if (fail || cost == null) {
      return const Left(ServerFailure(message: 'no cost'));
    }
    return Right(cost);
  }
}

class _FakeLanguages extends Fake implements LanguagePreferenceService {
  AppLanguage content;
  _FakeLanguages(this.content);

  @override
  Future<AppLanguage> getStudyContentLanguage() async => content;

  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();
}

TokenStatus _status() => TokenStatus(
      availableTokens: 30,
      purchasedTokens: 0,
      totalTokens: 30,
      dailyLimit: 40,
      totalConsumedToday: 10,
      userPlan: UserPlan.standard,
      lastReset: DateTime(2026, 10, 6),
      nextResetTime: DateTime.now().add(const Duration(hours: 6)),
      authenticationType: AuthenticationType.authenticated,
      isPremium: false,
      unlimitedUsage: false,
      canPurchaseTokens: true,
      planDescription: '',
    );

void main() {
  late FakeTranslationService translations;
  late _MockTokenBloc tokenBloc;
  late _MockSubscriptionBloc subscriptionBloc;
  late _FakeCosts costs;
  late _FakeLanguages languages;

  setUp(() {
    translations = FakeTranslationService();
    tokenBloc = _MockTokenBloc();
    subscriptionBloc = _MockSubscriptionBloc();
    costs = _FakeCosts();
    languages = _FakeLanguages(AppLanguage.english);
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<SystemConfigService>(_FakeSystemConfig());
    sl.registerSingleton<TokenCostRepository>(costs);
    sl.registerSingleton<LanguagePreferenceService>(languages);
    when(() => tokenBloc.state).thenReturn(
        TokenLoaded(tokenStatus: _status(), lastUpdated: DateTime(2026)));
    when(() => subscriptionBloc.state).thenReturn(const SubscriptionInitial());
  });

  tearDown(() async => sl.reset());

  Widget app({bool dark = true}) {
    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(path: '/page', builder: (_, __) => const TokenManagementPage()),
        for (final path in const [
          '/token-management/purchase',
          '/token-management/purchase-history',
          '/token-management/usage-history',
          '/my-plan',
          '/pricing',
          '/generate-study',
        ])
          GoRoute(
              path: path,
              builder: (_, __) => Scaffold(body: Text('stub:$path'))),
      ],
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider<TokenBloc>.value(value: tokenBloc),
        BlocProvider<SubscriptionBloc>.value(value: subscriptionBloc),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
      ),
    );
  }

  testWidgets('Credits page: one cost line, no per-plan table, no "Token"',
      (tester) async {
    useSurface(tester, const Size(390, 1600));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Kept: ring, reset, tiles, actions, one plan row.
    expect(find.text('30'), findsWidgets);
    expect(find.text('of 40'), findsOneWidget);
    expect(find.textContaining('Resets at'), findsOneWidget);
    expect(find.text('used today'), findsOneWidget);
    expect(find.text('purchased'), findsOneWidget);
    expect(find.text('Get credits'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);

    // One cost line from the repository for the content language.
    expect(find.text('WHAT A STUDY COSTS'), findsOneWidget);
    expect(
        find.text('Quick Read 10 · Standard 20 · Deep Dive 30 · Follow-up 5'),
        findsOneWidget);
    expect(costs.asked, containsAll(['en:quick', 'en:standard', 'en:deep']));

    // Gone: the multi-plan table.
    expect(find.text('DAILY CREDITS BY PLAN'), findsNothing);
    expect(find.text('Best for pastors and teachers'), findsNothing);
    expect(find.text('Premium'), findsNothing);
    expect(find.textContaining('oken'), findsNothing);
  });

  testWidgets('costs follow the content language, not the app language',
      (tester) async {
    languages.content = AppLanguage.hindi;
    useSurface(tester, const Size(390, 1600));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
        find.text('Quick Read 15 · Standard 30 · Deep Dive 45 · Follow-up 5'),
        findsOneWidget);
    expect(costs.asked, everyElement(startsWith('hi:')));
  });

  testWidgets('costs unavailable: the general "from" line stays',
      (tester) async {
    costs.fail = true;
    useSurface(tester, const Size(390, 1600));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.textContaining('Quick Read from 10'), findsOneWidget);
  });

  group('320px fit', () {
    setUpAll(loadAppFonts);

    for (final language in AppLanguage.values) {
      for (final dark in [false, true]) {
        testWidgets('${language.code} ${dark ? 'dark' : 'light'}',
            (tester) async {
          translations.language = language;
          languages.content = language;
          useSurface(tester, const Size(320, 2000));
          await tester.pumpWidget(app(dark: dark));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }
  });
}
