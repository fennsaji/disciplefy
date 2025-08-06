import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_profile_entity.dart';
import '../repositories/user_profile_repository.dart';

/// Use case for retrieving user profile
/// Implements Clean Architecture principles with proper error handling
class GetUserProfile
    implements UseCase<UserProfileEntity?, GetUserProfileParams> {
  final UserProfileRepository repository;

  const GetUserProfile({required this.repository});

  @override
  Future<Either<Failure, UserProfileEntity?>> call(
      GetUserProfileParams params) async {
    try {
      final profile = await repository.getUserProfile(params.userId);
      return Right(profile);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to get user profile: ${e.toString()}',
        code: 'GET_PROFILE_ERROR',
      ));
    }
  }
}

/// Parameters for GetUserProfile use case
class GetUserProfileParams {
  final String userId;

  const GetUserProfileParams({required this.userId});
}
