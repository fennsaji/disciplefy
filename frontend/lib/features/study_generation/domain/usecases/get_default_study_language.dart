import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/models/app_language.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../presentation/pages/generate_study_screen.dart';
import '../mappers/app_language_mapper.dart';

/// Use case for getting the default language for study generation from unified preference service
/// Uses study content language (not app UI language)
class GetDefaultStudyLanguage implements UseCase<StudyLanguage, NoParams> {
  final LanguagePreferenceService _languagePreferenceService;

  GetDefaultStudyLanguage(this._languagePreferenceService);

  @override
  Future<Either<Failure, StudyLanguage>> call(NoParams params) async {
    try {
      final appLanguage =
          await _languagePreferenceService.getStudyContentLanguage();
      return Right(appLanguage.toStudyLanguage());
    } catch (e) {
      // Return English as fallback
      return const Right(StudyLanguage.english);
    }
  }
}
