import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/saved_guides_repository.dart';

class RemoveGuide implements UseCase<void, RemoveGuideParams> {
  final SavedGuidesRepository repository;

  const RemoveGuide(this.repository);

  @override
  Future<Either<Failure, void>> call(RemoveGuideParams params) async => await repository.removeGuide(params.guideId);
}

class RemoveGuideParams extends Equatable {
  final String guideId;

  const RemoveGuideParams({required this.guideId});

  @override
  List<Object?> get props => [guideId];
}
