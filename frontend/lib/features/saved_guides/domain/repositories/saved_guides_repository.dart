import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/saved_guide_entity.dart';

abstract class SavedGuidesRepository {
  Future<Either<Failure, List<SavedGuideEntity>>> getSavedGuides();
  Future<Either<Failure, List<SavedGuideEntity>>> getRecentGuides();
  Future<Either<Failure, void>> saveGuide(SavedGuideEntity guide);
  Future<Either<Failure, void>> removeGuide(String guideId);
  Future<Either<Failure, void>> addToRecent(SavedGuideEntity guide);
  Future<Either<Failure, void>> clearAllSaved();
  Future<Either<Failure, void>> clearAllRecent();
  Stream<List<SavedGuideEntity>> watchSavedGuides();
  Stream<List<SavedGuideEntity>> watchRecentGuides();
}