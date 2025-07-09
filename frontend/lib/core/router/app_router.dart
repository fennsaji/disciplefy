import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/onboarding/presentation/pages/onboarding_screen.dart';
import '../../features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_language_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_purpose_page.dart';
import '../../features/home/presentation/pages/home_screen.dart';
import '../../features/study_generation/presentation/pages/study_input_page.dart';
import '../../features/study_generation/presentation/pages/generate_study_screen.dart';
import '../../features/study_generation/presentation/pages/study_guide_screen.dart';
import '../../features/study_generation/presentation/pages/study_result_page.dart';
import '../../features/study_generation/domain/entities/study_guide.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';
import '../../features/saved_guides/presentation/pages/saved_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../presentation/widgets/app_shell.dart';
import '../error/error_page.dart';

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String onboardingWelcome = '/onboarding/welcome';
  static const String onboardingLanguage = '/onboarding/language';
  static const String onboardingPurpose = '/onboarding/purpose';
  static const String home = '/';
  static const String generateStudy = '/generate-study';
  static const String studyGuide = '/study-guide';
  static const String studyResult = '/study-result';
  static const String settings = '/settings';
  static const String saved = '/saved';
  static const String login = '/login';
  static const String error = '/error';
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: _getInitialRoute(),
    routes: [
      // Onboarding Flow (outside app shell)
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingWelcome,
        name: 'onboarding_welcome',
        builder: (context, state) => const OnboardingWelcomePage(),
      ),
      GoRoute(
        path: AppRoutes.onboardingLanguage,
        name: 'onboarding_language',
        builder: (context, state) => const OnboardingLanguagePage(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPurpose,
        name: 'onboarding_purpose',
        builder: (context, state) => const OnboardingPurposePage(),
      ),
      
      // Main App Routes (using AppShell directly)
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: AppRoutes.generateStudy,
        name: 'generate_study',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: AppRoutes.saved,
        name: 'saved',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const AppShell(),
      ),
      
      // Authentication Routes (outside app shell)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Full Screen Routes (outside shell)
      GoRoute(
        path: AppRoutes.studyGuide,
        name: 'study_guide',
        builder: (context, state) {
          // Handle different types of navigation data
          StudyGuide? studyGuide;
          Map<String, dynamic>? routeExtra;
          
          if (state.extra is StudyGuide) {
            studyGuide = state.extra as StudyGuide;
          } else if (state.extra is Map<String, dynamic>) {
            routeExtra = state.extra as Map<String, dynamic>;
          }
          
          return StudyGuideScreen(
            studyGuide: studyGuide,
            routeExtra: routeExtra,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.studyResult,
        name: 'study_result',
        builder: (context, state) {
          final studyGuide = state.extra as StudyGuide?;
          return StudyResultPage(studyGuide: studyGuide);
        },
      ),
      
      // Error Page
      GoRoute(
        path: AppRoutes.error,
        name: 'error',
        builder: (context, state) {
          final error = state.extra as String?;
          return ErrorPage(error: error);
        },
      ),
    ],
    errorBuilder: (context, state) => ErrorPage(
      error: 'Page not found: ${state.matchedLocation}',
    ),
  );

  static String _getInitialRoute() {
    try {
      // Check if onboarding has been completed
      final box = Hive.box('app_settings');
      final onboardingCompleted = box.get('onboarding_completed', defaultValue: false);
      
      return onboardingCompleted ? AppRoutes.home : AppRoutes.onboarding;
    } catch (e) {
      // If Hive is not ready, default to onboarding
      return AppRoutes.onboardingWelcome;
    }
  }
}

// Navigation Extensions
extension AppRouterExtension on GoRouter {
  void goToOnboarding() => go(AppRoutes.onboarding);
  void goToOnboardingWelcome() => go(AppRoutes.onboardingWelcome);
  void goToOnboardingLanguage() => go(AppRoutes.onboardingLanguage);
  void goToOnboardingPurpose() => go(AppRoutes.onboardingPurpose);
  void goToHome() => go(AppRoutes.home);
  void goToGenerateStudy() => go(AppRoutes.generateStudy);
  void goToStudyGuide(StudyGuide studyGuide) => go(AppRoutes.studyGuide, extra: studyGuide);
  void goToStudyGuideWithExtra(Map<String, dynamic> extra) => go(AppRoutes.studyGuide, extra: extra);
  void goToStudyResult(StudyGuide studyGuide) => go(AppRoutes.studyResult, extra: studyGuide);
  void goToSettings() => go(AppRoutes.settings);
  void goToSaved() => go(AppRoutes.saved);
  void goToLogin() => go(AppRoutes.login);
  void goToError(String error) => go(AppRoutes.error, extra: error);
}