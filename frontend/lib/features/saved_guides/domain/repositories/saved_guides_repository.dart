import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/saved_guide_entity.dart';

abstract class SavedGuidesRepository {
  // Local operations (for offline/cache)
  Future<Either<Failure, List<SavedGuideEntity>>> getSavedGuides();
  Future<Either<Failure, List<SavedGuideEntity>>> getRecentGuides();
  Future<Either<Failure, void>> saveGuide(SavedGuideEntity guide);
  Future<Either<Failure, void>> removeGuide(String guideId);
  Future<Either<Failure, void>> addToRecent(SavedGuideEntity guide);
  Future<Either<Failure, void>> clearAllSaved();
  Future<Either<Failure, void>> clearAllRecent();
  Stream<List<SavedGuideEntity>> watchSavedGuides();
  Stream<List<SavedGuideEntity>> watchRecentGuides();

  // API operations (for authenticated users)
  Future<Either<Failure, List<SavedGuideEntity>>> fetchSavedGuidesFromApi({
    int limit = 20,
    int offset = 0,
  });
  Future<Either<Failure, List<SavedGuideEntity>>> fetchRecentGuidesFromApi({
    int limit = 20,
    int offset = 0,
  });
  Future<Either<Failure, SavedGuideEntity>> toggleSaveGuideApi({
    required String guideId,
    required bool save,
  });

  // Hybrid operations (combine API + local cache)
  Future<Either<Failure, List<SavedGuideEntity>>> getSavedGuidesWithSync({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  });
  Future<Either<Failure, List<SavedGuideEntity>>> getRecentGuidesWithSync({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  });
}
