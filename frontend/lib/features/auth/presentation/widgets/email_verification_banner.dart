import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';

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
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is AuthErrorState) {
          setState(() => _isResending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr(TranslationKeys.commonErrorTryAgain)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        // Only show for authenticated users who need email verification
        if (state is! AuthenticatedState || !state.needsEmailVerification) {
          return const SizedBox.shrink();
        }

        final palette = ReaderPalette.of(context);
        final amber = SettingsToneColors.of(context, SettingsTone.amber);
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: palette.isDark
                ? amber.foreground.withValues(alpha: 0.12)
                : amber.fill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.mail_outline_rounded,
                  size: 18, color: amber.foreground),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Text(
                  context.tr(TranslationKeys.emailVerificationTitle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Tooltip carries the full "Resend verification email" wording
              // the short label leaves out.
              // Flexible: long hi/ml labels wrap instead of overflowing.
              Flexible(
                flex: 2,
                child: Tooltip(
                  message: context.tr(TranslationKeys.emailVerificationResend),
                  child: TextButton(
                    onPressed: _isResending ? null : _onResendVerification,
                    style: TextButton.styleFrom(
                      foregroundColor: amber.foreground,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(48, 40),
                    ),
                    child: _isResending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  amber.foreground),
                            ),
                          )
                        : Text(
                            context.tr(
                                TranslationKeys.emailVerificationResendShort),
                            textAlign: TextAlign.center,
                            style: AppFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: amber.foreground,
                            ),
                          ),
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
