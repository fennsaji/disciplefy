import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/phone_auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/phone_auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/phone_auth_state.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_form.dart';

/// OTP verification screen for phone authentication
class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;
  final int expiresIn;
  final DateTime sentAt;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.countryCode,
    required this.expiresIn,
    required this.sentAt,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  Timer? _timer;
  int _remainingSeconds = 0;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    final expiryTime = widget.sentAt.add(Duration(seconds: widget.expiresIn));
    _remainingSeconds = expiryTime.difference(DateTime.now()).inSeconds;

    if (_remainingSeconds <= 0) {
      setState(() {
        _canResend = true;
        _remainingSeconds = 0;
      });
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds = expiryTime.difference(DateTime.now()).inSeconds;
        if (_remainingSeconds <= 0) {
          _remainingSeconds = 0;
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PhoneAuthBloc, PhoneAuthState>(
          listener: (context, state) {
            if (state is PhoneAuthSuccessState) {
              Logger.info(
                '🎉 Phone auth successful - session already established by native Supabase auth',
                tag: 'PHONE_AUTH_FLOW',
                context: {
                  'user_id': state.user.id,
                  'requires_onboarding': state.requiresOnboarding,
                  'session_user_id': state.session.user.id,
                  'current_supabase_user':
                      Supabase.instance.client.auth.currentUser?.id,
                  'current_supabase_session':
                      Supabase.instance.client.auth.currentSession != null,
                },
              );

              // Update main auth bloc with successful phone auth
              // This will trigger auth state change and let the router handle navigation
              context.read<AuthBloc>().add(
                    AuthStateChanged(
                        AuthState(AuthChangeEvent.signedIn, state.session)),
                  );

              Logger.info(
                '✅ Auth state updated - native Supabase auth session is active',
                tag: 'PHONE_AUTH_FLOW',
                context: {
                  'next_step': 'router_should_detect_authenticated_session',
                  'expected_outcome': 'automatic_navigation_by_router_guard',
                },
              );

              // Give auth state and session establishment time to complete, then navigate
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (!mounted) {
                  Logger.warning(
                    '⚠️ Widget unmounted, skipping navigation',
                    tag: 'PHONE_AUTH_FLOW',
                    context: {'reason': 'widget_disposed'},
                  );
                  return;
                }

                Logger.info(
                  '🧭 Direct navigation after session establishment delay',
                  tag: 'PHONE_AUTH_FLOW',
                  context: {
                    'requires_onboarding': state.requiresOnboarding,
                    'navigation_target':
                        state.requiresOnboarding ? '/language-selection' : '/',
                    'supabase_user_check':
                        Supabase.instance.client.auth.currentUser?.id,
                    'supabase_session_check':
                        Supabase.instance.client.auth.currentSession != null,
                    'reason': 'router_not_triggering_automatically',
                  },
                );

                // Navigate directly based on onboarding requirements
                // This bypasses the router's automatic redirect logic that isn't working
                if (state.requiresOnboarding) {
                  Logger.info(
                    '🎯 Navigating to profile setup for new user',
                    tag: 'PHONE_AUTH_FLOW',
                    context: {'destination': '/profile-setup'},
                  );
                  context.go('/profile-setup');
                } else {
                  Logger.info(
                    '🏠 Navigating to home for existing user',
                    tag: 'PHONE_AUTH_FLOW',
                    context: {'destination': '/'},
                  );
                  context.go('/');
                }
              });
            } else if (state is PhoneAuthErrorState) {
              Logger.error(
                'OTP verification error',
                tag: 'PHONE_AUTH',
                context: {
                  'error_type': state.errorType.toString(),
                  'error_message': state.message,
                },
              );

              final canRetry =
                  state.errorType == PhoneAuthErrorType.networkError;
              showAppSnackBar(
                context,
                context.tr(TranslationKeys.commonErrorTryAgain),
                tone: AppSnackTone.error,
                actionLabel:
                    canRetry ? context.tr(TranslationKeys.commonRetry) : null,
                onAction: canRetry ? _verifyOTP : null,
              );

              // Clear OTP fields on error
              _clearOTPFields();
            } else if (state is OTPSentState) {
              Logger.info(
                'OTP resent successfully',
                tag: 'PHONE_AUTH',
                context: {'expires_in': state.expiresIn},
              );

              showAppSnackBar(
                context,
                context.tr(TranslationKeys.authOtpCodeSent),
                tone: AppSnackTone.success,
              );

              // Restart timer with new expiry
              _timer?.cancel();
              setState(() {
                _canResend = false;
              });
              _startTimer();
            }
          },
        ),
      ],
      child: WelcomeFormPage(
        photo: WelcomePhotos.wheatDawn,
        backKey: const Key('otp_back'),
        eyebrow: context.tr(TranslationKeys.phoneAuthOtpEyebrow),
        title: context.tr(TranslationKeys.phoneAuthOtpTitle),
        subtitle: _buildSentToLine(context),
        children: [
          _buildOTPInputSection(context),
          const SizedBox(height: 20),
          _buildTimerSection(context),
          const SizedBox(height: 20),
          WelcomeInfoCard(
            icon: Icons.info_outline_rounded,
            body: context.tr(TranslationKeys.phoneAuthOtpHelp),
          ),
          const SizedBox(height: 36),
          _buildVerifyButton(context),
        ],
      ),
    );
  }

  /// "We sent a code to {phone}" with the number emphasised.
  Widget _buildSentToLine(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final formattedPhone = '${widget.countryCode} ${widget.phoneNumber}';
    final sentence = context.tr(TranslationKeys.phoneAuthOtpSentTo,
        {'phone': '\u0000'}).split('\u0000');
    final style = welcomeSubtitleStyle(context);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: sentence.first),
          TextSpan(
            text: formattedPhone,
            style: style.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.isDark ? Colors.white : palette.text,
            ),
          ),
          if (sentence.length > 1) TextSpan(text: sentence.sublist(1).join()),
        ],
      ),
    );
  }

  /// Six single-digit fields that advance focus as digits are typed.
  Widget _buildOTPInputSection(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WelcomeFieldLabel(context.tr(TranslationKeys.phoneAuthOtpLabel)),
        Row(
          children: [
            for (var index = 0; index < 6; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: context.tr(
                    TranslationKeys.phoneAuthOtpDigit,
                    {'n': '${index + 1}'},
                  ),
                  child: TextFormField(
                    key: Key('otp_digit_$index'),
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    autofillHints:
                        index == 0 ? const [AutofillHints.oneTimeCode] : null,
                    maxLength: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: welcomeFieldDecoration(
                      context,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    style: AppFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                    onChanged: (value) {
                      setState(() {
                        // State update to trigger button rebuild
                      });

                      if (value.isNotEmpty && index < 5) {
                        // Move to next field
                        _otpFocusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        // Move to previous field
                        _otpFocusNodes[index - 1].requestFocus();
                      }

                      // Auto-verify when all fields are filled
                      if (index == 5 && value.isNotEmpty) {
                        final otp = _getOTPCode();
                        if (otp.length == 6) {
                          _verifyOTP();
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Expiry countdown and the resend link.
  Widget _buildTimerSection(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final time = _formatTime(_remainingSeconds);

    return Center(
      child: Column(
        children: [
          if (!_canResend) ...[
            Text(
              context.tr(TranslationKeys.phoneAuthOtpExpiresIn, {'time': time}),
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 14, color: palette.muted),
            ),
            const SizedBox(height: 4),
          ],
          TextButton(
            key: const Key('otp_resend'),
            onPressed: _canResend ? _resendOTP : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: palette.accentIcon,
            ),
            child: Text(
              _canResend
                  ? context.tr(TranslationKeys.phoneAuthOtpResend)
                  : context
                      .tr(TranslationKeys.phoneAuthOtpResendIn, {'time': time}),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: _canResend ? palette.accentIcon : palette.dim,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the verify button
  Widget _buildVerifyButton(BuildContext context) {
    return BlocBuilder<PhoneAuthBloc, PhoneAuthState>(
      builder: (context, state) {
        final isOTPComplete = _getOTPCode().length == 6;
        return WelcomePrimaryButton(
          key: const Key('otp_verify'),
          label: context.tr(TranslationKeys.phoneAuthOtpVerify),
          isLoading: state is PhoneAuthLoadingState,
          onPressed: isOTPComplete ? _verifyOTP : null,
        );
      },
    );
  }

  /// Gets the complete OTP code from all fields
  String _getOTPCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  /// Clears all OTP input fields
  void _clearOTPFields() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes[0].requestFocus();
  }

  /// Formats time in MM:SS format
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Verifies the entered OTP
  void _verifyOTP() {
    final otpCode = _getOTPCode();

    if (otpCode.length != 6) {
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.authOtpIncomplete),
        tone: AppSnackTone.warning,
      );
      return;
    }

    Logger.info(
      'Verifying OTP',
      tag: 'PHONE_AUTH',
      context: {
        'country_code': widget.countryCode,
        'otp_length': otpCode.length,
      },
    );

    context.read<PhoneAuthBloc>().add(
          VerifyOTPRequested(
            phoneNumber: widget.phoneNumber,
            countryCode: widget.countryCode,
            otpCode: otpCode,
          ),
        );
  }

  /// Resends the OTP
  void _resendOTP() {
    Logger.info(
      'Resending OTP',
      tag: 'PHONE_AUTH',
      context: {'country_code': widget.countryCode},
    );

    context.read<PhoneAuthBloc>().add(
          ResendOTPRequested(
            phoneNumber: widget.phoneNumber,
            countryCode: widget.countryCode,
          ),
        );
  }
}
