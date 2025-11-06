import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Use case for fetching subscription history.
///
/// This use case retrieves all subscriptions (active and historical) for the
/// authenticated user, ordered by creation date (newest first).
///
/// Returns either a [Failure] if the operation fails, or a list of [Subscription] entities.
class GetSubscriptionHistory implements UseCase<List<Subscription>, NoParams> {
  final SubscriptionRepository _repository;

  const GetSubscriptionHistory(this._repository);

  /// Executes the use case to get subscription history.
  ///
  /// Returns [Either<Failure, List<Subscription>>] where:
  /// - [Left] contains a [Failure] if the operation fails
  /// - [Right] contains list of [Subscription] ordered by creation date
  @override
  Future<Either<Failure, List<Subscription>>> call(NoParams params) async {
    return await _repository.getSubscriptionHistory();
  }
}
