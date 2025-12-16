import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_states;

/// Onboarding carousel screen with 3 intro slides.
///
/// Follows Disciplefy brand guidelines and UX specifications with dark mode support.
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
      title: 'Daily Inspiration & Study',
      subtitle: 'Start each day with God\'s Word',
      description:
          'Receive daily verses with instant study guides. Tap any verse to dive deeper with AI-powered insights, context, and practical applications.',
      iconData: Icons.wb_sunny,
      verse:
          '"Your word is a lamp for my feet, a light on my path." - Psalm 119:105',
    ),
    OnboardingSlide(
      title: 'AI-Powered Study Guides',
      subtitle: 'Personalized insights for your journey',
      description:
          'Enter any scripture or topic to create comprehensive study guides with context, interpretation, reflection questions, and prayer points.',
      iconData: Icons.auto_awesome,
      verse:
          '"All Scripture is God-breathed and is useful for teaching..." - 2 Timothy 3:16',
    ),
    OnboardingSlide(
      title: 'Voice Discipler',
      subtitle: 'Talk with your AI Bible companion',
      description:
          'Have natural voice conversations about Scripture. Ask questions, get answers, and deepen your understanding through guided dialogue.',
      iconData: Icons.mic,
      verse: '"Call to me and I will answer you..." - Jeremiah 33:3',
    ),
    OnboardingSlide(
      title: 'Memory Verses',
      subtitle: 'Hide God\'s Word in your heart',
      description:
          'Memorize Scripture with scientifically-proven spaced repetition. Review verses at optimal intervals to commit them to long-term memory.',
      iconData: Icons.psychology,
      verse:
          '"I have hidden your word in my heart that I might not sin against you." - Psalm 119:11',
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

  void _handleContinueButton() {
    if (_currentPage == _slides.length - 1) {
      // Last slide - complete onboarding and navigate to login
      _completeOnboarding();
    } else {
      // Not on last slide - go to next slide
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() async {
    // Mark onboarding as completed
    final box = Hive.box('app_settings');
    await box.put('onboarding_completed', true);

    if (mounted) {
      // Navigate to pricing page to show plans before login
      context.go(AppRoutes.pricing);
    }
  }

  void _skipOnboarding() async {
    // Mark onboarding as completed
    final box = Hive.box('app_settings');
    await box.put('onboarding_completed', true);

    if (mounted) {
      // Navigate to pricing page to show plans before login
      context.go(AppRoutes.pricing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  const _LogoWidget(),
                  // Skip button
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Skip',
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                  activeDotColor: theme.colorScheme.primary,
                  dotColor: theme.colorScheme.primary.withOpacity(0.3),
                  spacing: 12,
                ),
              ),
            ),

            // Continue button (navigates to next slide) or Get Started (last slide)
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, isLargeScreen ? 40 : 24),
              child: Container(
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
                    onTap: _handleContinueButton,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'Get Started'
                            : 'Continue',
                        style: AppFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFFFFF),
                          letterSpacing: 0.5,
                        ),
                      ),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: isLargeScreen ? 24 : 16),

          // Icon container with brand styling
          Container(
            width: isLargeScreen ? 140 : 120,
            height: isLargeScreen ? 140 : 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              slide.iconData,
              size: isLargeScreen ? 64 : 56,
              color: theme.colorScheme.primary,
            ),
          ),

          SizedBox(height: isLargeScreen ? 48 : 32),

          // Title
          Text(
            slide.title,
            style: AppFonts.poppins(
              fontSize: isLargeScreen ? 32 : 26,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isLargeScreen ? 16 : 12),

          // Subtitle
          Text(
            slide.subtitle,
            style: AppFonts.inter(
              fontSize: isLargeScreen ? 20 : 17,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isLargeScreen ? 24 : 16),

          // Description - removed maxLines to allow full text
          Text(
            slide.description,
            style: AppFonts.inter(
              fontSize: isLargeScreen ? 16 : 15,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isLargeScreen ? 28 : 20),

          // Bible verse (spiritual encouragement)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.secondary.withOpacity(0.5),
              ),
            ),
            child: Text(
              slide.verse,
              style: AppFonts.inter(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onBackground.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: isLargeScreen ? 24 : 16),
        ],
      ),
    );
  }
}

/// Private widget for rendering the theme-aware Disciplefy logo
class _LogoWidget extends StatelessWidget {
  const _LogoWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final logoAsset = isDarkMode
        ? 'assets/images/app_logo_dark.png'
        : 'assets/images/app_logo.png';

    return Semantics(
      label: 'Disciplefy app logo',
      child: Image.asset(
        logoAsset,
        width: 140,
        height: 32,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to icon + text if image fails to load
          return Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.menu_book,
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Disciplefy',
                style: AppFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
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
