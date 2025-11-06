import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Use case for fetching the user's active subscription.
///
/// This use case retrieves the current active subscription for the authenticated user.
/// Returns null if the user has no active subscription.
///
/// Returns either a [Failure] if the operation fails, or a [Subscription] entity
/// (or null if no active subscription exists).
class GetActiveSubscription implements UseCase<Subscription?, NoParams> {
  final SubscriptionRepository _repository;

  const GetActiveSubscription(this._repository);

  /// Executes the use case to get active subscription.
  ///
  /// Returns [Either<Failure, Subscription?>] where:
  /// - [Left] contains a [Failure] if the operation fails
  /// - [Right] contains [Subscription] if active, or null if no active subscription
  @override
  Future<Either<Failure, Subscription?>> call(NoParams params) async {
    return await _repository.getActiveSubscription();
  }
}
