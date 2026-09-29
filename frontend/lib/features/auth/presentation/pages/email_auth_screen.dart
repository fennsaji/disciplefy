import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/auth_aware_navigation_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/auth/domain/utils/auth_validator.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/terms_acceptance_checkbox.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// Email authentication: one screen toggling between sign in and create
/// account, with a photo header per mode ("V1 Photo Story" design).
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AuthBloc, auth_states.AuthState>(
        listener: (context, state) {
          if (state is auth_states.AuthenticatedState) {
            // Commit the autofill context so the OS (iOS Keychain / Android
            // Google Password Manager) offers to SAVE the entered credentials.
            TextInput.finishAutofillContext();
            // Successfully authenticated - navigate to home
            context.navigateAfterAuth();
          } else if (state is auth_states.AuthErrorState) {
            // Show error message
            final theme = Theme.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: theme.colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
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
    final headerHeight = topInset + 230;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: WelcomePhotoBackdrop(
              key: ValueKey(_isSignUp),
              asset: _isSignUp
                  ? WelcomePhotos.greenHills
                  : WelcomePhotos.wheatDawn,
              alignment: Alignment.bottomCenter,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(24, topInset + 8, 24, bottomInset + 24),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            key: const Key('email_auth_back'),
                            tooltip: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            icon: Icon(
                              Icons.arrow_back,
                              color:
                                  palette.isDark ? Colors.white : palette.text,
                            ),
                            onPressed: () => context.pop(),
                          ),
                        ),
                        const SizedBox(height: 64),

                        // Eyebrow + title
                        _buildTitle(context),

                        const SizedBox(height: 36),

                        // Name field (only for sign up)
                        if (_isSignUp) ...[
                          _buildNameField(context),
                          const SizedBox(height: 18),
                        ],

                        // Email field
                        _buildEmailField(context),

                        const SizedBox(height: 18),

                        // Password field
                        _buildPasswordField(context),

                        // Forgot password link (only for sign in)
                        if (!_isSignUp) ...[
                          const SizedBox(height: 6),
                          _buildForgotPasswordLink(context),
                        ],

                        const SizedBox(height: 36),

                        // Submit button
                        _buildSubmitButton(context),

                        const SizedBox(height: 10),

                        // Toggle between sign in and sign up
                        _buildToggleAuthMode(context),

                        if (_isSignUp) ...[
                          const SizedBox(height: 32),
                          LegalLinksLine(
                            textColor: palette.dim,
                            linkColor: palette.muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WelcomeEyebrow(
          context.tr(_isSignUp
              ? TranslationKeys.emailAuthSignUpEyebrow
              : TranslationKeys.emailAuthSignInEyebrow),
        ),
        const SizedBox(height: 10),
        WelcomeTitle(
          context.tr(_isSignUp
              ? TranslationKeys.emailAuthSignUpTitle
              : TranslationKeys.emailAuthSignInTitle),
          fontSize: MediaQuery.sizeOf(context).width < 360 ? 28 : 32,
        ),
      ],
    );
  }

  /// Label shown above a field.
  Widget _fieldLabel(BuildContext context, String text) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: palette.muted,
        ),
      ),
    );
  }

  /// Filled field decoration with a leading icon and hairline border.
  InputDecoration _fieldDecoration(
    BuildContext context, {
    required IconData icon,
    required String hint,
    Widget? suffix,
  }) {
    final palette = ReaderPalette.of(context);
    final radius = BorderRadius.circular(16);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: AppFonts.inter(fontSize: 15.5, color: palette.dim),
      prefixIcon: Icon(icon, size: 21, color: palette.muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: palette.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: border(palette.outline),
      enabledBorder: border(palette.outline),
      focusedBorder: border(palette.accentIcon, 1.5),
      errorBorder: border(Theme.of(context).colorScheme.error),
      focusedErrorBorder: border(Theme.of(context).colorScheme.error, 1.5),
      errorMaxLines: 3,
    );
  }

  TextStyle _fieldTextStyle(BuildContext context) =>
      AppFonts.inter(fontSize: 15.5, color: ReaderPalette.of(context).text);

  Widget _buildNameField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, context.tr(TranslationKeys.emailAuthFullName)),
        TextFormField(
          key: const Key('email_auth_name'),
          controller: _nameController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          textCapitalization: TextCapitalization.words,
          style: _fieldTextStyle(context),
          decoration: _fieldDecoration(
            context,
            icon: Icons.person_outline_rounded,
            hint: context.tr(TranslationKeys.emailAuthFullNameHint),
          ),
          validator: (value) {
            if (value == null || !AuthValidator.isValidFullName(value)) {
              return context.tr(TranslationKeys.emailAuthInvalidName);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, context.tr(TranslationKeys.emailAuthEmail)),
        TextFormField(
          key: const Key('email_auth_email'),
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          autocorrect: false,
          style: _fieldTextStyle(context),
          decoration: _fieldDecoration(
            context,
            icon: Icons.mail_outline_rounded,
            hint: context.tr(TranslationKeys.emailAuthEmailHint),
          ),
          validator: (value) {
            if (value == null || !AuthValidator.isValidEmail(value)) {
              return context.tr(TranslationKeys.emailAuthInvalidEmail);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, context.tr(TranslationKeys.emailAuthPassword)),
        TextFormField(
          key: const Key('email_auth_password'),
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleSubmit(context),
          autofillHints: _isSignUp
              ? const [AutofillHints.newPassword]
              : const [AutofillHints.password],
          autocorrect: false,
          style: _fieldTextStyle(context),
          decoration: _fieldDecoration(
            context,
            icon: Icons.lock_outline_rounded,
            hint: context.tr(_isSignUp
                ? TranslationKeys.emailAuthNewPasswordHint
                : TranslationKeys.emailAuthPasswordHint),
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 21,
                color: palette.muted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (_isSignUp &&
                (value == null || !AuthValidator.isValidPassword(value))) {
              return context.tr(TranslationKeys.emailAuthInvalidPassword);
            }
            if (!_isSignUp && (value == null || value.isEmpty)) {
              return context.tr(TranslationKeys.emailAuthPasswordHint);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildForgotPasswordLink(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => context.push(AppRoutes.passwordReset),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(44, 44),
          foregroundColor: palette.accentIcon,
        ),
        child: Text(
          context.tr(TranslationKeys.emailAuthForgotPassword),
          style: AppFonts.inter(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: palette.accentIcon,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        final isLoading = state is auth_states.AuthLoadingState;

        return WelcomePrimaryButton(
          key: const Key('email_auth_submit'),
          label: _isSignUp
              ? context.tr(TranslationKeys.emailAuthSignUpButton)
              : context.tr(TranslationKeys.emailAuthSignInButton),
          isLoading: isLoading,
          onPressed: () => _handleSubmit(context),
        );
      },
    );
  }

  Widget _buildToggleAuthMode(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _isSignUp
              ? context.tr(TranslationKeys.emailAuthHaveAccount)
              : context.tr(TranslationKeys.emailAuthNoAccount),
          style: AppFonts.inter(fontSize: 14.5, color: palette.muted),
        ),
        TextButton(
          key: const Key('email_auth_toggle_mode'),
          onPressed: () => setState(() => _isSignUp = !_isSignUp),
          style: TextButton.styleFrom(
            foregroundColor: palette.text,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(44, 44),
          ),
          child: Text(
            _isSignUp
                ? context.tr(TranslationKeys.emailAuthSignInLink)
                : context.tr(TranslationKeys.emailAuthCreateAccount),
            style: AppFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
        ),
      ],
    );
  }

  void _handleSubmit(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      if (_isSignUp) {
        context.read<AuthBloc>().add(
              EmailSignUpRequested(
                email: _emailController.text.trim(),
                password: _passwordController.text,
                fullName: _nameController.text.trim(),
              ),
            );
      } else {
        context.read<AuthBloc>().add(
              EmailSignInRequested(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              ),
            );
      }
    }
  }
}
