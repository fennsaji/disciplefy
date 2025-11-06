import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

/// Parameters for fetching invoices with pagination.
class GetInvoicesParams extends Equatable {
  /// Maximum number of invoices to return (optional)
  final int? limit;

  /// Number of invoices to skip for pagination (optional)
  final int? offset;

  const GetInvoicesParams({
    this.limit,
    this.offset,
  });

  @override
  List<Object?> get props => [limit, offset];
}

/// Use case for fetching subscription invoices.
///
/// This use case retrieves subscription invoices for the authenticated user
/// with optional pagination support.
///
/// Returns either a [Failure] if the operation fails, or a list of [SubscriptionInvoice] entities.
class GetInvoices
    implements UseCase<List<SubscriptionInvoice>, GetInvoicesParams> {
  final SubscriptionRepository _repository;

  const GetInvoices(this._repository);

  /// Executes the use case to get invoices.
  ///
  /// Returns [Either<Failure, List<SubscriptionInvoice>>] where:
  /// - [Left] contains a [Failure] if the operation fails
  /// - [Right] contains list of [SubscriptionInvoice] with optional pagination
  @override
  Future<Either<Failure, List<SubscriptionInvoice>>> call(
      GetInvoicesParams params) async {
    return await _repository.getInvoices(
      limit: params.limit,
      offset: params.offset,
    );
  }
}
