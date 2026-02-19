import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart' as auth_states;
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/utils/auth_validator.dart';

/// Password reset screen for email-based authentication
/// Allows users to request a password reset link via email
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
            final theme = Theme.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Something went wrong. Please try again.'),
                backgroundColor: theme.colorScheme.error,
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
              child: _emailSent
                  ? _buildSuccessContent(context)
                  : _buildFormContent(context),
            ),
          ),
        ),
      );

  Widget _buildFormContent(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),

          // Icon
          Icon(
            Icons.lock_reset,
            size: 80,
            color: theme.colorScheme.primary,
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            context.tr(TranslationKeys.passwordResetTitle),
            style: AppFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onBackground,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            context.tr(TranslationKeys.passwordResetSubtitle),
            style: AppFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Email field
          _buildEmailField(context),

          const SizedBox(height: 32),

          // Submit button
          _buildSubmitButton(context),

          const SizedBox(height: 24),

          // Back to sign in link
          _buildBackToSignInLink(context),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSuccessContent(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 64),

        // Success icon
        Icon(
          Icons.mark_email_read,
          size: 100,
          color: theme.colorScheme.primary,
        ),

        const SizedBox(height: 32),

        // Success title
        Text(
          context.tr(TranslationKeys.passwordResetSuccessTitle),
          style: AppFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Success message
        Text(
          context.tr(TranslationKeys.passwordResetSuccessMessage),
          style: AppFonts.inter(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 48),

        // Back to sign in button
        _buildBackToSignInButton(context),

        const SizedBox(height: 16),

        // Resend link
        _buildResendLink(context),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: context.tr(TranslationKeys.passwordResetEmail),
        hintText: context.tr(TranslationKeys.passwordResetEmailHint),
        prefixIcon: Icon(
          Icons.email_outlined,
          color: theme.colorScheme.primary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
      ),
      validator: (value) {
        if (value == null || !AuthValidator.isValidEmail(value)) {
          return context.tr(TranslationKeys.passwordResetInvalidEmail);
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        final isLoading = state is auth_states.AuthLoadingState;

        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: isLoading ? null : AppTheme.primaryGradient,
            color: isLoading ? AppTheme.primaryColor.withOpacity(0.5) : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isLoading
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : () => _handleSubmit(context),
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        context.tr(TranslationKeys.passwordResetSendButton),
                        style: AppFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackToSignInLink(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton(
      onPressed: () => context.pop(),
      child: Text(
        context.tr(TranslationKeys.passwordResetBackToSignIn),
        style: AppFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildBackToSignInButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              context.tr(TranslationKeys.passwordResetBackToSignIn),
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendLink(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        final isLoading = state is auth_states.AuthLoadingState;

        return TextButton(
          onPressed: isLoading
              ? null
              : () {
                  setState(() => _emailSent = false);
                },
          child: Text(
            context.tr(TranslationKeys.passwordResetResend),
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isLoading
                  ? theme.colorScheme.onSurface.withOpacity(0.3)
                  : theme.colorScheme.primary,
            ),
          ),
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
