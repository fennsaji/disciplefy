import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/phone_auth_bloc.dart';
import '../bloc/phone_auth_event.dart';
import '../bloc/phone_auth_state.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/logger.dart';

/// Phone number input screen for phone authentication
class PhoneNumberInputScreen extends StatefulWidget {
  const PhoneNumberInputScreen({super.key});

  @override
  State<PhoneNumberInputScreen> createState() => _PhoneNumberInputScreenState();
}

class _PhoneNumberInputScreenState extends State<PhoneNumberInputScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Country code options
  String _selectedCountryCode = '+1';
  final Map<String, String> _countryCodes = {
    '+1': '🇺🇸 United States',
    '+91': '🇮🇳 India',
    '+44': '🇬🇧 United Kingdom',
    '+49': '🇩🇪 Germany',
    '+33': '🇫🇷 France',
    '+81': '🇯🇵 Japan',
    '+86': '🇨🇳 China',
    '+55': '🇧🇷 Brazil',
    '+61': '🇦🇺 Australia',
    '+7': '🇷🇺 Russia',
  };

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PhoneAuthBloc, PhoneAuthState>(
      listener: (context, state) {
        if (state is OTPSentState) {
          Logger.info(
            'OTP sent successfully - navigating to verification',
            tag: 'PHONE_AUTH',
            context: {
              'phone_number': state.formattedPhoneNumber,
              'expires_in': state.expiresIn,
            },
          );

          // Navigate to OTP verification screen
          context.push(AppRoutes.phoneAuthVerify, extra: {
            'phoneNumber':
                state.phoneNumber, // Just the phone number without country code
            'countryCode': state.countryCode, // Country code separate
            'expiresIn': state.expiresIn,
            'sentAt': state.sentAt,
          });
        } else if (state is PhoneAuthErrorState) {
          Logger.error(
            'Phone auth error occurred',
            tag: 'PHONE_AUTH',
            context: {
              'error_type': state.errorType.toString(),
              'error_message': state.message,
            },
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              action: state.errorType == PhoneAuthErrorType.networkError
                  ? SnackBarAction(
                      label: 'Retry',
                      onPressed: () => _sendOTP(),
                    )
                  : null,
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
          title: Text(
            'Phone Number',
            style: GoogleFonts.inter(
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

                // Phone input form
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPhoneInputSection(context),
                        const SizedBox(height: 24),
                        _buildInfoSection(context),
                        const Spacer(),
                        _buildSendOTPButton(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the header section with title and description
  Widget _buildHeaderSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your phone number',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll send you a verification code to confirm your number',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// Builds the phone input section with country code dropdown
  Widget _buildPhoneInputSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code dropdown
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCountryCode = newValue;
                      });
                    }
                  },
                  items: _countryCodes.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        '${entry.value.split(' ')[0]} ${entry.key}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Phone number input
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  hintStyle: GoogleFonts.inter(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 7) {
                    return 'Phone number is too short';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Clear validation errors on input
                  if (value.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the info section with security and privacy notes
  Widget _buildInfoSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Secure Verification',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your phone number will be used only for authentication and will not be shared with third parties.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the send OTP button
  Widget _buildSendOTPButton(BuildContext context) {
    return BlocBuilder<PhoneAuthBloc, PhoneAuthState>(
      builder: (context, state) {
        final isLoading = state is PhoneAuthLoadingState;
        final theme = Theme.of(context);

        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : _sendOTP,
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
                    'Send Verification Code',
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

  /// Sends OTP to the entered phone number
  void _sendOTP() {
    if (_formKey.currentState?.validate() ?? false) {
      final phoneNumber = _phoneController.text.trim();

      Logger.info(
        'Sending OTP request',
        tag: 'PHONE_AUTH',
        context: {
          'country_code': _selectedCountryCode,
          'phone_length': phoneNumber.length,
        },
      );

      context.read<PhoneAuthBloc>().add(
            SendOTPRequested(
              phoneNumber: phoneNumber,
              countryCode: _selectedCountryCode,
            ),
          );
    }
  }
}
