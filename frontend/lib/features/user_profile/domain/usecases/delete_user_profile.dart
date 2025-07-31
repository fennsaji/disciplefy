import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/user_profile_repository.dart';

/// Use case for deleting user profile
/// Handles complete profile removal including associated data
class DeleteUserProfile implements UseCase<void, DeleteUserProfileParams> {
  final UserProfileRepository repository;

  const DeleteUserProfile({required this.repository});

  @override
  Future<Either<Failure, void>> call(DeleteUserProfileParams params) async {
    try {
      await repository.deleteUserProfile(params.userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to delete user profile: ${e.toString()}',
        code: 'DELETE_PROFILE_ERROR',
      ));
    }
  }
}

/// Parameters for DeleteUserProfile use case
class DeleteUserProfileParams {
  final String userId;

  const DeleteUserProfileParams({required this.userId});
}