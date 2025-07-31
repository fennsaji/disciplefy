import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/saved_guide_entity.dart';
import '../repositories/saved_guides_repository.dart';

class GetSavedGuidesWithSync {
  final SavedGuidesRepository repository;

  const GetSavedGuidesWithSync({required this.repository});

  Future<Either<Failure, List<SavedGuideEntity>>> call({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async => await repository.getSavedGuidesWithSync(
      limit: limit,
      offset: offset,
      forceRefresh: forceRefresh,
    );
}