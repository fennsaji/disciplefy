import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Parameters for cancelling a subscription.
class CancelSubscriptionParams extends Equatable {
  /// If true, subscription remains active until current period ends.
  /// If false, cancels immediately and revokes premium access.
  final bool cancelAtCycleEnd;

  /// Optional cancellation reason for analytics
  final String? reason;

  const CancelSubscriptionParams({
    required this.cancelAtCycleEnd,
    this.reason,
  });

  @override
  List<Object?> get props => [cancelAtCycleEnd, reason];
}

/// Use case for cancelling an active subscription.
///
/// This use case handles both immediate cancellation and scheduled cancellation
/// at the end of the current billing cycle.
///
/// Returns either a [Failure] if the operation fails, or a [CancelSubscriptionResult]
/// containing cancellation details and affected period information.
class CancelSubscription
    implements UseCase<CancelSubscriptionResult, CancelSubscriptionParams> {
  final SubscriptionRepository _repository;

  const CancelSubscription(this._repository);

  /// Executes the use case to cancel a subscription.
  ///
  /// Returns [Either<Failure, CancelSubscriptionResult>] where:
  /// - [Left] contains a [Failure] if the operation fails
  /// - [Right] contains [CancelSubscriptionResult] with cancellation details
  @override
  Future<Either<Failure, CancelSubscriptionResult>> call(
      CancelSubscriptionParams params) async {
    return await _repository.cancelSubscription(
      cancelAtCycleEnd: params.cancelAtCycleEnd,
      reason: params.reason,
    );
  }
}
