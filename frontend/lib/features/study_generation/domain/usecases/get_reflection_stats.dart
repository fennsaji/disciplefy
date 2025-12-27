import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/reflections_repository.dart';

/// Use case for getting user's reflection statistics.
///
/// This use case implements the business logic for retrieving aggregated
/// reflection data, following Clean Architecture principles.
class GetReflectionStats {
  final ReflectionsRepository _repository;

  const GetReflectionStats(this._repository);

  /// Gets the user's reflection statistics.
  ///
  /// Returns either a [Failure] or [ReflectionStats].
  Future<Either<Failure, ReflectionStats>> call() async {
    try {
      final stats = await _repository.getReflectionStats();
      return Right(stats);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to get reflection stats',
        code: 'GET_REFLECTION_STATS_FAILED',
        context: {'error': e.toString()},
      ));
    }
  }
}
