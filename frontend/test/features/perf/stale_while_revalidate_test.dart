import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/cache/user_scoped_cache.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/network/network_info.dart';
import 'package:disciplefy_bible_study/core/usecases/usecase.dart';
import 'package:disciplefy_bible_study/features/community/data/datasources/community_remote_datasource.dart';
import 'package:disciplefy_bible_study/features/community/data/models/current_study_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/fellowship_model.dart';
import 'package:disciplefy_bible_study/features/community/data/models/public_fellowship_model.dart';
import 'package:disciplefy_bible_study/features/community/data/repositories/community_repository_impl.dart';
import 'package:disciplefy_bible_study/features/subscription/data/datasources/subscription_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/subscription/data/datasources/usage_stats_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/subscription/data/models/subscription_model.dart';
import 'package:disciplefy_bible_study/features/subscription/data/models/usage_stats_model.dart';
import 'package:disciplefy_bible_study/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:disciplefy_bible_study/features/subscription/data/repositories/usage_stats_repository_impl.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/usage_stats.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/usage_stats_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/usage_stats_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/usage_stats_state.dart';
import 'package:disciplefy_bible_study/features/tokens/data/datasources/token_remote_data_source.dart';
import 'package:disciplefy_bible_study/features/tokens/data/models/token_status_model.dart';
import 'package:disciplefy_bible_study/features/tokens/data/repositories/token_repository_impl.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/token_balance_changes.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/usecases/confirm_payment.dart'
    as confirm_payment;
import 'package:disciplefy_bible_study/features/tokens/domain/usecases/create_payment_order.dart'
    as create_payment_order;
import 'package:disciplefy_bible_study/features/tokens/domain/usecases/get_purchase_history.dart'
    as get_purchase_history;
import 'package:disciplefy_bible_study/features/tokens/domain/usecases/get_purchase_statistics.dart'
    as get_purchase_statistics;
import 'package:disciplefy_bible_study/features/tokens/domain/usecases/get_token_status.dart'
    as usecase;
import 'package:disciplefy_bible_study/features/tokens/domain/usecases/get_usage_history.dart'
    as get_usage_history;
import 'package:disciplefy_bible_study/features/tokens/domain/usecases/get_usage_statistics.dart'
    as get_usage_statistics;
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockTokenDs extends Mock implements TokenRemoteDataSource {}

class _MockUsageDs extends Mock implements UsageStatsRemoteDataSource {}

class _MockSubscriptionDs extends Mock
    implements SubscriptionRemoteDataSource {}

class _MockCommunityDs extends Mock implements CommunityRemoteDatasource {}

class _MockGetTokenStatus extends Mock implements usecase.GetTokenStatus {}

class _MockCreateOrder extends Mock
    implements create_payment_order.CreatePaymentOrder {}

class _MockConfirm extends Mock implements confirm_payment.ConfirmPayment {}

class _MockPurchaseHistory extends Mock
    implements get_purchase_history.GetPurchaseHistory {}

class _MockPurchaseStats extends Mock
    implements get_purchase_statistics.GetPurchaseStatistics {}

class _MockUsageHistory extends Mock
    implements get_usage_history.GetUsageHistory {}

class _MockUsageStatistics extends Mock
    implements get_usage_statistics.GetUsageStatistics {}

TokenStatusModel _tokens(int total) => TokenStatusModel(
      availableTokens: total,
      purchasedTokens: 0,
      totalTokens: total,
      dailyLimit: 20,
      totalConsumedToday: 0,
      userPlan: UserPlan.free,
      lastReset: DateTime.utc(2026, 9, 30),
      nextResetTime: DateTime.utc(2026, 10),
      authenticationType: AuthenticationType.authenticated,
      isPremium: false,
      unlimitedUsage: false,
      canPurchaseTokens: false,
      planDescription: 'Free',
    );

const _usage = UsageStatsModel(
  tokensUsed: 10,
  tokensTotal: 100,
  tokensRemaining: 90,
  percentage: 10,
  streakDays: 3,
  currentPlan: 'free',
  isUnlimited: false,
  thresholdState: ThresholdState.normal,
  monthYear: '2026-09',
);

FellowshipModel _fellowship(String id) => FellowshipModel(
      id: id,
      name: 'F$id',
      memberCount: 2,
      userRole: 'mentor',
      joinedAt: '2026-01-01T00:00:00Z',
      createdAt: '2026-01-01T00:00:00Z',
      currentStudy: const CurrentStudyModel(
        learningPathId: 'lp',
        learningPathTitle: 'John',
        currentGuideIndex: 1,
        startedAt: '2026-01-02T00:00:00Z',
      ),
    );

void main() {
  late String? userId;
  late UserScopedCache cache;

  setUpAll(() => registerFallbackValue(NoParams()));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    userId = 'user-a';
    cache = UserScopedCache(currentUserId: () => userId);
  });

  group('token status', () {
    late _MockTokenDs ds;
    late TokenRepositoryImpl repo;
    late _MockGetTokenStatus getStatus;

    TokenBloc bloc() => TokenBloc(
          getTokenStatus: getStatus,
          createPaymentOrder: _MockCreateOrder(),
          confirmPayment: _MockConfirm(),
          getPurchaseHistory: _MockPurchaseHistory(),
          getPurchaseStatistics: _MockPurchaseStats(),
          getUsageHistory: _MockUsageHistory(),
          getUsageStatistics: _MockUsageStatistics(),
          tokenRepository: repo,
          currentUserId: () => userId,
        );

    setUp(() {
      ds = _MockTokenDs();
      repo = TokenRepositoryImpl(
          remoteDataSource: ds, networkInfo: _Online(), cache: cache);
      getStatus = _MockGetTokenStatus();
      when(() => getStatus(any())).thenAnswer((_) => repo.getTokenStatus());
    });

    test('repository persists the balance per user', () async {
      when(() => ds.getTokenStatus()).thenAnswer((_) async => _tokens(42));
      await repo.getTokenStatus();
      expect((await repo.getCachedTokenStatus())?.totalTokens, 42);
      userId = 'user-b';
      expect(await repo.getCachedTokenStatus(), isNull);
    });

    test('shows the persisted balance at once, then the fresh one', () async {
      when(() => ds.getTokenStatus()).thenAnswer((_) async => _tokens(42));
      await repo.getTokenStatus();

      final fresh = Completer<TokenStatusModel>();
      when(() => ds.getTokenStatus()).thenAnswer((_) => fresh.future);
      final b = bloc();
      final states = <TokenState>[];
      final sub = b.stream.listen(states.add);
      b.add(const GetTokenStatus());
      await pumpEventQueue();

      expect(states.single, isA<TokenLoaded>());
      final cached = states.single as TokenLoaded;
      expect(cached.tokenStatus.totalTokens, 42);
      expect(cached.isRefreshing, isTrue);

      fresh.complete(_tokens(37));
      await pumpEventQueue();
      final last = states.last as TokenLoaded;
      expect(last.tokenStatus.totalTokens, 37);
      expect(last.isRefreshing, isFalse);
      await sub.cancel();
      await b.close();
    });

    test('a balance change (tokens spent) drops the cache and refetches',
        () async {
      when(() => ds.getTokenStatus()).thenAnswer((_) async => _tokens(42));
      final b = bloc();
      b.add(const GetTokenStatus());
      await pumpEventQueue();
      verify(() => ds.getTokenStatus()).called(1);

      when(() => ds.getTokenStatus()).thenAnswer((_) async => _tokens(37));
      TokenBalanceChanges.instance.notifyChanged();
      await pumpEventQueue();
      verify(() => ds.getTokenStatus()).called(1);
      expect((b.state as TokenLoaded).tokenStatus.totalTokens, 37);
      await b.close();
    });

    test('in-memory balance is not reused for another user', () async {
      when(() => ds.getTokenStatus()).thenAnswer((_) async => _tokens(42));
      final b = bloc();
      b.add(const GetTokenStatus());
      await pumpEventQueue();

      userId = 'user-b';
      final fresh = Completer<TokenStatusModel>();
      when(() => ds.getTokenStatus()).thenAnswer((_) => fresh.future);
      final states = <TokenState>[];
      final sub = b.stream.listen(states.add);
      b.add(const GetTokenStatus());
      await pumpEventQueue();
      expect(states.single, isA<TokenLoading>());
      fresh.complete(_tokens(5));
      await pumpEventQueue();
      expect((states.last as TokenLoaded).tokenStatus.totalTokens, 5);
      await sub.cancel();
      await b.close();
    });
  });

  group('usage stats', () {
    test('emits cached stats (marked cached) then fresh ones', () async {
      final ds = _MockUsageDs();
      final repo = UsageStatsRepositoryImpl(remoteDataSource: ds, cache: cache);
      when(() => ds.getUserUsageStats()).thenAnswer((_) async => _usage);
      await repo.getUserUsageStats();

      final b = UsageStatsBloc(repository: repo);
      final states = <UsageStatsState>[];
      final sub = b.stream.listen(states.add);
      b.add(const FetchUsageStats());
      await pumpEventQueue();
      expect(states.length, 2);
      expect((states.first as UsageStatsLoaded).isCached, isTrue);
      expect((states.last as UsageStatsLoaded).isCached, isFalse);
      await sub.cancel();
      await b.close();
    });

    test('shows loading (not another user\'s stats) for a new user', () async {
      final ds = _MockUsageDs();
      final repo = UsageStatsRepositoryImpl(remoteDataSource: ds, cache: cache);
      when(() => ds.getUserUsageStats()).thenAnswer((_) async => _usage);
      await repo.getUserUsageStats();
      userId = 'user-b';

      final b = UsageStatsBloc(repository: repo);
      final states = <UsageStatsState>[];
      final sub = b.stream.listen(states.add);
      b.add(const FetchUsageStats());
      await pumpEventQueue();
      expect(states.first, isA<UsageStatsLoading>());
      await sub.cancel();
      await b.close();
    });
  });

  group('subscription', () {
    test('caches the active subscription and drops plan data on a change',
        () async {
      final ds = _MockSubscriptionDs();
      final repo = SubscriptionRepositoryImpl(
          remoteDataSource: ds, networkInfo: _Online(), cache: cache);
      final sub = SubscriptionModel.fromJson({
        'id': 's1',
        'user_id': 'user-a',
        'provider': 'google_play',
        'status': 'active',
        'plan_type': 'plus',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      when(() => ds.getActiveSubscription()).thenAnswer((_) async => sub);
      await repo.getActiveSubscription();
      final cached = await repo.getCachedActiveSubscription();
      expect(cached?.subscription?.id, 's1');
      expect(cached?.subscription?.provider, 'google_play');

      // A cached "no subscription" is distinguishable from a miss.
      when(() => ds.getActiveSubscription()).thenAnswer((_) async => null);
      await repo.getActiveSubscription();
      final none = await repo.getCachedActiveSubscription();
      expect(none, isNotNull);
      expect(none!.subscription, isNull);

      await cache.write(cache.ticket(UserScopedCache.tokenStatus),
          UserScopedCache.tokenStatus, {'x': 1});
      var ticks = 0;
      void onTick() => ticks++;
      TokenBalanceChanges.instance.addListener(onTick);
      await repo.invalidateCachedPlanData();
      TokenBalanceChanges.instance.removeListener(onTick);
      expect(await repo.getCachedActiveSubscription(), isNull);
      expect(await cache.read(UserScopedCache.tokenStatus), isNull);
      expect(ticks, 1);
    });
  });

  group('fellowships', () {
    late _MockCommunityDs ds;
    late CommunityRepositoryImpl repo;

    setUp(() {
      ds = _MockCommunityDs();
      repo = CommunityRepositoryImpl(datasource: ds, cache: cache);
    });

    test('list is persisted per user and language and round-trips', () async {
      when(() => ds.getFellowships('en'))
          .thenAnswer((_) async => [_fellowship('1')]);
      await repo.getFellowships('en');
      final cached = await repo.getCachedFellowships('en');
      expect(cached!.single.id, '1');
      expect(cached.single.currentStudy?.learningPathTitle, 'John');
      expect(cached.single.userRole, 'mentor');
      expect(await repo.getCachedFellowships('hi'), isNull);
      userId = 'user-b';
      expect(await repo.getCachedFellowships('en'), isNull);
    });

    test('join and leave invalidate the list and discover cache', () async {
      when(() => ds.getFellowships('en'))
          .thenAnswer((_) async => [_fellowship('1')]);
      when(() => ds.discoverFellowships(
            language: any(named: 'language'),
            search: any(named: 'search'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => (
            fellowships: [
              const PublicFellowshipModel(
                  id: 'p',
                  name: 'P',
                  language: 'en',
                  memberCount: 1,
                  maxMembers: null)
            ],
            hasMore: true,
            nextCursor: 'c',
          ));
      when(() => ds.joinPublicFellowship('p')).thenAnswer((_) async => 'P');
      when(() => ds.leaveFellowship('1')).thenAnswer((_) async {});

      await repo.getFellowships('en');
      await repo.discoverFellowships(language: 'en');
      expect(
          (await repo.getCachedDiscoverFellowships(language: 'en'))
              ?.fellowships
              .single
              .id,
          'p');

      await repo.joinPublicFellowship('p');
      expect(await repo.getCachedFellowships('en'), isNull);
      expect(await repo.getCachedDiscoverFellowships(language: 'en'), isNull);

      await repo.getFellowships('en');
      await repo.leaveFellowship('1');
      expect(await repo.getCachedFellowships('en'), isNull);
    });

    test('searched or paged discover results are not persisted', () async {
      when(() => ds.discoverFellowships(
            language: any(named: 'language'),
            search: any(named: 'search'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => (
            fellowships: <PublicFellowshipModel>[],
            hasMore: false,
            nextCursor: null,
          ));
      await repo.discoverFellowships(language: 'en', search: 'john');
      await repo.discoverFellowships(language: 'en', cursor: 'c');
      expect(await repo.getCachedDiscoverFellowships(language: 'en'), isNull);
    });

    test('failure is not cached and does not clear the last good list',
        () async {
      when(() => ds.getFellowships('en'))
          .thenAnswer((_) async => [_fellowship('1')]);
      await repo.getFellowships('en');
      when(() => ds.getFellowships('en')).thenThrow(Exception('offline'));
      final result = await repo.getFellowships('en');
      expect(result.isLeft(), isTrue);
      expect((await repo.getCachedFellowships('en'))!.single.id, '1');
    });
  });

  test('failure type is preserved for token status', () async {
    final ds = _MockTokenDs();
    final repo = TokenRepositoryImpl(
        remoteDataSource: ds, networkInfo: _Online(), cache: cache);
    when(() => ds.getTokenStatus()).thenThrow(Exception('x'));
    final r = await repo.getTokenStatus();
    expect(r.fold((f) => f, (_) => null), isA<Failure>());
    expect(await repo.getCachedTokenStatus(), isNull);
  });
}
