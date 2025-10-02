import 'package:equatable/equatable.dart';

/// Base class for all phone authentication events
abstract class PhoneAuthEvent extends Equatable {
  const PhoneAuthEvent();
  @override
  List<Object?> get props => [];
}

/// Event to send OTP to a phone number
class SendOTPRequested extends PhoneAuthEvent {
  final String phoneNumber;
  final String countryCode;

  const SendOTPRequested(
      {required this.phoneNumber, required this.countryCode});

  @override
  List<Object?> get props => [phoneNumber, countryCode];
}

/// Event to verify OTP code
class VerifyOTPRequested extends PhoneAuthEvent {
  final String phoneNumber;
  final String countryCode;
  final String otpCode;

  const VerifyOTPRequested({
    required this.phoneNumber,
    required this.countryCode,
    required this.otpCode,
  });

  @override
  List<Object?> get props => [phoneNumber, countryCode, otpCode];
}

/// Event to resend OTP to the same phone number
class ResendOTPRequested extends PhoneAuthEvent {
  final String phoneNumber;
  final String countryCode;

  const ResendOTPRequested(
      {required this.phoneNumber, required this.countryCode});

  @override
  List<Object?> get props => [phoneNumber, countryCode];
}

/// Event to reset phone auth state
class PhoneAuthResetRequested extends PhoneAuthEvent {
  const PhoneAuthResetRequested();
}
