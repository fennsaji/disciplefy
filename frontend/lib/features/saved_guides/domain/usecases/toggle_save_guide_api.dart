import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/saved_guide_entity.dart';
import '../repositories/saved_guides_repository.dart';

class ToggleSaveGuideApi {
  final SavedGuidesRepository repository;

  const ToggleSaveGuideApi({required this.repository});

  Future<Either<Failure, SavedGuideEntity>> call({
    required String guideId,
    required bool save,
  }) async =>
      await repository.toggleSaveGuideApi(
        guideId: guideId,
        save: save,
      );
}
