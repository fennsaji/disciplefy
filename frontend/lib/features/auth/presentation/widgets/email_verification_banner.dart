import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// A persistent banner prompting users to verify their email address.
///
/// This banner is shown to email/password users who haven't verified
/// their email yet. It provides a clear call-to-action to resend the
/// verification email.
///
/// The banner is persistent and cannot be permanently dismissed - it will
/// reappear each session until the user verifies their email. This ensures
/// users are reminded to verify their email for account security.
class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  State<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  bool _isResending = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is VerificationEmailSentState) {
          setState(() => _isResending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr(TranslationKeys.emailVerificationSent)),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is AuthErrorState) {
          setState(() => _isResending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        // Only show for authenticated users who need email verification
        if (state is! AuthenticatedState || !state.needsEmailVerification) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.warningColor.withAlpha(77),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.email_outlined,
                    color: AppTheme.warningColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(TranslationKeys.emailVerificationTitle),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.warningColor,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context
                              .tr(TranslationKeys.emailVerificationDescription),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Resend verification email button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isResending ? null : _onResendVerification,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warningColor,
                    side: BorderSide(color: AppTheme.warningColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isResending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.warningColor,
                            ),
                          ),
                        )
                      : Text(
                          context.tr(TranslationKeys.emailVerificationResend),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onResendVerification() {
    setState(() => _isResending = true);
    context.read<AuthBloc>().add(const ResendVerificationEmailRequested());
  }
}
