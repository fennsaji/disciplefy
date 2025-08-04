import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/daily_verse_entity.dart';
import '../repositories/daily_verse_repository.dart';

/// Use case for getting daily verse with date parameter
class GetDailyVerse implements UseCase<DailyVerseEntity, GetDailyVerseParams> {
  final DailyVerseRepository repository;

  GetDailyVerse(this.repository);

  @override
  Future<Either<Failure, DailyVerseEntity>> call(GetDailyVerseParams params) async {
    if (params.date != null) {
      return await repository.getDailyVerse(params.date!);
    } else {
      return await repository.getTodaysVerse();
    }
  }
}

/// Parameters for GetDailyVerse use case
class GetDailyVerseParams {
  final DateTime? date;

  GetDailyVerseParams({this.date});

  /// Create params for today's verse
  factory GetDailyVerseParams.today() => GetDailyVerseParams();

  /// Create params for specific date
  factory GetDailyVerseParams.forDate(DateTime date) => GetDailyVerseParams(date: date);
}
