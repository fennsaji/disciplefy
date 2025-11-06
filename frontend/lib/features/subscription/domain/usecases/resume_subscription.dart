import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Use case for resuming a cancelled subscription.
///
/// This use case allows users to reactivate subscriptions that were cancelled
/// with cancel_at_cycle_end=true and are still within their billing period.
///
/// Returns either a [Failure] if the operation fails, or a [ResumeSubscriptionResult]
/// containing resumption details and updated subscription status.
class ResumeSubscription
    implements UseCase<ResumeSubscriptionResult, NoParams> {
  final SubscriptionRepository _repository;

  const ResumeSubscription(this._repository);

  /// Executes the use case to resume a cancelled subscription.
  ///
  /// Returns [Either<Failure, ResumeSubscriptionResult>] where:
  /// - [Left] contains a [Failure] if the operation fails
  /// - [Right] contains [ResumeSubscriptionResult] with resumption details
  @override
  Future<Either<Failure, ResumeSubscriptionResult>> call(
      NoParams params) async {
    return await _repository.resumeSubscription();
  }
}
