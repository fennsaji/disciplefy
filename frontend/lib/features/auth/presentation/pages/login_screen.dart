import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart' as auth_states;

/// Login screen with Google OAuth and anonymous sign-in options
/// Follows Material Design 3 guidelines and brand theme
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  /// Check if user is already authenticated and redirect if needed
  void _checkAuthenticationStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is auth_states.AuthenticatedState) {
        // User is already authenticated, redirect to home
        context.go('/');
      }
      // No automatic sign-in - users must explicitly choose authentication method
    });
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthBloc, auth_states.AuthState>(
      listener: (context, state) {
        if (state is auth_states.AuthenticatedState) {
          // Navigate to home screen on successful authentication
          context.go('/');
        } else if (state is auth_states.AuthErrorState) {
          // Handle different types of errors
          if (state.message.contains('canceled') || state.message.contains('cancelled')) {
            // Show neutral snackbar for cancelled operations
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.onSurfaceVariant,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            // Show error message for actual errors
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Main content
                Expanded(
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
              ],
            ),
          ),
        ),
      ),
    );

  /// Builds the app logo with brand colors
  Widget _buildAppLogo(BuildContext context) => Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.auto_stories,
        size: 60,
        color: AppTheme.primaryColor,
      ),
    );

  /// Builds the welcome text section
  Widget _buildWelcomeText(BuildContext context) => Column(
      children: [
        Text(
          'Welcome to Disciplefy',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'Deepen your faith through guided Bible study',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppTheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );

  /// Builds the sign-in buttons with proper state management
  Widget _buildSignInButtons(BuildContext context) => BlocBuilder<AuthBloc, auth_states.AuthState>(
      builder: (context, state) {
        final isLoading = state is auth_states.AuthLoadingState;
        
        return Column(
          children: [
            // Google Sign-In Button
            _buildGoogleSignInButton(context, isLoading),
            
            const SizedBox(height: 16),
            
            // Continue as Guest Button
            _buildGuestSignInButton(context, isLoading),
          ],
        );
      },
    );

  /// Builds the Google sign-in button with proper branding
  Widget _buildGoogleSignInButton(BuildContext context, bool isLoading) => SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _handleGoogleSignIn(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                        image: AssetImage('images/google_logo.png'),
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

  /// Builds the guest sign-in button
  Widget _buildGuestSignInButton(BuildContext context, bool isLoading) => SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : () => _handleGuestSignIn(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: BorderSide(
            color: AppTheme.primaryColor,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledForegroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 20,
              color: AppTheme.primaryColor,
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

  /// Builds the features preview section
  Widget _buildFeaturesSection(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
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
              color: AppTheme.textPrimary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          _FeatureItem(
            icon: Icons.auto_awesome,
            title: 'AI-Powered Study Guides',
            subtitle: 'Personalized insights for any verse or topic',
          ),
          
          const SizedBox(height: 12),
          
          _FeatureItem(
            icon: Icons.school,
            title: 'Structured Learning',
            subtitle: 'Follow proven biblical study methodology',
          ),
          
          const SizedBox(height: 12),
          
          _FeatureItem(
            icon: Icons.language,
            title: 'Multi-Language Support',
            subtitle: 'Study in English, Hindi, and Malayalam',
          ),
        ],
      ),
    );

  /// Builds the privacy policy text
  Widget _buildPrivacyText(BuildContext context) => Text(
      'By continuing, you agree to our Terms of Service and Privacy Policy',
      style: GoogleFonts.inter(
        fontSize: 12,
        color: AppTheme.onSurfaceVariant,
        height: 1.4,
      ),
      textAlign: TextAlign.center,
    );

  /// Handles Google sign-in button tap
  void _handleGoogleSignIn(BuildContext context) {
    context.read<AuthBloc>().add(const GoogleSignInRequested());
  }

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
  Widget build(BuildContext context) => Row(
      children: [
        // Icon container
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: AppTheme.primaryColor,
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
                  color: AppTheme.textPrimary,
                ),
              ),
              
              const SizedBox(height: 2),
              
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
}