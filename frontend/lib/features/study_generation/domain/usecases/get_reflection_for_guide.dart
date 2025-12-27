import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/reflection_response.dart';
import '../repositories/reflections_repository.dart';

/// Use case for getting a reflection session for a specific study guide.
///
/// This use case implements the business logic for retrieving the reflection
/// associated with a study guide, following Clean Architecture principles.
class GetReflectionForGuide {
  final ReflectionsRepository _repository;

  const GetReflectionForGuide(this._repository);

  /// Gets a reflection session for a specific study guide.
  ///
  /// Returns either a [Failure] or the [ReflectionSession] (null if not found).
  Future<Either<Failure, ReflectionSession?>> call(String studyGuideId) async {
    try {
      final session = await _repository.getReflectionForGuide(studyGuideId);
      return Right(session);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to get reflection for guide',
        code: 'GET_REFLECTION_FOR_GUIDE_FAILED',
        context: {'error': e.toString()},
      ));
    }
  }
}
