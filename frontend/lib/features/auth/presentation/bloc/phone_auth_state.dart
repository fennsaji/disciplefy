import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base class for all phone authentication states
abstract class PhoneAuthState extends Equatable {
  const PhoneAuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any phone auth operations
class PhoneAuthInitialState extends PhoneAuthState {
  const PhoneAuthInitialState();
}

/// State when phone auth operations are in progress
class PhoneAuthLoadingState extends PhoneAuthState {
  final String? message;

  const PhoneAuthLoadingState({this.message});

  @override
  List<Object?> get props => [message];
}

/// State when OTP has been successfully sent
class OTPSentState extends PhoneAuthState {
  final String phoneNumber;
  final String countryCode;
  final int expiresIn;
  final DateTime sentAt;

  const OTPSentState({
    required this.phoneNumber,
    required this.countryCode,
    required this.expiresIn,
    required this.sentAt,
  });

  @override
  List<Object?> get props => [phoneNumber, countryCode, expiresIn, sentAt];

  /// Get formatted phone number for display
  String get formattedPhoneNumber => '$countryCode$phoneNumber';

  /// Check if OTP has expired
  bool get isExpired {
    final now = DateTime.now();
    final expiryTime = sentAt.add(Duration(seconds: expiresIn));
    return now.isAfter(expiryTime);
  }

  /// Get remaining time in seconds
  int get remainingSeconds {
    final now = DateTime.now();
    final expiryTime = sentAt.add(Duration(seconds: expiresIn));
    final remaining = expiryTime.difference(now).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
}

/// State when OTP verification is successful and user is authenticated
class PhoneAuthSuccessState extends PhoneAuthState {
  final User user;
  final Session session;
  final bool requiresOnboarding;
  final String onboardingStatus;

  const PhoneAuthSuccessState({
    required this.user,
    required this.session,
    required this.requiresOnboarding,
    required this.onboardingStatus,
  });

  @override
  List<Object?> get props =>
      [user, session, requiresOnboarding, onboardingStatus];
}

/// State when a phone auth error occurs
class PhoneAuthErrorState extends PhoneAuthState {
  final String message;
  final String? errorCode;
  final PhoneAuthErrorType errorType;

  const PhoneAuthErrorState({
    required this.message,
    this.errorCode,
    this.errorType = PhoneAuthErrorType.general,
  });

  @override
  List<Object?> get props => [message, errorCode, errorType];
}

/// Types of phone authentication errors
enum PhoneAuthErrorType {
  /// General error
  general,

  /// Invalid phone number format
  invalidPhoneNumber,

  /// Invalid OTP code
  invalidOTP,

  /// OTP has expired
  otpExpired,

  /// Too many attempts
  tooManyAttempts,

  /// Network connectivity issues
  networkError,

  /// SMS provider not configured
  providerNotConfigured,

  /// Rate limit exceeded
  rateLimitExceeded,
}
