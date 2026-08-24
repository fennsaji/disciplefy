import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../entities/user_profile_entity.dart';
import '../repositories/user_profile_repository.dart';

/// Use case for updating user profile
/// Handles profile upsert operations with validation
class UpdateUserProfile implements UseCase<void, UpdateUserProfileParams> {
  final UserProfileRepository repository;

  const UpdateUserProfile({required this.repository});

  @override
  Future<Either<Failure, void>> call(UpdateUserProfileParams params) async {
    try {
      await repository.upsertUserProfile(params.profile);
      return const Right(null);
    } catch (e) {
      Logger.error('Failed to update user profile', error: e);
      return const Left(ServerFailure(
        message: 'Failed to update user profile. Please try again.',
        code: 'UPDATE_PROFILE_ERROR',
      ));
    }
  }
}

/// Parameters for UpdateUserProfile use case
class UpdateUserProfileParams {
  final UserProfileEntity profile;

  const UpdateUserProfileParams({required this.profile});
}
