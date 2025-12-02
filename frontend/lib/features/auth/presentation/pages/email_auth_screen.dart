import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart' as auth_states;
import '../../../../core/services/auth_aware_navigation_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/utils/auth_validator.dart';

/// Email authentication screen with sign-in/sign-up toggle
/// Follows Material Design 3 guidelines and brand theme with dark mode support
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // Title
                    _buildTitle(context),

                    const SizedBox(height: 32),

                    // Tab toggle (Sign In / Sign Up)
                    _buildTabToggle(context),

                    const SizedBox(height: 32),

                    // Name field (only for sign up)
                    if (_isSignUp) ...[
                      _buildNameField(context),
                      const SizedBox(height: 16),
                    ],

                    // Email field
                    _buildEmailField(context),

                    const SizedBox(height: 16),

                    // Password field
                    _buildPasswordField(context),

                    // Forgot password link (only for sign in)
                    if (!_isSignUp) ...[
                      const SizedBox(height: 8),
                      _buildForgotPasswordLink(context),
                    ],

                    const SizedBox(height: 32),

                    // Submit button
                    _buildSubmitButton(context),

                    const SizedBox(height: 24),

                    // Toggle between sign in and sign up
                    _buildToggleAuthMode(context),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      context.tr(TranslationKeys.emailAuthTitle),
      style: AppFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onBackground,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTabToggle(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Sign In Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSignUp = false),
              child: Container(
                decoration: BoxDecoration(
                  color: !_isSignUp
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    context.tr(TranslationKeys.emailAuthSignIn),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: !_isSignUp
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Sign Up Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSignUp = true),
              child: Container(
                decoration: BoxDecoration(
                  color: _isSignUp
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    context.tr(TranslationKeys.emailAuthSignUp),
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isSignUp
                          ? Colors.white
                          : theme.colorScheme.onSurface,
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

  Widget _buildNameField(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: _nameController,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: context.tr(TranslationKeys.emailAuthFullName),
        hintText: context.tr(TranslationKeys.emailAuthFullNameHint),
        prefixIcon: Icon(
          Icons.person_outline,
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
        if (value == null || !AuthValidator.isValidFullName(value)) {
          return context.tr(TranslationKeys.emailAuthInvalidName);
        }
        return null;
      },
    );
  }

  Widget _buildEmailField(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: context.tr(TranslationKeys.emailAuthEmail),
        hintText: context.tr(TranslationKeys.emailAuthEmailHint),
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
          return context.tr(TranslationKeys.emailAuthInvalidEmail);
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: context.tr(TranslationKeys.emailAuthPassword),
        hintText: context.tr(TranslationKeys.emailAuthPasswordHint),
        prefixIcon: Icon(
          Icons.lock_outline,
          color: theme.colorScheme.primary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
        if (_isSignUp &&
            (value == null || !AuthValidator.isValidPassword(value))) {
          return context.tr(TranslationKeys.emailAuthInvalidPassword);
        }
        if (!_isSignUp && (value == null || value.isEmpty)) {
          return context.tr(TranslationKeys.emailAuthPasswordHint);
        }
        return null;
      },
    );
  }

  Widget _buildForgotPasswordLink(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => context.push(AppRoutes.passwordReset),
        child: Text(
          context.tr(TranslationKeys.emailAuthForgotPassword),
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
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
                        _isSignUp
                            ? context.tr(TranslationKeys.emailAuthSignUpButton)
                            : context.tr(TranslationKeys.emailAuthSignInButton),
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

  Widget _buildToggleAuthMode(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp
              ? context.tr(TranslationKeys.emailAuthHaveAccount)
              : context.tr(TranslationKeys.emailAuthNoAccount),
          style: AppFonts.inter(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _isSignUp = !_isSignUp),
          child: Text(
            _isSignUp
                ? context.tr(TranslationKeys.emailAuthSignInLink)
                : context.tr(TranslationKeys.emailAuthCreateAccount),
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
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
