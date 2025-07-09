import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/saved_guide_entity.dart';
import '../../domain/repositories/saved_guides_repository.dart';
import '../datasources/saved_guides_local_data_source.dart';
import '../models/saved_guide_model.dart';

class SavedGuidesRepositoryImpl implements SavedGuidesRepository {
  final SavedGuidesLocalDataSource localDataSource;

  const SavedGuidesRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<SavedGuideEntity>>> getSavedGuides() async {
    try {
      final guides = await localDataSource.getSavedGuides();
      return Right(guides.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SavedGuideEntity>>> getRecentGuides() async {
    try {
      final guides = await localDataSource.getRecentGuides();
      return Right(guides.map((model) => model.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveGuide(SavedGuideEntity guide) async {
    try {
      final model = SavedGuideModel.fromEntity(guide);
      await localDataSource.saveGuide(model);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeGuide(String guideId) async {
    try {
      await localDataSource.removeGuide(guideId);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addToRecent(SavedGuideEntity guide) async {
    try {
      final model = SavedGuideModel.fromEntity(guide);
      await localDataSource.addToRecent(model);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearAllSaved() async {
    try {
      await localDataSource.clearAllSaved();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearAllRecent() async {
    try {
      await localDataSource.clearAllRecent();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Stream<List<SavedGuideEntity>> watchSavedGuides() {
    try {
      return localDataSource.watchSavedGuides().map(
        (models) => models.map((model) => model.toEntity()).toList(),
      );
    } catch (e) {
      return Stream.error(CacheFailure(message: 'Failed to watch saved guides: $e'));
    }
  }

  @override
  Stream<List<SavedGuideEntity>> watchRecentGuides() {
    try {
      return localDataSource.watchRecentGuides().map(
        (models) => models.map((model) => model.toEntity()).toList(),
      );
    } catch (e) {
      return Stream.error(CacheFailure(message: 'Failed to watch recent guides: $e'));
    }
  }
}