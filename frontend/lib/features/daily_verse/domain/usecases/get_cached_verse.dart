import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/daily_verse_entity.dart';
import '../repositories/daily_verse_repository.dart';

/// Use case for getting cached daily verse (offline support)
class GetCachedVerse
    implements UseCase<DailyVerseEntity?, GetCachedVerseParams> {
  final DailyVerseRepository repository;

  GetCachedVerse(this.repository);

  @override
  Future<Either<Failure, DailyVerseEntity?>> call(
      GetCachedVerseParams params) async {
    try {
      final cachedVerse = await repository.getCachedVerse(params.date);
      return Right(cachedVerse);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to load cached verse: ${e.toString()}',
        code: 'CACHE_VERSE_ERROR',
      ));
    }
  }
}

/// Parameters for GetCachedVerse use case
class GetCachedVerseParams {
  final DateTime date;

  GetCachedVerseParams({required this.date});

  /// Create params for today's cached verse
  factory GetCachedVerseParams.today() =>
      GetCachedVerseParams(date: DateTime.now());

  /// Create params for specific date cached verse
  factory GetCachedVerseParams.forDate(DateTime date) =>
      GetCachedVerseParams(date: date);
}
