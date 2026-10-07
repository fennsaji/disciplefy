import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart' as mt;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/widgets/locked_feature_wrapper.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';

class _Lang extends Fake implements LanguagePreferenceService {
  @override
  Stream<AppLanguage> get languageChanges => const Stream.empty();
  @override
  Future<AppLanguage> getSelectedLanguage() async => AppLanguage.english;
}

/// `voice_buddy` is a lock-mode feature available to paid plans only.
class _Config extends Fake implements SystemConfigService {
  static const _plans = ['standard', 'plus', 'premium'];
  @override
  bool hasFeatureAccess(String featureKey, String planType) =>
      _plans.contains(planType);
  @override
  bool isFeatureLocked(String featureKey, String planType) =>
      !_plans.contains(planType);
  @override
  bool shouldHideFeature(String featureKey, String planType) => false;
  @override
  List<String> getRequiredPlans(String featureKey) => _plans;
  @override
  String? getUpgradePlan(String featureKey, String currentPlan) => 'standard';
}

class _MockConnectivity extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _MockToken extends MockBloc<TokenEvent, TokenState>
    implements TokenBloc {}

TokenStatus _status(UserPlan plan) => TokenStatus(
      availableTokens: 2,
      purchasedTokens: 0,
      totalTokens: 2,
      dailyLimit: 15,
      totalConsumedToday: 0,
      userPlan: plan,
      lastReset: DateTime(2026, 9, 29),
      nextResetTime: DateTime(2026, 9, 30),
      authenticationType: AuthenticationType.authenticated,
      isPremium: plan != UserPlan.free,
      unlimitedUsage: false,
      canPurchaseTokens: true,
      planDescription: plan.name,
    );

class _MockGuest extends mt.Mock implements GuestSessionService {}

class _MockFlags extends mt.Mock implements RolloutFlags {}

const _offlineFailure = NetworkFailure(message: 'offline', code: 'NO_INTERNET');

void main() {
  late TranslationService translations;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final lang = _Lang();
    translations = TranslationService(lang, prefs);
    GetIt.instance
      ..registerSingleton<TranslationService>(translations)
      ..registerSingleton<LanguagePreferenceService>(lang)
      ..registerSingleton<SystemConfigService>(_Config());
  });
  tearDown(() => GetIt.instance.reset());

  Future<void> pump(WidgetTester tester, TokenState token,
      {bool offline = true}) async {
    final connectivity = _MockConnectivity();
    final tokens = _MockToken();
    whenListen(connectivity, const Stream<ConnectivityState>.empty(),
        initialState: offline ? ConnectivityOffline() : ConnectivityOnline());
    whenListen(tokens, const Stream<TokenState>.empty(), initialState: token);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<ConnectivityBloc>.value(value: connectivity),
            BlocProvider<TokenBloc>.value(value: tokens),
          ],
          child: const LockedFeatureWrapper(
            featureKey: 'voice_buddy',
            child: Text('Listen'),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  String tr(String key) => translations.getTranslation(key);

  testWidgets('offline with a cached paid plan stays unlocked', (tester) async {
    await pump(
      tester,
      TokenError(
        failure: _offlineFailure,
        previousTokenStatus: _status(UserPlan.plus),
      ),
    );
    expect(find.text('Listen'), findsOneWidget);
    expect(find.byType(LockedFeatureScrim), findsNothing);
  });

  testWidgets('offline with no cached plan shows the offline treatment',
      (tester) async {
    await pump(tester, const TokenError(failure: _offlineFailure));
    expect(find.text(tr(TranslationKeys.appChromeLockNotAvailableOffline)),
        findsOneWidget);
    expect(
        find.text(tr(TranslationKeys.appChromeLockTapToUpgrade)), findsNothing);
  });

  testWidgets('free plan online stays locked', (tester) async {
    await pump(
      tester,
      TokenLoaded(
          tokenStatus: _status(UserPlan.free), lastUpdated: DateTime(2026)),
      offline: false,
    );
    expect(find.text(tr(TranslationKeys.appChromeLockTapToUpgrade)),
        findsOneWidget);
  });

  test('knownPlanName reads the plan kept by a failed refresh', () {
    expect(
        TokenError(
          failure: _offlineFailure,
          previousTokenStatus: _status(UserPlan.premium),
        ).knownPlanName,
        'premium');
    expect(const TokenInitial().knownPlanName, isNull);
  });

  // A guest cannot buy a plan (pricing needs an account): tapping a
  // plan-locked feature asks for an account first, not the plan choice.
  testWidgets('a guest tapping a locked feature gets the account sheet',
      (tester) async {
    final guest = _MockGuest();
    final flags = _MockFlags();
    mt.when(() => guest.isGuest).thenReturn(true);
    mt.when(() => flags.guestMode).thenReturn(true);
    GetIt.instance
      ..registerSingleton<GuestSessionService>(guest)
      ..registerSingleton<RolloutFlags>(flags);
    await pump(
      tester,
      TokenLoaded(
          tokenStatus: _status(UserPlan.free), lastUpdated: DateTime(2026)),
      offline: false,
    );
    await tester.tap(find.text(tr(TranslationKeys.appChromeLockTapToUpgrade)));
    await tester.pumpAndSettle();
    expect(find.text(tr(TranslationKeys.accountGenericTitle)), findsOneWidget);
  });
}
