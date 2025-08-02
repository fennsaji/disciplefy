import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/onboarding_state_entity.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';

/// Welcome screen that introduces the app without authentication.
/// 
/// Features app logo, tagline, and app features preview
/// following the UX specifications and brand guidelines.
class OnboardingWelcomePage extends StatelessWidget {
  const OnboardingWelcomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
      create: (context) => sl<OnboardingBloc>()..add(const LoadOnboardingState()),
      child: const _OnboardingWelcomeContent(),
    );
}

class _OnboardingWelcomeContent extends StatelessWidget {
  const _OnboardingWelcomeContent();

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

    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingNavigating) {
          // Navigate based on the navigation state
          switch (state.toStep) {
            case OnboardingStep.language:
              context.go('/onboarding/language');
              break;
            case OnboardingStep.purpose:
              context.go('/onboarding/purpose');
              break;
            case OnboardingStep.completed:
              context.go('/login');
              break;
            default:
              break;
          }
        } else if (state is OnboardingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
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
              
              // Continue Button
              BlocBuilder<OnboardingBloc, OnboardingState>(
                builder: (context, state) {
                  final isLoading = state is OnboardingLoading;
                  
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading 
                          ? null 
                          : () => context.read<OnboardingBloc>().add(const NextStep()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading...',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Continue',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: isLargeScreen ? 40 : 24),
              
              // Privacy/Terms Notice
              Text(
                'Let\'s set up your personalized Bible study experience',
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