import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/saved_guide_entity.dart';
import '../../domain/repositories/saved_guides_repository.dart';
import '../datasources/saved_guides_local_data_source.dart';
import '../datasources/saved_guides_remote_data_source.dart';
import '../models/saved_guide_model.dart';

class SavedGuidesRepositoryImpl implements SavedGuidesRepository {
  final SavedGuidesLocalDataSource localDataSource;
  final SavedGuidesRemoteDataSource remoteDataSource;

  const SavedGuidesRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

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
      return Stream.error(
          CacheFailure(message: 'Failed to watch saved guides: $e'));
    }
  }

  @override
  Stream<List<SavedGuideEntity>> watchRecentGuides() {
    try {
      return localDataSource.watchRecentGuides().map(
            (models) => models.map((model) => model.toEntity()).toList(),
          );
    } catch (e) {
      return Stream.error(
          CacheFailure(message: 'Failed to watch recent guides: $e'));
    }
  }

  // API operations implementation
  @override
  Future<Either<Failure, List<SavedGuideEntity>>> fetchSavedGuidesFromApi({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final guides = await remoteDataSource.getSavedGuides(
        limit: limit,
        offset: offset,
      );
      return Right(guides.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SavedGuideEntity>>> fetchRecentGuidesFromApi({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final guides = await remoteDataSource.getRecentGuides(
        limit: limit,
        offset: offset,
      );
      return Right(guides.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, SavedGuideEntity>> toggleSaveGuideApi({
    required String guideId,
    required bool save,
  }) async {
    try {
      final guide = await remoteDataSource.toggleSaveGuide(
        guideId: guideId,
        save: save,
      );

      // Update local cache as well
      final entity = guide.toEntity();
      if (save) {
        await localDataSource.saveGuide(guide);
      } else {
        await localDataSource.removeGuide(guideId);
      }

      return Right(entity);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  // Hybrid operations implementation
  @override
  Future<Either<Failure, List<SavedGuideEntity>>> getSavedGuidesWithSync({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    try {
      // If force refresh or cache is empty, fetch from API
      if (forceRefresh || offset == 0) {
        final apiResult = await fetchSavedGuidesFromApi(
          limit: limit,
          offset: offset,
        );

        return apiResult.fold(
          (failure) {
            // Fallback to local cache on API failure
            if (failure is AuthenticationFailure) {
              return Left(failure); // Auth failures should not fallback
            }
            return getSavedGuides(); // Use local cache as fallback
          },
          (guides) {
            // Cache the API results locally for offline access
            if (offset == 0) {
              // Clear and repopulate cache for fresh data
              _cacheGuides(guides, true);
            }
            return Right(guides);
          },
        );
      }

      // For pagination beyond first page, always use API
      return fetchSavedGuidesFromApi(limit: limit, offset: offset);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SavedGuideEntity>>> getRecentGuidesWithSync({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    try {
      // If force refresh or cache is empty, fetch from API
      if (forceRefresh || offset == 0) {
        final apiResult = await fetchRecentGuidesFromApi(
          limit: limit,
          offset: offset,
        );

        return apiResult.fold(
          (failure) {
            // Fallback to local cache on API failure
            if (failure is AuthenticationFailure) {
              return Left(failure); // Auth failures should not fallback
            }
            return getRecentGuides(); // Use local cache as fallback
          },
          (guides) {
            // Cache the API results locally for offline access
            if (offset == 0) {
              // Update local recent guides cache
              _cacheGuides(guides, false);
            }
            return Right(guides);
          },
        );
      }

      // For pagination beyond first page, always use API
      return fetchRecentGuidesFromApi(limit: limit, offset: offset);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  /// Helper method to cache guides locally
  Future<void> _cacheGuides(
      List<SavedGuideEntity> guides, bool areSaved) async {
    try {
      for (final guide in guides) {
        final model = SavedGuideModel.fromEntity(guide);
        if (areSaved) {
          await localDataSource.saveGuide(model);
        } else {
          await localDataSource.addToRecent(model);
        }
      }
    } catch (e) {
      // Silently handle cache errors - they shouldn't break the main flow
    }
  }
}
