import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_states;

/// Onboarding carousel screen with 3 intro slides.
/// 
/// Follows Disciplefy brand guidelines and UX specifications.
/// Each slide introduces key app features following the design images.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
    });
  }

  static const List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'Generate Personalized Bible Study Guides',
      subtitle: 'AI-powered insights tailored to your spiritual journey',
      description: 'Simply enter any scripture reference or spiritual topic, and our AI will create a comprehensive study guide with context, interpretation, and life application.',
      iconData: Icons.auto_awesome,
      verse: '"Your word is a lamp for my feet, a light on my path." - Psalm 119:105',
    ),
    OnboardingSlide(
      title: 'Explore Predefined Topics',
      subtitle: 'Discover guided studies on faith essentials',
      description: 'Choose from carefully curated topics like Gospel, Prayer, Baptism, Grace, and Faith in Trials to deepen your understanding of core biblical principles.',
      iconData: Icons.menu_book_rounded,
      verse: '"All Scripture is God-breathed and is useful for teaching..." - 2 Timothy 3:16',
    ),
    OnboardingSlide(
      title: 'Save Notes & Track Progress',
      subtitle: 'Build your personal spiritual journal',
      description: 'Take notes during your study, save your insights, and track your spiritual growth journey. Resume your studies anytime, anywhere.',
      iconData: Icons.bookmark_added,
      verse: '"The grass withers and the flowers fall, but the word of our God endures forever." - Isaiah 40:8',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _navigateToWelcome() {
    context.go('/onboarding/welcome');
  }

  void _skipOnboarding() {
    context.go('/onboarding/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo and skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Disciplefy Logo
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Disciplefy',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  // Skip button
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Page view with slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _slides.length,
                itemBuilder: (context, index) => _OnboardingSlideWidget(
                    slide: _slides[index],
                    isLargeScreen: isLargeScreen,
                  ),
              ),
            ),
            
            // Page indicator
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: isLargeScreen ? 32 : 24,
              ),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _slides.length,
                effect: WormEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  activeDotColor: AppTheme.primaryColor,
                  dotColor: AppTheme.primaryColor.withOpacity(0.3),
                  spacing: 12,
                ),
              ),
            ),
            
            // Get Started button (shows on last slide) or Continue
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, isLargeScreen ? 40 : 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToWelcome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _slides.length - 1 ? 'Get Started' : 'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual slide widget for the onboarding carousel.
class _OnboardingSlideWidget extends StatelessWidget {
  final OnboardingSlide slide;
  final bool isLargeScreen;

  const _OnboardingSlideWidget({
    required this.slide,
    required this.isLargeScreen,
  });

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container with brand styling
          Container(
            width: isLargeScreen ? 140 : 120,
            height: isLargeScreen ? 140 : 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.secondaryColor.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              slide.iconData,
              size: isLargeScreen ? 64 : 56,
              color: AppTheme.primaryColor,
            ),
          ),
          
          SizedBox(height: isLargeScreen ? 56 : 48),
          
          // Title
          Text(
            slide.title,
            style: GoogleFonts.playfairDisplay(
              fontSize: isLargeScreen ? 32 : 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isLargeScreen ? 20 : 16),
          
          // Subtitle
          Text(
            slide.subtitle,
            style: GoogleFonts.inter(
              fontSize: isLargeScreen ? 20 : 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryColor,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isLargeScreen ? 28 : 24),
          
          // Description
          Text(
            slide.description,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          
          SizedBox(height: isLargeScreen ? 32 : 28),
          
          // Bible verse (spiritual encouragement)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.secondaryColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Text(
              slide.verse,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: AppTheme.textPrimary.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
}

/// Data model for onboarding slide content.
class OnboardingSlide {
  final String title;
  final String subtitle;
  final String description;
  final IconData iconData;
  final String verse;

  const OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.iconData,
    required this.verse,
  });
}