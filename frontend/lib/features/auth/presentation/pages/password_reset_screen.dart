import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/domain/utils/auth_validator.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// Password reset: asks for the account email and sends a reset link, then
/// shows a "check your email" confirmation. Same photo-header chrome as the
/// email sign-in screen it is opened from.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AuthBloc, auth_states.AuthState>(
        listener: (context, state) {
          if (state is auth_states.PasswordResetSentState) {
            setState(() => _emailSent = true);
          } else if (state is auth_states.AuthErrorState) {
            showAppSnackBar(
              context,
              context.tr(TranslationKeys.commonErrorTryAgain),
              tone: AppSnackTone.error,
            );
          }
        },
        child: Scaffold(
          backgroundColor: ReaderPalette.of(context).page,
          body: _buildBody(context),
        ),
      );

  Widget _buildBody(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + 230,
            child: const WelcomePhotoBackdrop(
              asset: WelcomePhotos.valleyMist,
              alignment: Alignment.bottomCenter,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(24, topInset + 8, 24, bottomInset + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const Key('password_reset_back'),
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        icon: Icon(
                          Icons.arrow_back,
                          color: palette.isDark ? Colors.white : palette.text,
                        ),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(height: 64),
                    if (_emailSent)
                      _buildSuccessContent(context)
                    else
                      _buildFormContent(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Muted Inter paragraph under a title.
  Widget _subtitle(BuildContext context, String text) {
    final palette = ReaderPalette.of(context);
    return Text(
      text,
      style: AppFonts.inter(
        fontSize: 15.5,
        height: 1.45,
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.75)
            : palette.muted,
      ),
    );
  }

  Widget _buildFormContent(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WelcomeEyebrow(context.tr(TranslationKeys.passwordResetEyebrow)),
          const SizedBox(height: 10),
          WelcomeTitle(
            context.tr(TranslationKeys.passwordResetTitle),
            fontSize: isNarrow ? 28 : 32,
          ),
          const SizedBox(height: 10),
          _subtitle(context, context.tr(TranslationKeys.passwordResetSubtitle)),
          const SizedBox(height: 32),
          _buildEmailField(context),
          const SizedBox(height: 32),
          _buildSubmitButton(context),
          const SizedBox(height: 10),
          _buildBackToSignInLink(context),
        ],
      ),
    );
  }

  Widget _buildSuccessContent(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: PopupIconCircle(
            icon: Icons.mark_email_read_outlined,
            tone: PopupTone.gold,
            size: 60,
          ),
        ),
        const SizedBox(height: 20),
        WelcomeEyebrow(context.tr(TranslationKeys.passwordResetSuccess)),
        const SizedBox(height: 10),
        WelcomeTitle(
          context.tr(TranslationKeys.passwordResetSuccessTitle),
          fontSize: isNarrow ? 28 : 32,
        ),
        const SizedBox(height: 10),
        _subtitle(
            context, context.tr(TranslationKeys.passwordResetSuccessMessage)),
        const SizedBox(height: 36),
        WelcomePrimaryButton(
          key: const Key('password_reset_done'),
          label: context.tr(TranslationKeys.passwordResetBackToSignIn),
          onPressed: () => context.pop(),
        ),
        const SizedBox(height: 10),
        _buildResendLink(context),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    final radius = BorderRadius.circular(16);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            context.tr(TranslationKeys.passwordResetEmail),
            style: AppFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: palette.muted,
            ),
          ),
        ),
        TextFormField(
          key: const Key('password_reset_email'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          onFieldSubmitted: (_) => _handleSubmit(context),
          style: AppFonts.inter(fontSize: 15.5, color: palette.text),
          decoration: InputDecoration(
            hintText: context.tr(TranslationKeys.passwordResetEmailHint),
            hintMaxLines: 2,
            hintStyle: AppFonts.inter(fontSize: 15.5, color: palette.dim),
            prefixIcon: Icon(Icons.mail_outline_rounded,
                size: 21, color: palette.muted),
            filled: true,
            fillColor: palette.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            border: border(palette.outline),
            enabledBorder: border(palette.outline),
            focusedBorder: border(palette.accentIcon, 1.5),
            errorBorder: border(error),
            focusedErrorBorder: border(error, 1.5),
            errorMaxLines: 3,
          ),
          validator: (value) {
            if (value == null || !AuthValidator.isValidEmail(value)) {
              return context.tr(TranslationKeys.passwordResetInvalidEmail);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        return WelcomePrimaryButton(
          key: const Key('password_reset_submit'),
          label: context.tr(TranslationKeys.passwordResetSendButton),
          isLoading: state is auth_states.AuthLoadingState,
          onPressed: () => _handleSubmit(context),
        );
      },
    );
  }

  /// Muted full-width text link.
  Widget _textLink(
    BuildContext context, {
    required Key key,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final palette = ReaderPalette.of(context);
    final color = onPressed == null ? palette.dim : palette.muted;
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        key: key,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildBackToSignInLink(BuildContext context) => _textLink(
        context,
        key: const Key('password_reset_back_to_sign_in'),
        label: context.tr(TranslationKeys.passwordResetBackToSignIn),
        onPressed: () => context.pop(),
      );

  Widget _buildResendLink(BuildContext context) {
    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        final isLoading = state is auth_states.AuthLoadingState;
        return _textLink(
          context,
          key: const Key('password_reset_resend'),
          label: context.tr(TranslationKeys.passwordResetResend),
          onPressed:
              isLoading ? null : () => setState(() => _emailSent = false),
        );
      },
    );
  }

  void _handleSubmit(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            PasswordResetRequested(
              email: _emailController.text.trim(),
            ),
          );
    }
  }
}
