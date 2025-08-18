import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/models/app_language.dart';
import '../../../../core/services/language_preference_service.dart';
import '../entities/daily_verse_entity.dart';
import '../mappers/app_language_mapper.dart';

/// Use case for getting the default language from unified preference service
class GetDefaultLanguage implements UseCase<VerseLanguage, NoParams> {
  final LanguagePreferenceService _languagePreferenceService;

  GetDefaultLanguage(this._languagePreferenceService);

  @override
  Future<Either<Failure, VerseLanguage>> call(NoParams params) async {
    try {
      final appLanguage =
          await _languagePreferenceService.getSelectedLanguage();
      return Right(appLanguage.toVerseLanguage());
    } catch (e) {
      // Return English as fallback
      return const Right(VerseLanguage.english);
    }
  }
}
