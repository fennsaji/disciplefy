import 'package:dartz/dartz.dart';

import '../../../../core/cache/user_scoped_cache.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/user_subscription_status.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../../tokens/domain/token_balance_changes.dart';
import '../datasources/subscription_remote_data_source.dart';
import '../models/subscription_model.dart';

/// Implementation of SubscriptionRepository that handles data operations.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final UserScopedCache? _cacheOverride;

  const SubscriptionRepositoryImpl({
    required SubscriptionRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    UserScopedCache? cache,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo,
        _cacheOverride = cache;

  UserScopedCache get _cache => _cacheOverride ?? UserScopedCache.instance;

  /// Generic error handler that converts exceptions to failures.
  ///
  /// [changesPlan] marks operations that may change the user's plan: cached
  /// plan data is dropped before (so in-flight reads are discarded) and after.
  Future<Either<Failure, T>> _execute<T>(
    Future<T> Function() operation,
    String operationName, {
    bool changesPlan = false,
  }) async {
    if (await _networkInfo.isConnected) {
      try {
        if (changesPlan) await _dropPlanCaches();
        final T result;
        try {
          result = await operation();
        } finally {
          if (changesPlan) await invalidateCachedPlanData();
        }
        return Right(result);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, code: e.code));
      } on AuthenticationException catch (e) {
        return Left(AuthenticationFailure(message: e.message, code: e.code));
      } on ClientException catch (e) {
        return Left(ClientFailure(message: e.message, code: e.code));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ClientFailure(
          message: 'An unexpected error occurred during $operationName',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, CreateSubscriptionResult>> createSubscription() async {
    return _execute<CreateSubscriptionResult>(
      () async {
        final response = await _remoteDataSource.createSubscription();
        // Model already extends entity, so we can return it directly
        return response;
      },
      'subscription creation',
      changesPlan: true,
    );
  }

  @override
  Future<Either<Failure, CancelSubscriptionResult>> cancelSubscription({
    required bool cancelAtCycleEnd,
    String? reason,
  }) async {
    return _execute<CancelSubscriptionResult>(
      () async {
        final response = await _remoteDataSource.cancelSubscription(
          cancelAtCycleEnd: cancelAtCycleEnd,
          reason: reason,
        );
        // Model already extends entity, so we can return it directly
        return response;
      },
      'subscription cancellation',
      changesPlan: true,
    );
  }

  @override
  Future<Either<Failure, ResumeSubscriptionResult>> resumeSubscription() async {
    return _execute<ResumeSubscriptionResult>(
      () async {
        final response = await _remoteDataSource.resumeSubscription();
        // Convert model to entity
        return ResumeSubscriptionResult(
          success: response.success,
          subscriptionId: response.subscriptionId,
          status: SubscriptionStatus.values.firstWhere(
            (e) => e.name == response.status,
            orElse: () => SubscriptionStatus.active,
          ),
          resumedAt: DateTime.parse(response.resumedAt),
          message: response.message,
        );
      },
      'subscription resumption',
      changesPlan: true,
    );
  }

  @override
  Future<Either<Failure, Subscription?>> getActiveSubscription() async {
    return _execute<Subscription?>(
      () async {
        final ticket = _cache.ticket(UserScopedCache.activeSubscription);
        final subscription = await _remoteDataSource.getActiveSubscription();
        await _cache.write(ticket, UserScopedCache.activeSubscription,
            {'subscription': subscription?.toJson()});
        // Model already extends entity, so we can return it directly
        return subscription;
      },
      'active subscription fetch',
    );
  }

  @override
  Future<Either<Failure, List<Subscription>>> getSubscriptionHistory() async {
    return _execute<List<Subscription>>(
      () async {
        final subscriptions = await _remoteDataSource.getSubscriptionHistory();
        // Models already extend entities, so we can return them directly
        return subscriptions;
      },
      'subscription history fetch',
    );
  }

  @override
  Future<Either<Failure, List<SubscriptionInvoice>>> getInvoices({
    int? limit,
    int? offset,
  }) async {
    return _execute<List<SubscriptionInvoice>>(
      () async {
        final invoices = await _remoteDataSource.getInvoices(
          limit: limit,
          offset: offset,
        );
        // Models already extend entities, so we can return them directly
        return invoices;
      },
      'subscription invoices fetch',
    );
  }

  @override
  Future<Either<Failure, UserSubscriptionStatus>>
      getSubscriptionStatus() async {
    return _execute<UserSubscriptionStatus>(
      () async {
        final ticket = _cache.ticket(UserScopedCache.subscriptionStatus);
        final status = await _remoteDataSource.getSubscriptionStatus();
        await _cache.write(
            ticket, UserScopedCache.subscriptionStatus, status.toJson());
        return status;
      },
      'subscription status fetch',
    );
  }

  @override
  Future<({Subscription? subscription})?> getCachedActiveSubscription() async {
    final cached = await _cache.read(UserScopedCache.activeSubscription);
    if (cached is! Map<String, dynamic>) return null;
    final json = cached['subscription'];
    if (json == null) return (subscription: null);
    if (json is! Map<String, dynamic>) return null;
    try {
      return (subscription: SubscriptionModel.fromJson(json));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserSubscriptionStatus?> getCachedSubscriptionStatus() async {
    final cached = await _cache.read(UserScopedCache.subscriptionStatus);
    if (cached is! Map<String, dynamic>) return null;
    try {
      return UserSubscriptionStatus.fromJson(cached);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> invalidateCachedPlanData() async {
    await _dropPlanCaches();
    TokenBalanceChanges.instance.notifyChanged();
  }

  Future<void> _dropPlanCaches() async {
    await Future.wait([
      _cache.invalidate(UserScopedCache.activeSubscription),
      _cache.invalidate(UserScopedCache.subscriptionStatus),
      _cache.invalidate(UserScopedCache.tokenStatus),
      _cache.invalidate(UserScopedCache.usageStats),
    ]);
  }

  @override
  Future<Either<Failure, CreateSubscriptionResult>>
      createStandardSubscription() async {
    return _execute<CreateSubscriptionResult>(
      () async {
        final response = await _remoteDataSource.createStandardSubscription();
        // Model already extends entity, so we can return it directly
        return response;
      },
      'standard subscription creation',
      changesPlan: true,
    );
  }

  @override
  Future<Either<Failure, CreateSubscriptionResult>>
      createPlusSubscription() async {
    return _execute<CreateSubscriptionResult>(
      () async {
        final response = await _remoteDataSource.createPlusSubscription();
        // Model already extends entity, so we can return it directly
        return response;
      },
      'plus subscription creation',
      changesPlan: true,
    );
  }

  @override
  Future<Either<Failure, StartPremiumTrialResult>> startPremiumTrial() async {
    return _execute<StartPremiumTrialResult>(
      () async {
        final response = await _remoteDataSource.startPremiumTrial();
        return StartPremiumTrialResult(
          trialStartedAt: response.trialStartedAt,
          trialEndAt: response.trialEndAt,
          daysRemaining: response.daysRemaining,
          message: response.message,
        );
      },
      'premium trial start',
      changesPlan: true,
    );
  }

  @override
  Future<Either<Failure, CreateSubscriptionV2Result>> createSubscriptionV2({
    required String planCode,
    required String provider,
    String? region,
    String? promoCode,
    String? receipt,
  }) async {
    return _execute<CreateSubscriptionV2Result>(
      () async {
        final response = await _remoteDataSource.createSubscriptionV2(
          planCode: planCode,
          provider: provider,
          region: region,
          promoCode: promoCode,
          receipt: receipt,
        );

        return CreateSubscriptionV2Result(
          success: response.success,
          subscriptionId: response.subscriptionId,
          providerSubscriptionId: response.providerSubscriptionId,
          authorizationUrl: response.authorizationUrl,
          status: response.status,
        );
      },
      'subscription creation v2',
      changesPlan: true,
    );
  }

  @override
  Future<Either<Failure, SyncPlayStoreResult>> syncPlayStoreStatus({
    required String provider,
    required List<Map<String, dynamic>> purchases,
    required bool deviceHasNoPurchases,
  }) async {
    return _execute<SyncPlayStoreResult>(
      () async {
        final response = await _remoteDataSource.syncPlayStoreStatus(
          provider: provider,
          purchases: purchases,
          deviceHasNoPurchases: deviceHasNoPurchases,
        );
        return SyncPlayStoreResult(
          success: response.success,
          actionTaken: response.actionTaken,
          newStatus: response.newStatus,
          subscriptionId: response.subscriptionId,
        );
      },
      'play store sync',
      changesPlan: true,
    );
  }
}
