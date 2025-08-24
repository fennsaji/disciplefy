import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/services/auth_aware_navigation_service.dart';
import '../../../../core/utils/logger.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart' as auth_states;

/// OTP Verification screen for phone and email authentication
/// Follows Material Design 3 guidelines with accessibility support
class OTPVerificationScreen extends StatefulWidget {
  final String identifier; // Phone number or email
  final String method; // 'phone' or 'email'

  const OTPVerificationScreen({
    super.key,
    required this.identifier,
    required this.method,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;
  
  late AnimationController _shakeAnimationController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _setupAnimations();
    
    // Auto-focus OTP input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    _resendTimer?.cancel();
    _shakeAnimationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _shakeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _shakeAnimationController,
      curve: Curves.elasticIn,
    ));
  }

  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 60;
    
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _triggerShakeAnimation() {
    _shakeAnimationController.forward().then((_) {
      _shakeAnimationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, auth_states.AuthState>(
      listener: (context, state) {
        if (state is auth_states.AuthenticatedState) {
          Logger.info(
            'OTP verification successful - navigating to home',
            tag: 'OTP_SCREEN',
            context: {
              'method': widget.method,
              'user_type': state.isAnonymous ? 'anonymous' : 'authenticated',
            },
          );
          // Use AuthAwareNavigationService for proper post-auth navigation
          context.navigateAfterAuth();
        } else if (state is auth_states.ProfileIncompleteState) {
          Logger.info(
            'First-time user - navigating to profile completion',
            tag: 'OTP_SCREEN',
            context: {
              'method': widget.method,
              'user_id': state.userId,
            },
          );
          context.go('/auth/profile-completion', extra: {
            'user': state.user,
            'isFirstTime': state.isFirstTime,
          });
        } else if (state is auth_states.OTPSentState) {
          // OTP resent successfully
          _startResendTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (state is auth_states.AuthErrorState) {
          Logger.error(
            'OTP verification error',
            tag: 'OTP_SCREEN',
            context: {
              'method': widget.method,
              'identifier': widget.identifier,
              'error': state.message,
            },
          );

          // Clear OTP input and trigger shake animation
          _otpController.clear();
          _triggerShakeAnimation();

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
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
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                
                // Header Section
                _buildHeader(context),
                
                const SizedBox(height: 48),
                
                // OTP Input Section
                _buildOTPInput(context),
                
                const SizedBox(height: 32),
                
                // Verify Button
                _buildVerifyButton(context),
                
                const SizedBox(height: 24),
                
                // Resend Section
                _buildResendSection(context),
                
                const SizedBox(height: 32),
                
                // Help Text
                _buildHelpText(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isPhone = widget.method == 'phone';
    
    return Column(
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPhone ? Icons.sms : Icons.email,
            size: 40,
            color: theme.colorScheme.primary,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Title
        Text(
          'Verification Code',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Subtitle
        Text(
          isPhone
              ? 'We sent a 6-digit code to\\n${widget.identifier}'
              : 'We sent a verification code to\\n${widget.identifier}',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOTPInput(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final offset = sin(_shakeAnimation.value * pi * 2) * 5;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Enter Verification Code',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // OTP Input using Pinput
            Pinput(
              length: 6,
              controller: _otpController,
              focusNode: _otpFocusNode,
              defaultPinTheme: PinTheme(
                width: 48,
                height: 48,
                textStyle: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
              ),
              focusedPinTheme: PinTheme(
                width: 48,
                height: 48,
                textStyle: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              submittedPinTheme: PinTheme(
                width: 48,
                height: 48,
                textStyle: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimary,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              errorPinTheme: PinTheme(
                width: 48,
                height: 48,
                textStyle: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onError,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error,
                    width: 2,
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onCompleted: _handleOTPSubmit,
              onChanged: (value) {
                // Auto-submit when 6 digits are entered
                if (value.length == 6) {
                  _handleOTPSubmit(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyButton(BuildContext context) {
    final theme = Theme.of(context);
    
    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        final isVerifying = state is auth_states.OTPVerifyingState;
        final otpText = _otpController.text;
        final isValidLength = otpText.length == 6;
        
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (isValidLength && !isVerifying) 
                ? () => _handleOTPSubmit(otpText)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            child: isVerifying
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(
                    'Verify Code',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildResendSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        final isLoading = state is auth_states.AuthLoadingState;
        
        return Column(
          children: [
            Text(
              'Didn\'t receive the code?',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 8),
            
            if (_canResend && !isLoading)
              TextButton(
                onPressed: _handleResendOTP,
                child: Text(
                  'Resend Code',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            else
              Text(
                'Resend in ${_resendCountdown}s',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHelpText(BuildContext context) {
    final theme = Theme.of(context);
    final isPhone = widget.method == 'phone';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPhone
                  ? 'Check your SMS messages. The code expires in 10 minutes.'
                  : 'Check your email inbox and spam folder. The code expires in 10 minutes.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOTPSubmit(String otp) {
    if (otp.length == 6) {
      // Haptic feedback
      HapticFeedback.lightImpact();
      
      // Submit OTP for verification
      context.read<AuthBloc>().add(
        OTPVerificationRequested(
          otp: otp,
          identifier: widget.identifier,
          method: widget.method,
        ),
      );
    }
  }

  void _handleResendOTP() {
    // Haptic feedback
    HapticFeedback.selectionClick();
    
    // Resend OTP based on method
    if (widget.method == 'phone') {
      context.read<AuthBloc>().add(
        PhoneSignInRequested(phoneNumber: widget.identifier),
      );
    } else {
      context.read<AuthBloc>().add(
        EmailSignInRequested(email: widget.identifier),
      );
    }
  }
}

