import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/daily_verse_entity.dart';
import '../repositories/daily_verse_repository.dart';

/// Use case for getting preferred verse language
class GetPreferredLanguage implements UseCase<VerseLanguage, NoParams> {
  final DailyVerseRepository repository;

  GetPreferredLanguage(this.repository);

  @override
  Future<Either<Failure, VerseLanguage>> call(NoParams params) async {
    try {
      final language = await repository.getPreferredLanguage();
      return Right(language);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to get preferred language: $e',
      ));
    }
  }
}

/// Use case for setting preferred verse language
class SetPreferredLanguage implements UseCase<void, SetPreferredLanguageParams> {
  final DailyVerseRepository repository;

  SetPreferredLanguage(this.repository);

  @override
  Future<Either<Failure, void>> call(SetPreferredLanguageParams params) async {
    try {
      await repository.setPreferredLanguage(params.language);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to set preferred language: $e',
      ));
    }
  }
}

/// Parameters for SetPreferredLanguage use case
class SetPreferredLanguageParams {
  final VerseLanguage language;

  SetPreferredLanguageParams({required this.language});
}

/// Use case for getting cache statistics
class GetCacheStats implements UseCase<Map<String, dynamic>, NoParams> {
  final DailyVerseRepository repository;

  GetCacheStats(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(NoParams params) async {
    try {
      final stats = await repository.getCacheStats();
      return Right(stats);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to get cache stats: $e',
      ));
    }
  }
}

/// Use case for clearing verse cache
class ClearVerseCache implements UseCase<void, NoParams> {
  final DailyVerseRepository repository;

  ClearVerseCache(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    try {
      await repository.clearCache();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to clear cache: $e',
      ));
    }
  }
}
