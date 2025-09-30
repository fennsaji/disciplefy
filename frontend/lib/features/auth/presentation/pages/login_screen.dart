import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart' as auth_states;
import '../../../../core/services/auth_aware_navigation_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/logger.dart';

/// Login screen with Google OAuth and anonymous sign-in options
/// Follows Material Design 3 guidelines and brand theme with dark mode support
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Flag to prevent navigation conflicts during phone auth flow
  final bool _isPhoneAuthInProgress = false;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  /// Check if user is already authenticated and redirect if needed
  /// Anonymous users are allowed to stay on login screen to upgrade their account
  void _checkAuthenticationStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is auth_states.AuthenticatedState) {
        // Only redirect non-anonymous users - let anonymous users upgrade their account
        if (!authState.isAnonymous) {
          Logger.info(
            'Authenticated user detected on login screen - redirecting',
            tag: 'LOGIN_SCREEN',
            context: {
              'user_type': 'authenticated',
              'redirect_reason': 'already_authenticated',
            },
          );
          // Use AuthAwareNavigationService for proper stack management
          context.navigateAfterAuth();
        }
        // Anonymous users can stay on login screen to upgrade to real account
      }
      // No automatic sign-in - users must explicitly choose authentication method
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AuthBloc, auth_states.AuthState>(
        listener: (context, state) {
          if (state is auth_states.AuthenticatedState) {
            // Check if this is a phone auth user by checking if they have a phone number
            final isPhoneAuthUser =
                state.user.phone != null && state.user.phone!.isNotEmpty;

            if (isPhoneAuthUser) {
              Logger.info(
                'Phone auth user detected - letting router handle navigation',
                tag: 'LOGIN_SCREEN',
                context: {
                  'user_type': 'phone_auth',
                  'phone': state.user.phone,
                  'skip_navigation': 'router_will_handle',
                },
              );
              // Don't navigate for phone auth users - let the router handle it
              // This prevents conflicts with OTP verification screen navigation
              return;
            }

            Logger.info(
              'Authentication successful - navigating to home',
              tag: 'LOGIN_SCREEN',
              context: {
                'user_type': state.isAnonymous ? 'anonymous' : 'authenticated',
                'navigation_method': 'auth_aware_service',
              },
            );
            // Use AuthAwareNavigationService for proper post-auth navigation
            context.navigateAfterAuth();
          } else if (state is auth_states.AuthErrorState) {
            Logger.error(
              'Authentication error occurred',
              tag: 'LOGIN_SCREEN',
              context: {
                'error_message': state.message,
                'is_cancelled': state.message.contains('canceled') ||
                    state.message.contains('cancelled'),
              },
            );
            // Handle different types of errors
            final theme = Theme.of(context);
            if (state.message.contains('canceled') ||
                state.message.contains('cancelled')) {
              // Show neutral snackbar for cancelled operations
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: theme.colorScheme.onSurface.withOpacity(0.8),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else {
              // Show error message for actual errors
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: theme.colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Main content - scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height -
                            MediaQuery.of(context).viewPadding.top -
                            MediaQuery.of(context).viewPadding.bottom -
                            80, // Account for skip button space
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App logo/icon
                          _buildAppLogo(context),

                          const SizedBox(height: 48),

                          // Welcome text
                          _buildWelcomeText(context),

                          const SizedBox(height: 32),

                          // Features Preview Section
                          _buildFeaturesSection(context),

                          const SizedBox(height: 32),

                          // Sign-in buttons
                          _buildSignInButtons(context),

                          const SizedBox(height: 32),

                          // Privacy policy text
                          _buildPrivacyText(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// Builds the app logo with brand colors
  Widget _buildAppLogo(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.auto_stories,
        size: 60,
        color: theme.colorScheme.primary,
      ),
    );
  }

  /// Builds the welcome text section
  Widget _buildWelcomeText(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          'Welcome to Disciplefy',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Deepen your faith through guided Bible study',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds the sign-in buttons with proper state management
  Widget _buildSignInButtons(BuildContext context) =>
      BlocBuilder<AuthBloc, auth_states.AuthState>(
        builder: (context, state) {
          final isLoading = state is auth_states.AuthLoadingState;

          return Column(
            children: [
              // Google Sign-In Button
              _buildGoogleSignInButton(context, isLoading),

              const SizedBox(height: 16),

              // Phone Sign-In Button - COMMENTED OUT FOR NOW
              // _buildPhoneSignInButton(context, isLoading),
              //
              // const SizedBox(height: 16),

              // Continue as Guest Button
              _buildGuestSignInButton(context, isLoading),
            ],
          );
        },
      );

  /// Builds the Google sign-in button with proper branding
  Widget _buildGoogleSignInButton(BuildContext context, bool isLoading) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _handleGoogleSignIn(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.5),
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google logo
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/google_logo.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Text(
                    'Continue with Google',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Builds the phone sign-in button - COMMENTED OUT FOR NOW
  // Widget _buildPhoneSignInButton(BuildContext context, bool isLoading) {
  //   final theme = Theme.of(context);
  //
  //   return SizedBox(
  //     width: double.infinity,
  //     height: 56,
  //     child: OutlinedButton(
  //       onPressed: isLoading ? null : () => _handlePhoneSignIn(context),
  //       style: OutlinedButton.styleFrom(
  //         foregroundColor: theme.colorScheme.primary,
  //         side: BorderSide(
  //           color: theme.colorScheme.primary,
  //           width: 2,
  //         ),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         disabledForegroundColor:
  //             theme.colorScheme.primary.withValues(alpha: 0.5),
  //       ),
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Icon(
  //             Icons.phone,
  //             size: 20,
  //             color: theme.colorScheme.primary,
  //           ),
  //           const SizedBox(width: 12),
  //           Text(
  //             'Continue with Phone',
  //             style: GoogleFonts.inter(
  //               fontSize: 16,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  /// Builds the guest sign-in button
  Widget _buildGuestSignInButton(BuildContext context, bool isLoading) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : () => _handleGuestSignIn(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledForegroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Continue as Guest',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the features preview section
  Widget _buildFeaturesSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
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
            'What you\'ll get:',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          const _FeatureItem(
            icon: Icons.auto_awesome,
            title: 'AI-Powered Study Guides',
            subtitle: 'Personalized insights for any verse or topic',
          ),
          const SizedBox(height: 12),
          const _FeatureItem(
            icon: Icons.school,
            title: 'Structured Learning',
            subtitle: 'Follow proven biblical study methodology',
          ),
          const SizedBox(height: 12),
          const _FeatureItem(
            icon: Icons.language,
            title: 'Multi-Language Support',
            subtitle: 'Study in English, Hindi, and Malayalam',
          ),
        ],
      ),
    );
  }

  /// Builds the privacy policy text
  Widget _buildPrivacyText(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      'By continuing, you agree to our Terms of Service and Privacy Policy',
      style: GoogleFonts.inter(
        fontSize: 12,
        color: theme.colorScheme.onSurface.withOpacity(0.6),
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Handles Google sign-in button tap
  void _handleGoogleSignIn(BuildContext context) {
    context.read<AuthBloc>().add(const GoogleSignInRequested());
  }

  /// Handles phone sign-in button tap - COMMENTED OUT FOR NOW
  // void _handlePhoneSignIn(BuildContext context) {
  //   context.push(AppRoutes.phoneAuth);
  // }

  /// Handles guest sign-in button tap
  void _handleGuestSignIn(BuildContext context) {
    context.read<AuthBloc>().add(const AnonymousSignInRequested());
  }
}

/// Individual feature item widget for the login screen
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Icon container
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: theme.colorScheme.primary,
          ),
        ),

        const SizedBox(width: 14),

        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
