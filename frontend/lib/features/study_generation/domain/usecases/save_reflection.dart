import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/reflection_response.dart';
import '../entities/study_mode.dart';
import '../repositories/reflections_repository.dart';

/// Parameters for saving a reflection session.
class SaveReflectionParams extends Equatable {
  final String studyGuideId;
  final StudyMode studyMode;
  final List<ReflectionResponse> responses;
  final int timeSpentSeconds;
  final DateTime? completedAt;

  const SaveReflectionParams({
    required this.studyGuideId,
    required this.studyMode,
    required this.responses,
    required this.timeSpentSeconds,
    this.completedAt,
  });

  @override
  List<Object?> get props => [
        studyGuideId,
        studyMode,
        responses,
        timeSpentSeconds,
        completedAt,
      ];
}

/// Use case for saving a reflection session.
///
/// This use case implements the business logic for persisting reflection data,
/// following Clean Architecture principles.
class SaveReflection {
  final ReflectionsRepository _repository;

  const SaveReflection(this._repository);

  /// Saves a reflection session.
  ///
  /// Returns either a [Failure] or the saved [ReflectionSession].
  Future<Either<Failure, ReflectionSession>> call(
    SaveReflectionParams params,
  ) async {
    try {
      final session = await _repository.saveReflection(
        studyGuideId: params.studyGuideId,
        studyMode: params.studyMode,
        responses: params.responses,
        timeSpentSeconds: params.timeSpentSeconds,
        completedAt: params.completedAt,
      );

      return Right(session);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to save reflection',
        code: 'SAVE_REFLECTION_FAILED',
        context: {'error': e.toString()},
      ));
    }
  }
}
