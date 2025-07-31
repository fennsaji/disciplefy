import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_states;

/// Welcome/Login screen based on Login_Screen.jpg design.
/// 
/// Features app logo, tagline, and authentication options
/// following the UX specifications and brand guidelines.
class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key});

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage> {

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;
    
    // If localization is not ready, show loading
    if (l10n == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Top spacing
              SizedBox(height: isLargeScreen ? 80 : 60),
              
              // App Logo Section
              Column(
                children: [
                  // Logo Container
                  Container(
                    width: isLargeScreen ? 120 : 100,
                    height: isLargeScreen ? 120 : 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: isLargeScreen ? 64 : 56,
                      color: Colors.white,
                    ),
                  ),
                  
                  SizedBox(height: isLargeScreen ? 32 : 24),
                  
                  // App Title
                  Text(
                    'Disciplefy',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isLargeScreen ? 48 : 42,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  SizedBox(height: isLargeScreen ? 16 : 12),
                  
                  // Tagline
                  Text(
                    'Deepen your faith with guided studies',
                    style: GoogleFonts.inter(
                      fontSize: isLargeScreen ? 20 : 18,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Features Preview Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      blurRadius: 20,
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
                    
                    const SizedBox(height: 20),
                    
                    const _WelcomeFeatureItem(
                      icon: Icons.auto_awesome,
                      title: 'AI-Powered Study Guides',
                      subtitle: 'Personalized insights for any verse or topic',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    const _WelcomeFeatureItem(
                      icon: Icons.school,
                      title: 'Structured Learning',
                      subtitle: 'Follow proven biblical study methodology',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    const _WelcomeFeatureItem(
                      icon: Icons.language,
                      title: 'Multi-Language Support',
                      subtitle: 'Study in English, Hindi, and Malayalam',
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Authentication Buttons
              Column(
                children: [
                  // Login with Google Button
                  BlocBuilder<AuthBloc, auth_states.AuthState>(
                    builder: (context, state) {
                      final isLoading = state is auth_states.AuthLoadingState;
                      
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isLoading 
                              ? null 
                              : () => _handleGoogleLogin(context),
                          icon: isLoading 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                ),
                          label: Text(
                            isLoading ? 'Signing in...' : 'Login with Google',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Continue as Guest Button
                  BlocConsumer<AuthBloc, auth_states.AuthState>(
                    listener: (context, state) {
                      if (state is auth_states.AuthenticatedState) {
                        // Navigate to home on successful authentication
                        context.go('/');
                        
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              state.isAnonymous 
                                  ? 'Welcome! You\'re signed in as a guest.'
                                  : 'Welcome back!',
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (state is auth_states.AuthErrorState) {
                        // Show error dialog
                        _showErrorDialog(
                          'Guest Login Failed',
                          'Unable to sign in as guest:\n\n${state.message}',
                        );
                      }
                    },
                    builder: (context, state) {
                      final isLoading = state is auth_states.AuthLoadingState;
                      
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isLoading 
                              ? null 
                              : () => context.read<AuthBloc>().add(const AnonymousSignInRequested()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Signing in...',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Continue as Guest',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              SizedBox(height: isLargeScreen ? 40 : 24),
              
              // Privacy/Terms Notice
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isLargeScreen ? 24 : 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to proper login screen for Google authentication
  /// Uses BLoC architecture instead of direct API calls

  void _handleGoogleLogin(BuildContext context) {
    // Navigate to the proper login screen with Google OAuth
    context.go('/login');
  }

  /// Shows an error dialog with the given title and message.
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
          backgroundColor: const Color(0xFFFAFAFA), // Light background
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.1),
          title: Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333), // Primary gray text
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF333333), // Primary gray text
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF888888), // Light gray for cancel
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'OK',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF888888), // Light gray text
                ),
              ),
            ),
          ],
        ),
    );
  }
}

/// Individual feature item widget for the welcome screen.
class _WelcomeFeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _WelcomeFeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
      children: [
        // Icon container
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: AppTheme.primaryColor,
          ),
        ),
        
        const SizedBox(width: 16),
        
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