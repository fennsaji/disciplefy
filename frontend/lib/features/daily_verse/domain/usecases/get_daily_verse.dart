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
  Future<Either<Failure, DailyVerseEntity>> call(
      GetDailyVerseParams params) async {
    if (params.date != null) {
      return await repository.getDailyVerse(params.date!, params.language);
    } else {
      return await repository.getTodaysVerse(params.language);
    }
  }
}

/// Parameters for GetDailyVerse use case
class GetDailyVerseParams {
  final DateTime? date;
  final VerseLanguage? language;

  GetDailyVerseParams({this.date, this.language});

  /// Create params for today's verse
  factory GetDailyVerseParams.today([VerseLanguage? language]) =>
      GetDailyVerseParams(language: language);

  /// Create params for specific date
  factory GetDailyVerseParams.forDate(DateTime date,
          [VerseLanguage? language]) =>
      GetDailyVerseParams(date: date, language: language);
}
