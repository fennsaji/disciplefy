import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/saved_guide_entity.dart';
import '../repositories/saved_guides_repository.dart';

class AddToRecent implements UseCase<void, AddToRecentParams> {
  final SavedGuidesRepository repository;

  const AddToRecent(this.repository);

  @override
  Future<Either<Failure, void>> call(AddToRecentParams params) async {
    return await repository.addToRecent(params.guide);
  }
}

class AddToRecentParams extends Equatable {
  final SavedGuideEntity guide;

  const AddToRecentParams({required this.guide});

  @override
  List<Object?> get props => [guide];
}