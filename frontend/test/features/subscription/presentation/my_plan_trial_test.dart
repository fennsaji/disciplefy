import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/subscription/data/datasources/subscription_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/subscription/data/models/subscription_v2_models.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/subscription.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/pages/my_plan_page.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';

import '../../../helpers/text_fit.dart';
import '../../../helpers/welcome_test_harness.dart';

class _MockTokenBloc extends MockBloc<TokenEvent, TokenState>
    implements TokenBloc {}

class _MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

class _FakeSystemConfig extends Fake implements SystemConfigService {
  @override
  bool get isNewSubscriptionsEnabled => true;

  @override
  SystemConfig? get config => null;
}

SubscriptionPlanModel _plan(String code, int tier, List<String> features) =>
    SubscriptionPlanModel(
      planId: code,
      planCode: code,
      planName: code,
      tier: tier,
      interval: 'monthly',
      features: const {},
      marketingFeatures: features,
      sortOrder: tier,
      pricing: PlanPricingModel(
        provider: 'razorpay',
        providerPlanId: 'p_$code',
        basePriceMinor: tier * 7900,
        currency: 'INR',
        basePriceFormatted: tier * 79.0,
      ),
    );

/// Free first, so a page that falls back to `plans.first` shows Free's copy.
final _plans = GetPlansResponseModel(
  success: true,
  plans: [
    _plan('free', 0, ['Daily Bible verse', '15 credits a day']),
    _plan('standard', 1, [
      'Daily Bible verse',
      '40 credits a day',
      'Discipler · 3 conversations a month',
    ]),
  ],
);

class _FakeSubscriptionData extends Fake
    implements SubscriptionRemoteDataSource {
  @override
  Future<GetPlansResponseModel> getPlans({
    required String provider,
    String? region,
    String? promoCode,
    String? locale,
  }) async =>
      _plans;
}

TokenStatus _standard() => TokenStatus(
      availableTokens: 30,
      purchasedTokens: 0,
      totalTokens: 30,
      dailyLimit: 40,
      totalConsumedToday: 10,
      userPlan: UserPlan.standard,
      lastReset: DateTime(2026, 10, 6),
      nextResetTime: DateTime(2026, 10, 7, 6),
      authenticationType: AuthenticationType.authenticated,
      isPremium: false,
      unlimitedUsage: false,
      canPurchaseTokens: true,
      planDescription: '',
    );

/// The trial row the backend writes for a new Standard user.
Subscription _trial() => Subscription(
      id: 'trial-1',
      userId: 'u1',
      razorpaySubscriptionId: '',
      provider: 'trial',
      status: SubscriptionStatus.trial,
      planType: 'standard_trial',
      amountPaise: 0,
      currency: 'INR',
      currentPeriodEnd: DateTime(2027, 3, 31),
      paidCount: 0,
      cancelAtCycleEnd: false,
      createdAt: DateTime(2026, 10, 2),
      updatedAt: DateTime(2026, 10, 2),
    );

void main() {
  late FakeTranslationService translations;
  late _MockTokenBloc tokenBloc;
  late _MockSubscriptionBloc subscriptionBloc;

  setUp(() {
    translations = FakeTranslationService();
    tokenBloc = _MockTokenBloc();
    subscriptionBloc = _MockSubscriptionBloc();
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<SystemConfigService>(_FakeSystemConfig());
    sl.registerSingleton<SubscriptionRemoteDataSource>(_FakeSubscriptionData());
    sl.registerSingleton<TokenBloc>(tokenBloc);
    when(() => tokenBloc.state).thenReturn(
        TokenLoaded(tokenStatus: _standard(), lastUpdated: DateTime(2026)));
    whenListen(
      subscriptionBloc,
      Stream<SubscriptionState>.fromIterable([
        SubscriptionLoaded(
          activeSubscription: _trial(),
          lastUpdated: DateTime(2026),
        ),
      ]),
      initialState: const SubscriptionInitial(),
    );
  });

  tearDown(() async => sl.reset());

  Widget app({bool dark = true}) {
    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(path: '/page', builder: (_, __) => const MyPlanPage()),
        GoRoute(
          path: '/pricing',
          builder: (_, __) => const Scaffold(body: Text('stub:/pricing')),
        ),
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

  testWidgets('a Standard trial shows Standard, no store and no Cancel',
      (tester) async {
    useSurface(tester, const Size(390, 1400));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Trial'), findsWidgets);
    expect(find.textContaining('March 31, 2027'), findsWidgets);
    expect(find.text('App Store'), findsNothing);
    expect(find.text('Razorpay'), findsNothing);
    expect(find.textContaining('Via '), findsNothing);
    expect(find.text('Cancel plan'), findsNothing);
    expect(find.byKey(const Key('my_plan_cancel')), findsNothing);
    expect(find.text('View plans'), findsOneWidget);
    // Standard's own features, never Free's.
    expect(find.textContaining('40 credits a day'), findsOneWidget);
    expect(find.textContaining('15'), findsNothing);
  });

  testWidgets('View plans opens the plans page', (tester) async {
    useSurface(tester, const Size(390, 1400));
    await tester.pumpWidget(app(dark: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View plans'));
    await tester.pumpAndSettle();
    expect(find.text('stub:/pricing'), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('320px ${language.code}: trial fits', (tester) async {
      translations.language = language;
      useSurface(tester, const Size(320, 1400));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(tester);
    });
  }
}
