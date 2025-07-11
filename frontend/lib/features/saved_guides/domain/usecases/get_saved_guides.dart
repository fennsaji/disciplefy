import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/saved_guide_entity.dart';
import '../repositories/saved_guides_repository.dart';

class GetSavedGuides implements UseCase<List<SavedGuideEntity>, NoParams> {
  final SavedGuidesRepository repository;

  const GetSavedGuides(this.repository);

  @override
  Future<Either<Failure, List<SavedGuideEntity>>> call(NoParams params) async => await repository.getSavedGuides();
}