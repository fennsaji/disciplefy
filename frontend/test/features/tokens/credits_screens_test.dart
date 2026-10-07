import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/platform_detection_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/subscription/data/datasources/subscription_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/subscription/data/models/subscription_v2_models.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/subscription.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/user_subscription_status.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/pages/my_plan_page.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/pages/pricing_page.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/pricing_card.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/promo_code_input.dart';
import 'package:disciplefy_bible_study/features/tokens/data/datasources/token_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/tokens/data/models/token_pricing_model.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/pages/token_management_page.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/pages/token_purchase_page.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/purchase_statistics.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/usage_statistics.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/purchase_statistics_card.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/usage_statistics_card.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

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

  @override
  SystemConfig? get config => null;
}

class _FakePlatform extends Fake implements PlatformDetectionService {
  @override
  PaymentProvider getPreferredProvider() => PaymentProvider.razorpay;

  @override
  String providerToString(PaymentProvider provider) => 'razorpay';
}

SubscriptionPlanModel _plan(String code, String name, int tier, int price,
        int daily, List<String> features) =>
    SubscriptionPlanModel(
      planId: code,
      planCode: code,
      planName: name,
      tier: tier,
      interval: 'monthly',
      features: {'daily_tokens': daily},
      marketingFeatures: features,
      sortOrder: tier,
      pricing: PlanPricingModel(
        provider: 'razorpay',
        providerPlanId: 'p_$code',
        basePriceMinor: price * 100,
        currency: 'INR',
        basePriceFormatted: price.toDouble(),
      ),
    );

final _plans = GetPlansResponseModel(
  success: true,
  plans: [
    _plan('standard', 'Standard', 1, 79, 40,
        ['3 voice chats a month', '5 memory verses', '5 follow-ups per guide']),
    _plan('plus', 'Plus', 2, 149, 60,
        ['10 voice chats a month', '10 memory verses', 'Create fellowships']),
    _plan('premium', 'Premium', 3, 499, -1,
        ['Unlimited voice chats', 'Unlimited verses & follow-ups']),
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

class _FakeTokenData extends Fake implements TokenRemoteDataSource {
  @override
  Future<TokenPricingModel> getTokenPricing({String? region}) async =>
      TokenPricingModel(
        tokensPerRupee: 2,
        effectiveFrom: DateTime(2026),
        packages: const [
          TokenPackageModel(
              tokens: 20, rupees: 10, discount: 0, isPopular: false),
          TokenPackageModel(
              tokens: 50, rupees: 22, discount: 12, isPopular: false),
          TokenPackageModel(
              tokens: 100, rupees: 40, discount: 20, isPopular: true),
          TokenPackageModel(
              tokens: 200, rupees: 75, discount: 25, isPopular: false),
          TokenPackageModel(
              tokens: 400, rupees: 140, discount: 30, isPopular: false),
          TokenPackageModel(
              tokens: 1000, rupees: 300, discount: 40, isPopular: false),
        ],
      );
}

final _nextReset = DateTime.now().add(const Duration(hours: 6));

TokenStatus _status({UserPlan plan = UserPlan.standard}) => TokenStatus(
      availableTokens: 28,
      purchasedTokens: 50,
      totalTokens: 78,
      dailyLimit: 40,
      totalConsumedToday: 12,
      userPlan: plan,
      lastReset: DateTime(2026, 9, 29),
      nextResetTime: _nextReset,
      authenticationType: AuthenticationType.authenticated,
      isPremium: plan == UserPlan.premium,
      unlimitedUsage: plan == UserPlan.premium,
      canPurchaseTokens: plan != UserPlan.premium,
      planDescription: '',
    );

Subscription _subscription() => Subscription(
      id: 's1',
      userId: 'u1',
      razorpaySubscriptionId: 'sub_1',
      status: SubscriptionStatus.active,
      planType: 'standard_monthly',
      amountPaise: 7900,
      currency: 'INR',
      currentPeriodEnd: DateTime(2026, 10, 29),
      nextBillingAt: DateTime(2026, 10, 29),
      paidCount: 2,
      cancelAtCycleEnd: false,
      createdAt: DateTime(2026, 8, 29),
      updatedAt: DateTime(2026, 9, 29),
    );

List<SubscriptionInvoice> _invoices() => [
      SubscriptionInvoice(
        id: 'i1',
        subscriptionId: 's1',
        userId: 'u1',
        razorpayPaymentId: 'pay_1',
        invoiceNumber: 'DF-1',
        amountPaise: 7900,
        status: 'paid',
        billingPeriodStart: DateTime(2026, 9, 29),
        billingPeriodEnd: DateTime(2026, 10, 29),
        paidAt: DateTime(2026, 9, 29, 10, 2),
        createdAt: DateTime(2026, 9, 29),
      ),
    ];

void main() {
  late FakeTranslationService translations;
  late _MockTokenBloc tokenBloc;
  late _MockSubscriptionBloc subscriptionBloc;
  late List<String> pushed;
  late List<Object?> pushedExtras;

  setUpAll(() {
    registerFallbackValue(const GetTokenStatus());
    registerFallbackValue(const GetActiveSubscription());
  });

  setUp(() {
    // Razorpay's constructor resyncs over its channel; there is no plugin
    // in widget tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('razorpay_flutter'), (_) async => null);
    translations = FakeTranslationService();
    tokenBloc = _MockTokenBloc();
    subscriptionBloc = _MockSubscriptionBloc();
    pushed = [];
    pushedExtras = [];
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<SystemConfigService>(_FakeSystemConfig());
    sl.registerSingleton<SubscriptionRemoteDataSource>(_FakeSubscriptionData());
    sl.registerSingleton<TokenRemoteDataSource>(_FakeTokenData());
    sl.registerSingleton<TokenBloc>(tokenBloc);
    when(() => tokenBloc.state).thenReturn(
        TokenLoaded(tokenStatus: _status(), lastUpdated: DateTime(2026)));
    when(() => subscriptionBloc.state).thenReturn(const SubscriptionInitial());
  });

  tearDown(() async => sl.reset());

  Widget app(Widget page, {required bool dark}) {
    GoRoute stub(String path) => GoRoute(
          path: path,
          builder: (_, state) {
            pushed.add(path);
            pushedExtras.add(state.extra);
            return Scaffold(body: Text('stub:$path'));
          },
        );
    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(path: '/page', builder: (_, __) => page),
        stub('/token-management/purchase'),
        stub('/token-management/purchase-history'),
        stub('/token-management/usage-history'),
        stub('/my-plan'),
        stub('/pricing'),
        stub('/subscription-payment-history'),
        stub('/generate-study'),
        stub('/'),
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

  group('TokenManagementPage (credits)', () {
    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: balance hero, tiles and plan',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(const TokenManagementPage(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('Credits'), findsOneWidget);
        expect(find.text('Standard plan'), findsWidgets);
        expect(find.text('28 left today'), findsOneWidget);
        expect(find.text('of 40'), findsOneWidget);
        expect(find.text('used today'), findsOneWidget);
        expect(find.text('78'), findsOneWidget);
        expect(find.text('Get credits'), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
        expect(find.text('Manage'), findsOneWidget);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const TokenManagementPage(), dark: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Get credits pushes the purchase page with the balance',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const TokenManagementPage(), dark: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('credits_get_credits')));
      await tester.pumpAndSettle();

      expect(pushed, contains('/token-management/purchase'));
      expect(pushedExtras.last, _status());
    });

    testWidgets('Manage opens My Plan; Upgrade opens pricing', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const TokenManagementPage(), dark: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('credits_upgrade')));
      await tester.pumpAndSettle();
      expect(pushed.last, '/pricing');
    });
  });

  group('TokenPurchasePage (get credits)', () {
    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: packs grid, popular preselected',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(
          TokenPurchasePage(
              tokenStatus: _status(), userEmail: 'a@b.c', userPhone: '1'),
          dark: dark,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Balance · 78 credits'), findsOneWidget);
        expect(find.text('POPULAR'), findsOneWidget);
        expect(find.text('20% off'), findsOneWidget);
        expect(find.text('Get 100 credits · ₹40'), findsOneWidget);
      });
    }

    testWidgets('320x640 ml: no overflow', (tester) async {
      translations.language = AppLanguage.malayalam;
      useSurface(tester, const Size(320, 640));
      await tester.pumpWidget(app(
        TokenPurchasePage(
            tokenStatus: _status(), userEmail: 'a@b.c', userPhone: '1'),
        dark: true,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('buy CTA dispatches CreatePaymentOrder for the selected pack',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(
        TokenPurchasePage(
            tokenStatus: _status(), userEmail: 'a@b.c', userPhone: '1'),
        dark: true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('credits_pack_200')));
      await tester.pump();
      expect(find.text('Get 200 credits · ₹75'), findsOneWidget);

      await tester.tap(find.byKey(const Key('credits_buy_cta')));
      await tester.pump();

      verify(() => tokenBloc
              .add(const CreatePaymentOrder(tokenAmount: 200, rupeeAmount: 75)))
          .called(1);
    });
  });

  group('PricingPage (plans)', () {
    // The page clears pending promo codes from Hive when it is disposed.
    setUpAll(() => Hive.init(Directory.systemTemp.createTempSync().path));
    Widget pricing() => PricingPage(
          platformService: _FakePlatform(),
          dataSource: _FakeSubscriptionData(),
        );

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: plan cards and promo field',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(pricing(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('Choose your plan'), findsOneWidget);
        expect(find.text('Have a promo code?'), findsOneWidget);
        expect(find.byType(PricingCard), findsNWidgets(3));
        expect(find.text('₹149'), findsOneWidget);
        expect(find.text('Recommended'), findsOneWidget);
      });
    }

    for (final language in [AppLanguage.hindi, AppLanguage.malayalam]) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(pricing(), dark: false));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tapping a plan card calls its action; current plan does not',
        (tester) async {
      var taps = 0;
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ListView(
            children: [
              PricingCard(
                key: const Key('plus'),
                planName: 'Plus',
                price: '149',
                priceSubtext: '/mo',
                features: const ['10 memory verses'],
                buttonText: 'Get Started',
                onPressed: () => taps++,
              ),
              PricingCard(
                key: const Key('standard'),
                planName: 'Standard',
                price: '79',
                priceSubtext: '/mo',
                features: const [],
                buttonText: 'Get Started',
                isCurrentPlan: true,
                currentPlanLabel: 'Your current plan',
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('plus')));
      await tester.tap(find.byKey(const Key('standard')));
      expect(taps, 1);
      expect(find.text('Your current plan'), findsOneWidget);
    });

    testWidgets('promo Apply validates the typed code', (tester) async {
      final validated = <String>[];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PromoCodeInput(
            onPromoApplied: (_) {},
            onValidate: (code) async {
              validated.add(code);
              return null;
            },
          ),
        ),
      ));
      await tester.enterText(
          find.byKey(const Key('promo_code_field')), 'FAITH50');
      await tester.tap(find.byKey(const Key('promo_code_apply')));
      await tester.pumpAndSettle();
      expect(validated, ['FAITH50']);
    });
  });

  group('MyPlanPage', () {
    void withActiveSubscription() {
      final loaded = SubscriptionLoaded(
        activeSubscription: _subscription(),
        invoices: _invoices(),
        lastUpdated: DateTime(2026),
      );
      whenListen(
        subscriptionBloc,
        Stream<SubscriptionState>.fromIterable([loaded]),
        initialState: const SubscriptionInitial(),
      );
    }

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: plan card, billing, payments',
          (tester) async {
        withActiveSubscription();
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(const MyPlanPage(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('My Plan'), findsOneWidget);
        expect(find.text('Standard'), findsWidgets);
        expect(find.text('Active Subscription'), findsOneWidget);
        expect(find.text('Renews October 29, 2026'), findsOneWidget);
        expect(find.text('BILLING'), findsOneWidget);
        expect(find.text('₹79/month'), findsOneWidget);
        expect(find.text('Cancel plan'), findsOneWidget);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        withActiveSubscription();
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const MyPlanPage(), dark: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cancel sheet confirms with the same cycle-end event',
        (tester) async {
      withActiveSubscription();
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const MyPlanPage(), dark: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('my_plan_cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Keep studying until Oct 29?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel_confirm')));
      await tester.pumpAndSettle();

      verify(() => subscriptionBloc
          .add(const CancelSubscription(cancelAtCycleEnd: true))).called(1);
    });

    testWidgets('Keep plan dismisses without cancelling', (tester) async {
      withActiveSubscription();
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const MyPlanPage(), dark: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('my_plan_cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel_keep_plan')));
      await tester.pumpAndSettle();

      verifyNever(
          () => subscriptionBloc.add(any(that: isA<CancelSubscription>())));
    });
  });

  group('restored content', () {
    testWidgets('credits: refresh, balance status, plan description',
        (tester) async {
      useSurface(tester, const Size(390, 1600));
      await tester.pumpWidget(app(const TokenManagementPage(), dark: true));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Refresh'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(
          find.text('40 daily credits plus ability to purchase more. '
              'Best for group leaders.'),
          findsOneWidget);
      // The per-plan allowance table moved to the plans page.
      expect(find.text('Best for pastors and teachers'), findsNothing);

      await tester.tap(find.byKey(const Key('credits_refresh')));
      verify(() => tokenBloc.add(const RefreshTokenStatus()))
          .called(greaterThan(0));
    });

    for (final end in [null, DateTime(2027, 3, 31)]) {
      testWidgets(
          'credits: trial with ${end == null ? 'no' : 'a'} end date; '
          'one-line study costs', (tester) async {
        when(() => subscriptionBloc.state).thenReturn(SubscriptionLoaded(
          activeSubscription: Subscription(
            id: 't1',
            userId: 'u1',
            razorpaySubscriptionId: '',
            provider: 'trial',
            status: SubscriptionStatus.trial,
            planType: 'standard_trial',
            amountPaise: 0,
            currency: 'INR',
            currentPeriodEnd: end,
            paidCount: 0,
            cancelAtCycleEnd: false,
            createdAt: DateTime(2026, 10, 2),
            updatedAt: DateTime(2026, 10, 2),
          ),
          lastUpdated: DateTime(2026),
        ));
        useSurface(tester, const Size(390, 1600));
        await tester.pumpWidget(app(const TokenManagementPage(), dark: true));
        await tester.pumpAndSettle();

        // Never a made-up date: the pill and its line show only when the
        // trial row carries an end date, and never one without the other.
        expect(find.text('Free trial until Mar 31, 2027'),
            end == null ? findsNothing : findsOneWidget);
        expect(find.byKey(const Key('credits_trial_pill')),
            end == null ? findsNothing : findsOneWidget);
        expect(find.textContaining('Free until'), findsNothing);
        expect(find.textContaining('Quick Read from 10'), findsOneWidget);
        expect(find.textContaining('oken'), findsNothing);
      });
    }

    for (final pending in [false, true]) {
      testWidgets(
          'credits: the row arriving while credits still load is kept '
          '(${pending ? 'pending cancel' : 'renews'})', (tester) async {
        final tokens = StreamController<TokenState>();
        final subs = StreamController<SubscriptionState>();
        whenListen(tokenBloc, tokens.stream,
            initialState: const TokenLoading(operation: 'fetching'));
        whenListen(subscriptionBloc, subs.stream,
            initialState: const SubscriptionInitial());
        useSurface(tester, const Size(390, 1600));
        await tester.pumpWidget(app(const TokenManagementPage(), dark: true));
        await tester.pump();

        final row = Subscription(
          id: 's1',
          userId: 'u1',
          razorpaySubscriptionId: 'sub_1',
          status: pending
              ? SubscriptionStatus.pending_cancellation
              : SubscriptionStatus.active,
          planType: 'standard_monthly',
          amountPaise: 7900,
          currency: 'INR',
          currentPeriodEnd: DateTime(2026, 10, 29),
          nextBillingAt: DateTime(2026, 10, 29),
          paidCount: 2,
          cancelAtCycleEnd: pending,
          createdAt: DateTime(2026, 8, 29),
          updatedAt: DateTime(2026, 9, 29),
        );
        // Row, then the status call, both before the credits load.
        subs.add(SubscriptionLoaded(
            activeSubscription: row, lastUpdated: DateTime(2026)));
        await tester.pump();
        subs.add(UserSubscriptionStatusLoaded(
          subscriptionStatus: UserSubscriptionStatus(
            currentPlan: 'standard',
            isTrialActive: true,
            daysUntilTrialEnd: 200,
            hasSubscription: true,
            trialEndDate: DateTime.now().add(const Duration(days: 200)),
          ),
          lastUpdated: DateTime(2026),
        ));
        await tester.pump();
        tokens.add(
            TokenLoaded(tokenStatus: _status(), lastUpdated: DateTime(2026)));
        await tester.pumpAndSettle();

        expect(find.text('₹79/month · renews Oct 29'), findsOneWidget);
        expect(find.byKey(const Key('credits_trial_pill')), findsNothing);
        expect(find.textContaining('Free until'), findsNothing);
        if (pending) {
          expect(find.byType(LedgerNotice), findsOneWidget);
        }
        await tokens.close();
        await subs.close();
      });
    }

    testWidgets(
        'credits: a paying Standard subscriber gets no trial pill even while '
        'the global trial date is ahead', (tester) async {
      whenListen(
        subscriptionBloc,
        Stream<SubscriptionState>.fromIterable([
          SubscriptionLoaded(
            activeSubscription: _subscription(),
            lastUpdated: DateTime(2026),
          ),
          // get_subscription_status returns the same trial date to everyone.
          UserSubscriptionStatusLoaded(
            subscriptionStatus: UserSubscriptionStatus(
              currentPlan: 'standard',
              isTrialActive: true,
              daysUntilTrialEnd: 200,
              hasSubscription: true,
              trialEndDate: DateTime.now().add(const Duration(days: 200)),
            ),
            lastUpdated: DateTime(2026),
          ),
        ]),
        initialState: const SubscriptionInitial(),
      );
      useSurface(tester, const Size(390, 1600));
      await tester.pumpWidget(app(const TokenManagementPage(), dark: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('credits_trial_pill')), findsNothing);
      expect(find.textContaining('Free trial until'), findsNothing);
      expect(find.textContaining('Free until'), findsNothing);
      // The row survives the status call settling after it.
      expect(find.text('₹79/month · renews Oct 29'), findsOneWidget);
    });

    testWidgets('credits: low balance reads "Running Low"', (tester) async {
      when(() => tokenBloc.state).thenReturn(TokenLoaded(
          tokenStatus: TokenStatus(
            availableTokens: 4,
            purchasedTokens: 0,
            totalTokens: 4,
            dailyLimit: 40,
            totalConsumedToday: 36,
            userPlan: UserPlan.standard,
            lastReset: DateTime(2026, 9, 29),
            nextResetTime: _nextReset,
            authenticationType: AuthenticationType.authenticated,
            isPremium: false,
            unlimitedUsage: false,
            canPurchaseTokens: true,
            planDescription: '',
          ),
          lastUpdated: DateTime(2026)));
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const TokenManagementPage(), dark: false));
      await tester.pumpAndSettle();
      expect(find.text('Running Low'), findsOneWidget);
    });

    testWidgets('get credits: every rupee pack shows its price per credit',
        (tester) async {
      useSurface(tester, const Size(390, 1200));
      await tester.pumpWidget(app(
        TokenPurchasePage(
            tokenStatus: _status(), userEmail: 'a@b.c', userPhone: '1'),
        dark: true,
      ));
      await tester.pumpAndSettle();
      expect(find.text('40.0 paise/credit'), findsOneWidget); // 100 for ₹40
      expect(find.text('30.0 paise/credit'), findsOneWidget); // 1000 for ₹300
    });

    testWidgets('plans: each card spells out its action; promo has a label',
        (tester) async {
      Hive.init(Directory.systemTemp.createTempSync().path);
      useSurface(tester, const Size(390, 2400));
      await tester.pumpWidget(app(
        PricingPage(
          platformService: _FakePlatform(),
          dataSource: _FakeSubscriptionData(),
        ),
        dark: true,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsNWidgets(3));
      expect(find.text('Have a promo code?'), findsOneWidget);
      expect(find.text('Enter promo code'), findsOneWidget);
    });

    testWidgets('my plan: cancel explains cycle end; payments show the year',
        (tester) async {
      whenListen(
        subscriptionBloc,
        Stream<SubscriptionState>.fromIterable([
          SubscriptionLoaded(
            activeSubscription: _subscription(),
            invoices: _invoices(),
            lastUpdated: DateTime(2026),
          ),
        ]),
        initialState: const SubscriptionInitial(),
      );
      useSurface(tester, const Size(390, 1600));
      await tester.pumpWidget(app(const MyPlanPage(), dark: false));
      await tester.pumpAndSettle();
      expect(find.text('Cancel at period end'), findsOneWidget);
      expect(find.textContaining('Sep 29, 2026'), findsOneWidget);
    });

    Widget card(Widget child) => MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: ListView(children: [child])),
        );

    testWidgets('purchase summary: heading, average, first and last purchase',
        (tester) async {
      await tester.pumpWidget(card(PurchaseStatisticsCard(
        statistics: PurchaseStatistics(
          totalPurchases: 2,
          totalTokens: 150,
          totalSpent: 62,
          averagePurchaseAmount: 31,
          firstPurchaseDate: DateTime(2026, 8, 2),
          lastPurchaseDate: DateTime(2026, 9, 20),
        ),
      )));
      expect(find.text('PURCHASE SUMMARY'), findsOneWidget);
      expect(find.text('Average per Credit'), findsOneWidget);
      expect(find.text('₹0.41'), findsOneWidget);
      expect(find.text('Aug 2, 2026'), findsOneWidget);
      expect(find.text('Last Purchase'), findsOneWidget);
      expect(find.text('Sep 20, 2026'), findsOneWidget);
    });

    testWidgets('usage summary: daily / purchased split, most used, last use',
        (tester) async {
      await tester.pumpWidget(card(UsageStatisticsCard(
        statistics: UsageStatistics(
          totalTokens: 100,
          totalOperations: 10,
          dailyTokensConsumed: 75,
          purchasedTokensConsumed: 25,
          mostUsedFeature: 'study_generate',
          mostUsedLanguage: 'en',
          mostUsedMode: 'standard',
          featureBreakdown: const [],
          languageBreakdown: const [],
          studyModeBreakdown: const [],
          lastUsageDate: DateTime(2026, 9, 28),
        ),
      )));
      expect(find.text('75'), findsOneWidget);
      expect(find.text('Purchased · 25%'), findsOneWidget);
      expect(find.text('Feature'), findsOneWidget);
      expect(find.text('Study Generation'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Study Mode'), findsOneWidget);
      expect(find.text('Last Usage'), findsOneWidget);
      expect(find.text('Sep 28, 2026'), findsOneWidget);
    });

    testWidgets('button pair stacks when a label would not fit at half width',
        (tester) async {
      await loadAppFonts();
      Widget pair(double width, String second) => MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: LedgerButtonPair(
                    labels: ['Get credits', second],
                    first: LedgerPrimaryButton(
                        key: const Key('a'),
                        label: 'Get credits',
                        icon: Icons.add,
                        onPressed: () {}),
                    second: LedgerSecondaryButton(
                        key: const Key('b'),
                        label: second,
                        icon: Icons.add,
                        onPressed: () {}),
                  ),
                ),
              ),
            ),
          );
      await tester.pumpWidget(pair(358, 'Upgrade'));
      expect(tester.getTopLeft(find.byKey(const Key('a'))).dy,
          tester.getTopLeft(find.byKey(const Key('b'))).dy);

      await tester.pumpWidget(pair(288, 'Upgrade to Premium'));
      expect(tester.getTopLeft(find.byKey(const Key('b'))).dy,
          greaterThan(tester.getTopLeft(find.byKey(const Key('a'))).dy));
      expectNoTruncatedText(tester);
    });
  });

  // Tall surfaces so every row of the list is laid out; only the width
  // matters for wrapping.
  group('no cut-off text at 320px', () {
    setUpAll(() async {
      Hive.init(Directory.systemTemp.createTempSync().path);
      await loadAppFonts();
    });

    for (final language in AppLanguage.values) {
      testWidgets('credits ${language.code}', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 2000));
        await tester.pumpWidget(app(const TokenManagementPage(), dark: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });

      testWidgets('get credits ${language.code}', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 2000));
        await tester.pumpWidget(app(
          TokenPurchasePage(
              tokenStatus: _status(), userEmail: 'a@b.c', userPhone: '1'),
          dark: true,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });

      testWidgets('plans ${language.code}', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 3000));
        await tester.pumpWidget(app(
          PricingPage(
            platformService: _FakePlatform(),
            dataSource: _FakeSubscriptionData(),
          ),
          dark: false,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });

      testWidgets('my plan ${language.code}', (tester) async {
        translations.language = language;
        whenListen(
          subscriptionBloc,
          Stream<SubscriptionState>.fromIterable([
            SubscriptionLoaded(
              activeSubscription: _subscription(),
              invoices: _invoices(),
              lastUpdated: DateTime(2026),
            ),
          ]),
          initialState: const SubscriptionInitial(),
        );
        useSurface(tester, const Size(320, 2000));
        await tester.pumpWidget(app(const MyPlanPage(), dark: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester);
      });
    }
  });
}
