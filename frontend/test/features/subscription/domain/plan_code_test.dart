import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/subscription/domain/utils/plan_code.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';

void main() {
  test('normalizePlanCode', () {
    expect(normalizePlanCode('standard_trial'), 'standard');
    expect(normalizePlanCode('standard_monthly'), 'standard');
    expect(normalizePlanCode('standard_yearly'), 'standard');
    expect(normalizePlanCode('premium_monthly'), 'premium');
    expect(normalizePlanCode('plus_yearly'), 'plus');
    expect(normalizePlanCode('free'), 'free');
    expect(normalizePlanCode('weird'), 'free');
    expect(normalizePlanCode(''), 'free');
  });

  test('providerLabelOrNull hides non-store providers', () {
    expect(providerLabelOrNull('trial'), isNull);
    expect(providerLabelOrNull('system'), isNull);
    expect(providerLabelOrNull('free'), isNull);
    expect(providerLabelOrNull(''), isNull);
    expect(providerLabelOrNull('razorpay'), 'Razorpay');
    expect(providerLabelOrNull('google_play'), 'Google Play');
    expect(providerLabelOrNull('apple_appstore'), 'App Store');
    expect(providerLabelOrNull('app_store'), 'App Store');
    expect(providerLabelOrNull('apple'), 'App Store');
  });

  test('currentPlanCode reads TokenBloc, free until loaded', () {
    expect(currentPlanCode(const TokenInitial()), 'free');
    final loaded = TokenLoaded(
      tokenStatus: TokenStatus(
        availableTokens: 30,
        purchasedTokens: 0,
        totalTokens: 30,
        dailyLimit: 40,
        totalConsumedToday: 10,
        userPlan: UserPlan.standard,
        lastReset: DateTime(2026, 10, 6),
        nextResetTime: DateTime(2026, 10, 7),
        authenticationType: AuthenticationType.authenticated,
        isPremium: false,
        unlimitedUsage: false,
        canPurchaseTokens: true,
        planDescription: '',
      ),
      lastUpdated: DateTime(2026, 10, 6),
    );
    expect(currentPlanCode(loaded), 'standard');
  });
}
