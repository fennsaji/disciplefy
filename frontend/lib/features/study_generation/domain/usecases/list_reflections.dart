import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/study_mode.dart';
import '../repositories/reflections_repository.dart';

/// Parameters for listing reflections.
class ListReflectionsParams extends Equatable {
  final int page;
  final int perPage;
  final StudyMode? studyMode;

  const ListReflectionsParams({
    this.page = 1,
    this.perPage = 20,
    this.studyMode,
  });

  @override
  List<Object?> get props => [page, perPage, studyMode];
}

/// Use case for listing user's reflection sessions with pagination.
///
/// This use case implements the business logic for retrieving a paginated
/// list of reflections, following Clean Architecture principles.
class ListReflections {
  final ReflectionsRepository _repository;

  const ListReflections(this._repository);

  /// Lists user's reflections with pagination and optional filtering.
  ///
  /// Returns either a [Failure] or [ReflectionListResult].
  Future<Either<Failure, ReflectionListResult>> call(
    ListReflectionsParams params,
  ) async {
    try {
      final result = await _repository.listReflections(
        page: params.page,
        perPage: params.perPage,
        studyMode: params.studyMode,
      );

      return Right(result);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to list reflections',
        code: 'LIST_REFLECTIONS_FAILED',
        context: {'error': e.toString()},
      ));
    }
  }
}
