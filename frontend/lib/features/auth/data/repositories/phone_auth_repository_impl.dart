import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/phone_auth_repository.dart';
import '../datasources/phone_auth_remote_datasource.dart';

/// Implementation of the phone auth repository
class PhoneAuthRepositoryImpl implements PhoneAuthRepository {
  final PhoneAuthRemoteDataSource _remoteDataSource;

  const PhoneAuthRepositoryImpl({
    required PhoneAuthRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<SendOTPResult> sendOTP({
    required String phoneNumber,
    required String countryCode,
  }) async {
    try {
      final response = await _remoteDataSource.sendOTP(
        phoneNumber: phoneNumber,
        countryCode: countryCode,
      );

      return SendOTPResult(
        message: response.message,
        phoneNumber: response.phoneNumber,
        expiresIn: response.expiresIn,
      );
    } on ValidationException catch (e) {
      throw ValidationFailure(message: e.message);
    } on NetworkException catch (e) {
      throw NetworkFailure(message: e.message);
    } on RateLimitException catch (e) {
      throw RateLimitFailure(message: e.message);
    } on ServerException catch (e) {
      throw ServerFailure(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerFailure(
        message: 'An unexpected error occurred: ${e.toString()}',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  @override
  Future<VerifyOTPResult> verifyOTP({
    required String phoneNumber,
    required String countryCode,
    required String otpCode,
  }) async {
    try {
      final response = await _remoteDataSource.verifyOTP(
        phoneNumber: phoneNumber,
        countryCode: countryCode,
        otpCode: otpCode,
      );

      return VerifyOTPResult(
        message: response.message,
        user: response.user,
        session: response.session,
        requiresOnboarding: response.requiresOnboarding,
        onboardingStatus: response.onboardingStatus,
      );
    } on ValidationException catch (e) {
      throw ValidationFailure(message: e.message);
    } on NetworkException catch (e) {
      throw NetworkFailure(message: e.message);
    } on RateLimitException catch (e) {
      throw RateLimitFailure(message: e.message);
    } on ServerException catch (e) {
      throw ServerFailure(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerFailure(
        message: 'An unexpected error occurred: ${e.toString()}',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }
}
