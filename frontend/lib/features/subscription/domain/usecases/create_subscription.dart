import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Use case for creating a new premium subscription.
///
/// This use case creates a Razorpay subscription and returns an authorization URL
/// for the user to complete payment setup.
///
/// Returns either a [Failure] if the operation fails, or a [CreateSubscriptionResult]
/// containing subscription details and payment authorization URL.
class CreateSubscription
    implements UseCase<CreateSubscriptionResult, NoParams> {
  final SubscriptionRepository _repository;

  const CreateSubscription(this._repository);

  /// Executes the use case to create a new subscription.
  ///
  /// Returns [Either<Failure, CreateSubscriptionResult>] where:
  /// - [Left] contains a [Failure] if the operation fails
  /// - [Right] contains [CreateSubscriptionResult] with subscription details and payment URL
  @override
  Future<Either<Failure, CreateSubscriptionResult>> call(
      NoParams params) async {
    return await _repository.createSubscription();
  }
}
