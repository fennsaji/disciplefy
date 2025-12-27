import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/reflections_repository.dart';

/// Use case for deleting a reflection session.
///
/// This use case implements the business logic for removing a reflection,
/// following Clean Architecture principles.
class DeleteReflection {
  final ReflectionsRepository _repository;

  const DeleteReflection(this._repository);

  /// Deletes a reflection session by its ID.
  ///
  /// Returns either a [Failure] or void on success.
  Future<Either<Failure, void>> call(String reflectionId) async {
    try {
      await _repository.deleteReflection(reflectionId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to delete reflection',
        code: 'DELETE_REFLECTION_FAILED',
        context: {'error': e.toString()},
      ));
    }
  }
}
