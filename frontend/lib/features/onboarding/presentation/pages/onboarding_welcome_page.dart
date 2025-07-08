import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Welcome/Login screen based on Login_Screen.jpg design.
/// 
/// Features app logo, tagline, and authentication options
/// following the UX specifications and brand guidelines.
class OnboardingWelcomePage extends StatelessWidget {
  const OnboardingWelcomePage({super.key});

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
                    
                    _WelcomeFeatureItem(
                      icon: Icons.auto_awesome,
                      title: 'AI-Powered Study Guides',
                      subtitle: 'Personalized insights for any verse or topic',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _WelcomeFeatureItem(
                      icon: Icons.school,
                      title: 'Structured Learning',
                      subtitle: 'Follow proven biblical study methodology',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _WelcomeFeatureItem(
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleGoogleLogin(context),
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 24,
                      ),
                      label: Text(
                        'Login with Google',
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
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Continue as Guest Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _handleGuestLogin(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue as Guest',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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

  void _handleGoogleLogin(BuildContext context) {
    // TODO: Implement Google login with Supabase auth
    // For now, navigate to home
    context.go('/');
    
    // Show loading state while authenticating
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Google authentication coming soon!',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _handleGuestLogin(BuildContext context) {
    // TODO: Implement anonymous login with Supabase auth
    // For now, navigate to home
    context.go('/');
    
    // Mark onboarding as completed
    // This should be handled by the auth service
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
  Widget build(BuildContext context) {
    return Row(
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
              width: 1,
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
}