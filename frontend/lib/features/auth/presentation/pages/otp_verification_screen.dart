import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/phone_auth_bloc.dart';
import '../bloc/phone_auth_event.dart';
import '../bloc/phone_auth_state.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../../../../core/services/auth_aware_navigation_service.dart';
import '../../../../core/utils/logger.dart';

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

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Something went wrong. Please try again.'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  action: state.errorType == PhoneAuthErrorType.networkError
                      ? SnackBarAction(
                          label: 'Retry',
                          onPressed: () => _verifyOTP(),
                        )
                      : null,
                ),
              );

              // Clear OTP fields on error
              _clearOTPFields();
            } else if (state is OTPSentState) {
              Logger.info(
                'OTP resent successfully',
                tag: 'PHONE_AUTH',
                context: {
                  'phone_number': state.formattedPhoneNumber,
                  'expires_in': state.expiresIn,
                },
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Verification code sent!'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                ),
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
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Verify Phone',
            style: AppFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                _buildHeaderSection(context),

                const SizedBox(height: 32),

                // OTP input section
                _buildOTPInputSection(context),

                const SizedBox(height: 24),

                // Timer and resend section
                _buildTimerSection(context),

                const SizedBox(height: 32),

                // Info section
                _buildInfoSection(context),

                const Spacer(),

                // Verify button
                _buildVerifyButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the header section with title and phone number
  Widget _buildHeaderSection(BuildContext context) {
    final theme = Theme.of(context);
    final formattedPhone = '${widget.countryCode} ${widget.phoneNumber}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter verification code',
          style: AppFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: AppFonts.inter(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'We sent a code to '),
              TextSpan(
                text: formattedPhone,
                style: AppFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the OTP input section with 6 digit fields
  Widget _buildOTPInputSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verification Code',
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextFormField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.error,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: AppFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
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
            );
          }),
        ),
      ],
    );
  }

  /// Builds the timer and resend section
  Widget _buildTimerSection(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          if (!_canResend) ...[
            Text(
              'Code expires in ${_formatTime(_remainingSeconds)}',
              style: AppFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextButton(
            onPressed: _canResend ? _resendOTP : null,
            child: Text(
              _canResend
                  ? 'Resend Code'
                  : 'Resend in ${_formatTime(_remainingSeconds)}',
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _canResend
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the info section
  Widget _buildInfoSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Didn\'t receive the code? Check your spam folder or try resending.',
              style: AppFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.4,
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
        final isLoading = state is PhoneAuthLoadingState;
        final theme = Theme.of(context);
        final otpCode = _getOTPCode();
        final isOTPComplete = otpCode.length == 6;

        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (isLoading || !isOTPComplete) ? null : _verifyOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor:
                  theme.colorScheme.primary.withOpacity(0.5),
            ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.onPrimary),
                    ),
                  )
                : Text(
                    'Verify Code',
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the complete 6-digit code'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Logger.info(
      'Verifying OTP',
      tag: 'PHONE_AUTH',
      context: {
        'country_code': widget.countryCode,
        'phone_number': widget.phoneNumber,
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
      context: {
        'country_code': widget.countryCode,
        'phone_number': widget.phoneNumber,
      },
    );

    context.read<PhoneAuthBloc>().add(
          ResendOTPRequested(
            phoneNumber: widget.phoneNumber,
            countryCode: widget.countryCode,
          ),
        );
  }
}
