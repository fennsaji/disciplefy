import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';

/// Data model for OTP sent response
class OTPSentResponse {
  final String message;
  final String phoneNumber;
  final int expiresIn;

  const OTPSentResponse({
    required this.message,
    required this.phoneNumber,
    required this.expiresIn,
  });

  factory OTPSentResponse.fromJson(Map<String, dynamic> json) {
    return OTPSentResponse(
      message: json['message'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      expiresIn: json['expires_in'] ?? 60,
    );
  }
}

/// Data model for OTP verification response
class OTPVerifiedResponse {
  final String message;
  final User user;
  final Session session;
  final bool requiresOnboarding;
  final String onboardingStatus;

  const OTPVerifiedResponse({
    required this.message,
    required this.user,
    required this.session,
    required this.requiresOnboarding,
    required this.onboardingStatus,
  });

  factory OTPVerifiedResponse.fromJson(Map<String, dynamic> json) {
    final userData = json['user'];
    final sessionData = json['session'];

    if (userData == null) {
      throw const ServerException(
        message: 'User data not found in response',
        code: 'INVALID_RESPONSE',
      );
    }

    if (sessionData == null) {
      throw const ServerException(
        message: 'Session data not found in response',
        code: 'INVALID_RESPONSE',
      );
    }

    final user = User.fromJson(userData as Map<String, dynamic>);
    final session = Session.fromJson(sessionData as Map<String, dynamic>);

    if (user == null) {
      throw const ServerException(
        message: 'Failed to parse user data from response',
        code: 'INVALID_USER_DATA',
      );
    }

    if (session == null) {
      throw const ServerException(
        message: 'Failed to parse session data from response',
        code: 'INVALID_SESSION_DATA',
      );
    }

    return OTPVerifiedResponse(
      message: json['message'] ?? '',
      user: user,
      session: session,
      requiresOnboarding: json['requires_onboarding'] ?? false,
      onboardingStatus: json['onboarding_status'] ?? 'completed',
    );
  }
}

/// Abstract interface for phone authentication data source
abstract class PhoneAuthRemoteDataSource {
  /// Send OTP to phone number
  Future<OTPSentResponse> sendOTP({
    required String phoneNumber,
    required String countryCode,
  });

  /// Verify OTP code
  Future<OTPVerifiedResponse> verifyOTP({
    required String phoneNumber,
    required String countryCode,
    required String otpCode,
  });
}

/// Implementation of phone auth remote data source using native Supabase auth
class PhoneAuthRemoteDataSourceImpl implements PhoneAuthRemoteDataSource {
  final SupabaseClient _supabaseClient;

  const PhoneAuthRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  @override
  Future<OTPSentResponse> sendOTP({
    required String phoneNumber,
    required String countryCode,
  }) async {
    try {
      final formattedPhoneNumber = _formatPhoneNumber(phoneNumber, countryCode);

      // Use native Supabase phone auth - this automatically handles session establishment
      await _supabaseClient.auth.signInWithOtp(
        phone: formattedPhoneNumber,
      );

      return OTPSentResponse(
        message: 'OTP sent successfully',
        phoneNumber: formattedPhoneNumber,
        expiresIn: 60, // Standard OTP expiry time
      );
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }

      // Map common errors to specific exceptions
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('network') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout')) {
        throw NetworkException(
          message: 'Network error occurred while sending OTP',
          code: 'NETWORK_ERROR',
        );
      }

      if (errorMessage.contains('unsupported phone provider') ||
          errorMessage.contains('provider not configured')) {
        throw ServerException(
          message:
              'SMS service is currently unavailable. Please try again later.',
          code: 'SMS_SERVICE_UNAVAILABLE',
        );
      }

      if (errorMessage.contains('invalid phone number')) {
        throw ValidationException(
          message: 'Invalid phone number format',
          code: 'INVALID_PHONE_NUMBER',
        );
      }

      if (errorMessage.contains('rate limit') ||
          errorMessage.contains('too many requests')) {
        throw RateLimitException(
          message: 'Too many OTP requests. Please try again later.',
          code: 'RATE_LIMIT_EXCEEDED',
        );
      }

      throw ServerException(
        message: 'Failed to send OTP: ${e.toString()}',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  @override
  Future<OTPVerifiedResponse> verifyOTP({
    required String phoneNumber,
    required String countryCode,
    required String otpCode,
  }) async {
    try {
      final formattedPhoneNumber = _formatPhoneNumber(phoneNumber, countryCode);

      // Use native Supabase phone auth verification
      final response = await _supabaseClient.auth.verifyOTP(
        phone: formattedPhoneNumber,
        token: otpCode,
        type: OtpType.sms,
      );

      // Extract user and session from the auth response
      final user = response.user;
      final session = response.session;

      if (user == null || session == null) {
        throw const ServerException(
          message: 'Authentication failed - no user or session returned',
          code: 'AUTH_FAILED',
        );
      }

      // Check if user needs onboarding (new user without profile setup)
      final isNewUser = user.userMetadata?['phone_verified_at'] == null ||
          user.userMetadata?['first_login'] == true;

      return OTPVerifiedResponse(
        message: 'OTP verification successful',
        user: user,
        session: session,
        requiresOnboarding: isNewUser,
        onboardingStatus: isNewUser ? 'pending' : 'completed',
      );
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }

      // Map common errors to specific exceptions
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('network') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout')) {
        throw NetworkException(
          message: 'Network error occurred while verifying OTP',
          code: 'NETWORK_ERROR',
        );
      }

      if (errorMessage.contains('invalid otp') ||
          errorMessage.contains('otp must be 6 digits') ||
          errorMessage.contains('failed to verify otp')) {
        throw ValidationException(
          message: 'Invalid OTP code. Please check and try again.',
          code: 'INVALID_OTP_CODE',
        );
      }

      if (errorMessage.contains('expired') ||
          errorMessage.contains('otp verification failed')) {
        throw ValidationException(
          message: 'OTP has expired. Please request a new one.',
          code: 'OTP_EXPIRED',
        );
      }

      if (errorMessage.contains('rate limit') ||
          errorMessage.contains('too many requests')) {
        throw RateLimitException(
          message: 'Too many verification attempts. Please try again later.',
          code: 'RATE_LIMIT_EXCEEDED',
        );
      }

      throw ServerException(
        message: 'Failed to verify OTP: ${e.toString()}',
        code: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Format phone number with country code
  String _formatPhoneNumber(String phoneNumber, String countryCode) {
    // Debug logging
    print('🔍 [PHONE FORMAT] Raw phoneNumber: "$phoneNumber"');
    print('🔍 [PHONE FORMAT] Raw countryCode: "$countryCode"');

    // Remove any non-digit characters from phone number
    final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    print('🔍 [PHONE FORMAT] Clean phoneNumber: "$cleanPhoneNumber"');

    // Ensure country code starts with +
    final formattedCountryCode =
        countryCode.startsWith('+') ? countryCode : '+$countryCode';
    print('🔍 [PHONE FORMAT] Formatted countryCode: "$formattedCountryCode"');

    final formatted = '$formattedCountryCode$cleanPhoneNumber';
    print('🔍 [PHONE FORMAT] Final formatted: "$formatted"');

    return formatted;
  }
}
