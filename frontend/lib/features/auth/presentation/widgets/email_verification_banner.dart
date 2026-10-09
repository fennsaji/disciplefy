import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

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
          showAppSnackBar(
            context,
            context.tr(TranslationKeys.emailVerificationSent),
            tone: AppSnackTone.success,
          );
        } else if (state is AuthErrorState) {
          setState(() => _isResending = false);
          showAppSnackBar(
            context,
            context.tr(TranslationKeys.commonErrorTryAgain),
            tone: AppSnackTone.error,
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
        // One line, as in the design: icon, "Verify your email to secure
        // your account" and a short "Resend" action. Long hi/ml copy wraps.
        return Container(
          key: const Key('email_verification_banner'),
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            color: palette.isDark
                ? amber.foreground.withValues(alpha: 0.10)
                : amber.fill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: LayoutBuilder(builder: (context, box) {
            final resend = _resendButton(context, amber);
            final label = Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                context.tr(TranslationKeys.emailVerificationShortTitle),
                style: AppFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.3,
                ),
              ),
            );
            // A long "Resend" (Malayalam) moves under the line instead of
            // squeezing it into a narrow column.
            final painter = TextPainter(
              text: TextSpan(
                text: context.tr(TranslationKeys.emailVerificationResendShort),
                style:
                    AppFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final resendWide = painter.width + 16 > box.maxWidth * 0.3;
            painter.dispose();
            final icon = Icon(Icons.mail_outline_rounded,
                size: 16, color: amber.foreground);
            if (resendWide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    icon,
                    const SizedBox(width: 10),
                    Expanded(child: label),
                  ]),
                  Align(
                      alignment: AlignmentDirectional.centerEnd, child: resend),
                ],
              );
            }
            return Row(children: [
              icon,
              const SizedBox(width: 10),
              Expanded(child: label),
              resend,
            ]);
          }),
        );
      },
    );
  }

  Widget _resendButton(BuildContext context, SettingsToneColors amber) {
    return TextButton(
      onPressed: _isResending ? null : _onResendVerification,
      style: TextButton.styleFrom(
        foregroundColor: amber.foreground,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: _isResending
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(amber.foreground),
              ),
            )
          : Text(
              context.tr(TranslationKeys.emailVerificationResendShort),
              style: AppFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: amber.foreground,
              ),
            ),
    );
  }

  void _onResendVerification() {
    setState(() => _isResending = true);
    context.read<AuthBloc>().add(const ResendVerificationEmailRequested());
  }
}
