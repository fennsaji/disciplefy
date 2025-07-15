import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/onboarding/presentation/pages/onboarding_screen.dart';
import '../../features/onboarding/presentation/pages/onboarding_language_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_purpose_page.dart';
import '../../features/study_generation/presentation/pages/study_guide_screen.dart';
import '../../features/study_generation/presentation/pages/study_result_page.dart';
import '../../features/study_generation/domain/entities/study_guide.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/auth_callback_page.dart';
import '../presentation/widgets/app_shell.dart';
import '../error/error_page.dart';
import '../../features/home/presentation/pages/home_screen.dart';
import '../../features/study_generation/presentation/pages/generate_study_screen.dart';
import '../../features/saved_guides/presentation/pages/saved_screen_api.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String onboardingLanguage = '/onboarding/language';
  static const String onboardingPurpose = '/onboarding/purpose';
  static const String home = '/';
  static const String generateStudy = '/generate-study';
  static const String studyGuide = '/study-guide';
  static const String studyResult = '/study-result';
  static const String settings = '/settings';
  static const String saved = '/saved';
  static const String login = '/login';
  static const String authCallback = '/auth/callback';
  static const String error = '/error';
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: _getInitialRoute(),
    redirect: (context, state) {
      // Use Supabase for authentication check (primary method)
      final user = Supabase.instance.client.auth.currentUser;
      final isAuthenticated = user != null;
      final currentPath = state.uri.path;

      // Debug logging
      print(
          '🔐 [ROUTER] Auth check: ${isAuthenticated ? "✅ Authenticated" : "❌ Not authenticated"} | Route: $currentPath');
      if (user != null) {
        print(
            '👤 [ROUTER] User: ${user.email ?? "Anonymous"} (${user.isAnonymous ? "anonymous" : "authenticated"})');
      }

      // Public routes that don't require authentication
      final publicRoutes = [
        '/login',
        '/onboarding',
        '/onboarding/language',
        '/onboarding/purpose',
        '/auth/callback'
      ];
      final isPublicRoute = publicRoutes.contains(currentPath) ||
          currentPath.startsWith('/auth/callback');

      // If not authenticated and trying to access protected route, redirect to login
      if (!isAuthenticated && !isPublicRoute) {
        print(
            '🚫 [ROUTER] Blocking access to $currentPath, redirecting to /login');
        return '/login';
      }

      // If authenticated and on login page, redirect to home
      if (isAuthenticated && currentPath == '/login') {
        print('🏠 [ROUTER] User authenticated, redirecting to home');
        return '/';
      }

      return null; // No redirect needed
    },
    routes: [
      // Onboarding Flow (outside app shell)
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
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

      // Main App Routes (using StatefulShellRoute for proper navigation)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Home Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // Study Generation Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.generateStudy,
                name: 'generate_study',
                builder: (context, state) => const GenerateStudyScreen(),
              ),
            ],
          ),
          // Saved Guides Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.saved,
                name: 'saved',
                builder: (context, state) => const SavedScreenApi(),
              ),
            ],
          ),
          // Settings Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Authentication Routes (outside app shell)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.authCallback,
        name: 'auth_callback',
        builder: (context, state) {
          // Extract OAuth parameters from query parameters
          final code = state.uri.queryParameters['code'];
          final stateParam = state.uri.queryParameters['state'];
          final error = state.uri.queryParameters['error'];
          final errorDescription =
              state.uri.queryParameters['error_description'];

          return AuthCallbackPage(
            code: code,
            state: stateParam,
            error: error,
            errorDescription: errorDescription,
          );
        },
      ),

      // Full Screen Routes (outside shell)
      GoRoute(
        path: AppRoutes.studyGuide,
        name: 'study_guide',
        builder: (context, state) {
          // Handle different types of navigation data
          StudyGuide? studyGuide;
          Map<String, dynamic>? routeExtra;
          String? navigationSource;

          if (state.extra is StudyGuide) {
            studyGuide = state.extra as StudyGuide;
            // Check query parameters for source information
            navigationSource = state.uri.queryParameters['source'];
          } else if (state.extra is Map<String, dynamic>) {
            routeExtra = state.extra as Map<String, dynamic>;
            navigationSource = 'saved'; // Default for saved guides
          }

          return StudyGuideScreen(
            studyGuide: studyGuide,
            routeExtra: routeExtra,
            navigationSource: navigationSource,
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
      final onboardingCompleted =
          box.get('onboarding_completed', defaultValue: false);

      // Check if user is authenticated
      final user = Supabase.instance.client.auth.currentUser;
      final isAuthenticated = user != null;

      if (isAuthenticated) {
        // User is authenticated, go to home
        return AppRoutes.home;
      } else if (onboardingCompleted) {
        // Onboarding completed but not authenticated, go to login
        return AppRoutes.login;
      } else {
        // First time user, go to onboarding
        return AppRoutes.onboarding;
      }
    } catch (e) {
      // If Hive is not ready, default to login
      return AppRoutes.login;
    }
  }
}

// Navigation Extensions
extension AppRouterExtension on GoRouter {
  void goToOnboarding() => go(AppRoutes.onboarding);
  void goToOnboardingLanguage() => go(AppRoutes.onboardingLanguage);
  void goToOnboardingPurpose() => go(AppRoutes.onboardingPurpose);
  void goToHome() => go(AppRoutes.home);
  void goToGenerateStudy() => go(AppRoutes.generateStudy);
  void goToStudyGuide(StudyGuide studyGuide) =>
      go(AppRoutes.studyGuide, extra: studyGuide);
  void goToStudyGuideWithExtra(Map<String, dynamic> extra) =>
      go(AppRoutes.studyGuide, extra: extra);
  void goToStudyResult(StudyGuide studyGuide) =>
      go(AppRoutes.studyResult, extra: studyGuide);
  void goToSettings() => go(AppRoutes.settings);
  void goToSaved() => go(AppRoutes.saved);
  void goToLogin() => go(AppRoutes.login);
  void goToAuthCallback() => go(AppRoutes.authCallback);
  void goToError(String error) => go(AppRoutes.error, extra: error);
}
