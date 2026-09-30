import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/phone_auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/phone_auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/phone_auth_state.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_form.dart';

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
            context: {'expires_in': state.expiresIn},
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

          final canRetry = state.errorType == PhoneAuthErrorType.networkError;
          showAppSnackBar(
            context,
            context.tr(TranslationKeys.commonErrorTryAgain),
            tone: AppSnackTone.error,
            actionLabel:
                canRetry ? context.tr(TranslationKeys.commonRetry) : null,
            onAction: canRetry ? _sendOTP : null,
          );
        }
      },
      child: WelcomeFormPage(
        photo: WelcomePhotos.wheatDawn,
        backKey: const Key('phone_auth_back'),
        eyebrow: context.tr(TranslationKeys.phoneAuthEyebrow),
        title: context.tr(TranslationKeys.phoneAuthTitle),
        subtitle:
            WelcomeSubtitle(context.tr(TranslationKeys.phoneAuthSubtitle)),
        children: [
          Form(
            key: _formKey,
            child: _buildPhoneInputSection(context),
          ),
          const SizedBox(height: 20),
          WelcomeInfoCard(
            icon: Icons.shield_outlined,
            title: context.tr(TranslationKeys.phoneAuthSecureTitle),
            body: context.tr(TranslationKeys.phoneAuthSecureBody),
          ),
          const SizedBox(height: 36),
          _buildSendOTPButton(context),
        ],
      ),
    );
  }

  /// Country code picker and phone number field.
  Widget _buildPhoneInputSection(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WelcomeFieldLabel(context.tr(TranslationKeys.phoneAuthPhoneLabel)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: context.tr(TranslationKeys.phoneAuthCountryCode),
              child: Container(
                key: const Key('phone_auth_country_code'),
                height: 56,
                padding: const EdgeInsets.only(left: 14, right: 6),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.outline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    dropdownColor: palette.card,
                    borderRadius: BorderRadius.circular(16),
                    iconEnabledColor: palette.muted,
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
                          style: AppFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: palette.text,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                key: const Key('phone_auth_number'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                onFieldSubmitted: (_) => _sendOTP(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                style: welcomeFieldTextStyle(context),
                decoration: welcomeFieldDecoration(
                  context,
                  hint: context.tr(TranslationKeys.phoneAuthPhoneHint),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.tr(TranslationKeys.phoneAuthPhoneRequired);
                  }
                  if (value.length < 7) {
                    return context.tr(TranslationKeys.phoneAuthPhoneTooShort);
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

  /// Builds the send OTP button
  Widget _buildSendOTPButton(BuildContext context) {
    return BlocBuilder<PhoneAuthBloc, PhoneAuthState>(
      builder: (context, state) => WelcomePrimaryButton(
        key: const Key('phone_auth_send'),
        label: context.tr(TranslationKeys.phoneAuthSendCode),
        isLoading: state is PhoneAuthLoadingState,
        onPressed: _sendOTP,
      ),
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
