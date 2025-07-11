import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/saved_guide_entity.dart';
import '../repositories/saved_guides_repository.dart';

class SaveGuide implements UseCase<void, SaveGuideParams> {
  final SavedGuidesRepository repository;

  const SaveGuide(this.repository);

  @override
  Future<Either<Failure, void>> call(SaveGuideParams params) async => await repository.saveGuide(params.guide);
}

class SaveGuideParams extends Equatable {
  final SavedGuideEntity guide;

  const SaveGuideParams({required this.guide});

  @override
  List<Object?> get props => [guide];
}