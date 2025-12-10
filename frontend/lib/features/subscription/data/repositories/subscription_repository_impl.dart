import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/user_subscription_status.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_data_source.dart';

/// Implementation of SubscriptionRepository that handles data operations.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  const SubscriptionRepositoryImpl({
    required SubscriptionRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  /// Generic error handler that converts exceptions to failures
  Future<Either<Failure, T>> _execute<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    if (await _networkInfo.isConnected) {
      try {
        final result = await operation();
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
    );
  }

  @override
  Future<Either<Failure, Subscription?>> getActiveSubscription() async {
    return _execute<Subscription?>(
      () async {
        final subscription = await _remoteDataSource.getActiveSubscription();
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
        return await _remoteDataSource.getSubscriptionStatus();
      },
      'subscription status fetch',
    );
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
    );
  }
}
