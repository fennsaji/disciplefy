import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/logger.dart';

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

    // Parse user and session data (throws if parsing fails)
    final user = User.fromJson(userData as Map<String, dynamic>);
    final session = Session.fromJson(sessionData as Map<String, dynamic>);

    if (user == null || session == null) {
      throw const ServerException(
        message: 'Failed to parse user/session data from response',
        code: 'PARSING_ERROR',
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

      // Check onboarding status from user_profiles table
      bool requiresOnboarding = false;
      String onboardingStatus = 'completed';

      try {
        final profileResponse = await _supabaseClient
            .from('user_profiles')
            .select('onboarding_status')
            .eq('id', user.id)
            .maybeSingle();

        if (profileResponse != null) {
          onboardingStatus =
              profileResponse['onboarding_status'] ?? 'completed';
          requiresOnboarding = onboardingStatus == 'profile_setup' ||
              onboardingStatus == 'language_selection' ||
              onboardingStatus == 'pending';
        } else {
          // No profile found - treat as new user requiring onboarding
          requiresOnboarding = true;
          onboardingStatus = 'profile_setup';
        }
      } catch (e) {
        // On error, default to non-new user to avoid blocking authentication
        // Log for debugging but don't fail the auth flow
        Logger.debug('Failed to fetch onboarding status: ${e.toString()}');
        requiresOnboarding = false;
        onboardingStatus = 'completed';
      }

      return OTPVerifiedResponse(
        message: 'OTP verification successful',
        user: user,
        session: session,
        requiresOnboarding: requiresOnboarding,
        onboardingStatus: onboardingStatus,
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
    Logger.debug('🔍 [PHONE FORMAT] Raw phoneNumber: "$phoneNumber"');
    Logger.debug('🔍 [PHONE FORMAT] Raw countryCode: "$countryCode"');

    // Remove any non-digit characters from phone number
    final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    Logger.debug('🔍 [PHONE FORMAT] Clean phoneNumber: "$cleanPhoneNumber"');

    // Ensure country code starts with +
    final formattedCountryCode =
        countryCode.startsWith('+') ? countryCode : '+$countryCode';
    Logger.debug(
        '🔍 [PHONE FORMAT] Formatted countryCode: "$formattedCountryCode"');

    final formatted = '$formattedCountryCode$cleanPhoneNumber';
    Logger.debug('🔍 [PHONE FORMAT] Final formatted: "$formatted"');

    return formatted;
  }
}
