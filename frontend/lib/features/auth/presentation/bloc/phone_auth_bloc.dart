import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/phone_auth_repository.dart';
import 'phone_auth_event.dart';
import 'phone_auth_state.dart';

/// BLoC for managing phone authentication state and operations
class PhoneAuthBloc extends Bloc<PhoneAuthEvent, PhoneAuthState> {
  final PhoneAuthRepository _phoneAuthRepository;

  PhoneAuthBloc({
    required PhoneAuthRepository phoneAuthRepository,
  })  : _phoneAuthRepository = phoneAuthRepository,
        super(const PhoneAuthInitialState()) {
    // Register event handlers
    on<SendOTPRequested>(_onSendOTPRequested);
    on<VerifyOTPRequested>(_onVerifyOTPRequested);
    on<ResendOTPRequested>(_onResendOTPRequested);
    on<PhoneAuthResetRequested>(_onPhoneAuthResetRequested);
  }

  /// Handles sending OTP to phone number
  Future<void> _onSendOTPRequested(
    SendOTPRequested event,
    Emitter<PhoneAuthState> emit,
  ) async {
    try {
      emit(const PhoneAuthLoadingState(message: 'Sending OTP...'));

      if (kDebugMode) {
        print(
            '📱 [PHONE AUTH] Sending OTP to ${event.countryCode}${event.phoneNumber}');
      }

      final result = await _phoneAuthRepository.sendOTP(
        phoneNumber: event.phoneNumber,
        countryCode: event.countryCode,
      );

      if (kDebugMode) {
        print('📱 [PHONE AUTH] OTP sent successfully');
      }

      emit(OTPSentState(
        phoneNumber: event.phoneNumber,
        countryCode: event.countryCode,
        expiresIn: result.expiresIn,
        sentAt: DateTime.now(),
      ));
    } catch (failure) {
      if (kDebugMode) {
        print('📱 [PHONE AUTH] Send OTP failed: $failure');
      }

      emit(_mapFailureToErrorState(failure, 'Failed to send OTP'));
    }
  }

  /// Handles OTP verification
  Future<void> _onVerifyOTPRequested(
    VerifyOTPRequested event,
    Emitter<PhoneAuthState> emit,
  ) async {
    try {
      emit(const PhoneAuthLoadingState(message: 'Verifying OTP...'));

      if (kDebugMode) {
        print(
            '📱 [PHONE AUTH] Verifying OTP for ${event.countryCode}${event.phoneNumber}');
      }

      final result = await _phoneAuthRepository.verifyOTP(
        phoneNumber: event.phoneNumber,
        countryCode: event.countryCode,
        otpCode: event.otpCode,
      );

      if (kDebugMode) {
        print('📱 [PHONE AUTH] OTP verified successfully');
        print('📱 [PHONE AUTH] User: ${result.user.email ?? result.user.id}');
        print(
            '📱 [PHONE AUTH] Requires onboarding: ${result.requiresOnboarding}');
      }

      emit(PhoneAuthSuccessState(
        user: result.user,
        session: result.session,
        requiresOnboarding: result.requiresOnboarding,
        onboardingStatus: result.onboardingStatus,
      ));
    } catch (failure) {
      if (kDebugMode) {
        print('📱 [PHONE AUTH] Verify OTP failed: $failure');
      }

      emit(_mapFailureToErrorState(failure, 'Failed to verify OTP'));
    }
  }

  /// Handles resending OTP (same as sending OTP)
  Future<void> _onResendOTPRequested(
    ResendOTPRequested event,
    Emitter<PhoneAuthState> emit,
  ) async {
    try {
      emit(const PhoneAuthLoadingState(message: 'Resending OTP...'));

      if (kDebugMode) {
        print(
            '📱 [PHONE AUTH] Resending OTP to ${event.countryCode}${event.phoneNumber}');
      }

      final result = await _phoneAuthRepository.sendOTP(
        phoneNumber: event.phoneNumber,
        countryCode: event.countryCode,
      );

      if (kDebugMode) {
        print('📱 [PHONE AUTH] OTP resent successfully');
      }

      emit(OTPSentState(
        phoneNumber: event.phoneNumber,
        countryCode: event.countryCode,
        expiresIn: result.expiresIn,
        sentAt: DateTime.now(),
      ));
    } catch (failure) {
      if (kDebugMode) {
        print('📱 [PHONE AUTH] Resend OTP failed: $failure');
      }

      emit(_mapFailureToErrorState(failure, 'Failed to resend OTP'));
    }
  }

  /// Handles resetting phone auth state
  Future<void> _onPhoneAuthResetRequested(
    PhoneAuthResetRequested event,
    Emitter<PhoneAuthState> emit,
  ) async {
    if (kDebugMode) {
      print('📱 [PHONE AUTH] Resetting phone auth state');
    }
    emit(const PhoneAuthInitialState());
  }

  /// Maps failures to appropriate error states
  PhoneAuthErrorState _mapFailureToErrorState(
      dynamic failure, String defaultMessage) {
    if (failure is ValidationFailure) {
      PhoneAuthErrorType errorType = PhoneAuthErrorType.general;

      final message = failure.message.toLowerCase();
      if (message.contains('invalid phone number')) {
        errorType = PhoneAuthErrorType.invalidPhoneNumber;
      } else if (message.contains('invalid otp') ||
          message.contains('otp must be')) {
        errorType = PhoneAuthErrorType.invalidOTP;
      } else if (message.contains('expired')) {
        errorType = PhoneAuthErrorType.otpExpired;
      }

      return PhoneAuthErrorState(
        message: failure.message,
        errorType: errorType,
      );
    }

    if (failure is NetworkFailure) {
      return PhoneAuthErrorState(
        message: failure.message,
        errorType: PhoneAuthErrorType.networkError,
      );
    }

    if (failure is RateLimitFailure) {
      return PhoneAuthErrorState(
        message: failure.message,
        errorType: PhoneAuthErrorType.rateLimitExceeded,
      );
    }

    if (failure is ServerFailure) {
      PhoneAuthErrorType errorType = PhoneAuthErrorType.general;

      final message = failure.message.toLowerCase();
      if (message.contains('sms service') ||
          message.contains('provider not configured') ||
          message.contains('unsupported phone provider')) {
        errorType = PhoneAuthErrorType.providerNotConfigured;
      } else if (message.contains('too many attempts')) {
        errorType = PhoneAuthErrorType.tooManyAttempts;
      }

      return PhoneAuthErrorState(
        message: failure.message,
        errorType: errorType,
      );
    }

    // Default error state
    return PhoneAuthErrorState(
      message: defaultMessage,
    );
  }
}
