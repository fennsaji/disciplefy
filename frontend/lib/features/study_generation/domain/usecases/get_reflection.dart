import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/reflection_response.dart';
import '../repositories/reflections_repository.dart';

/// Use case for getting a reflection session by ID.
///
/// This use case implements the business logic for retrieving a specific
/// reflection session, following Clean Architecture principles.
class GetReflection {
  final ReflectionsRepository _repository;

  const GetReflection(this._repository);

  /// Gets a reflection session by its ID.
  ///
  /// Returns either a [Failure] or the [ReflectionSession] (null if not found).
  Future<Either<Failure, ReflectionSession?>> call(String reflectionId) async {
    try {
      final session = await _repository.getReflection(reflectionId);
      return Right(session);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to get reflection',
        code: 'GET_REFLECTION_FAILED',
        context: {'error': e.toString()},
      ));
    }
  }
}
