import 'package:supabase_flutter/supabase_flutter.dart';

/// Data transfer objects for phone auth repository
class SendOTPResult {
  final String message;
  final String phoneNumber;
  final int expiresIn;

  const SendOTPResult({
    required this.message,
    required this.phoneNumber,
    required this.expiresIn,
  });
}

class VerifyOTPResult {
  final String message;
  final User user;
  final Session session;
  final bool requiresOnboarding;
  final String onboardingStatus;

  const VerifyOTPResult({
    required this.message,
    required this.user,
    required this.session,
    required this.requiresOnboarding,
    required this.onboardingStatus,
  });
}

/// Abstract repository interface for phone authentication
abstract class PhoneAuthRepository {
  /// Send OTP to the specified phone number
  Future<SendOTPResult> sendOTP({
    required String phoneNumber,
    required String countryCode,
  });

  /// Verify the OTP code for authentication
  Future<VerifyOTPResult> verifyOTP({
    required String phoneNumber,
    required String countryCode,
    required String otpCode,
  });
}
