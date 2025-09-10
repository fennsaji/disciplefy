import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/pages/onboarding_screen.dart';
import '../../features/onboarding/presentation/pages/language_selection_screen.dart';
import '../../features/onboarding/presentation/pages/onboarding_language_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_purpose_page.dart';
import '../../features/study_generation/presentation/pages/study_guide_screen.dart';
import '../../features/study_generation/domain/entities/study_guide.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/auth_callback_page.dart';
import '../presentation/widgets/app_shell.dart';
import '../error/error_page.dart';
import '../../features/home/presentation/pages/home_screen.dart';
import '../../features/study_generation/presentation/pages/generate_study_screen.dart';
import '../navigation/study_navigator.dart';
import '../di/injection_container.dart';
import '../../features/saved_guides/presentation/pages/saved_screen.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';
import '../../features/study_topics/presentation/pages/study_topics_screen.dart';
import '../../features/tokens/presentation/pages/token_management_page.dart';
import 'app_routes.dart';
import 'router_guard.dart';
import 'auth_notifier.dart';

class AppRouter {
  static final AuthNotifier _authNotifier = AuthNotifier();

  static final GoRouter router = GoRouter(
    initialLocation: '/', // Let the redirect logic handle the initial route
    refreshListenable: _authNotifier, // Listen to auth state changes
    redirect: (context, state) async =>
        await RouterGuard.handleRedirect(state.uri.path),
    routes: [
      // Onboarding Flow (outside app shell)
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.languageSelection,
        name: 'language_selection',
        builder: (context, state) => const LanguageSelectionScreen(),
      ),
      // GoRoute(
      //   path: AppRoutes.onboardingLanguage,
      //   name: 'onboarding_language',
      //   builder: (context, state) => const OnboardingLanguagePage(),
      // ),
      // GoRoute(
      //   path: AppRoutes.onboardingPurpose,
      //   name: 'onboarding_purpose',
      //   builder: (context, state) => const OnboardingPurposePage(),
      // ),

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
        ],
      ),

      // Standalone Routes (outside shell)
      GoRoute(
        path: AppRoutes.saved,
        name: 'saved',
        builder: (context, state) {
          // Parse tab parameter from query string
          final tabParam = state.uri.queryParameters['tab'];
          final sourceParam = state.uri.queryParameters['source'];
          int? initialTabIndex;
          if (tabParam == 'recent') {
            initialTabIndex = 1; // Recent tab
          } else if (tabParam == 'saved') {
            initialTabIndex = 0; // Saved tab
          }
          return SavedScreen(
            initialTabIndex: initialTabIndex,
            navigationSource: sourceParam,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.studyTopics,
        name: 'study_topics',
        builder: (context, state) => const StudyTopicsScreen(),
      ),
      GoRoute(
        path: AppRoutes.tokenManagement,
        name: 'token_management',
        builder: (context, state) => const TokenManagementPage(),
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

          // Parse navigation source from query parameters
          final sourceString = state.uri.queryParameters['source'];
          final navigationSource =
              sl<StudyNavigator>().parseNavigationSource(sourceString);

          if (state.extra is StudyGuide) {
            studyGuide = state.extra as StudyGuide;
          } else if (state.extra is Map<String, dynamic>) {
            routeExtra = state.extra as Map<String, dynamic>;
          }

          return StudyGuideScreen(
            studyGuide: studyGuide,
            routeExtra: routeExtra,
            navigationSource: navigationSource,
          );
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
}

// Navigation Extensions
extension AppRouterExtension on GoRouter {
  void goToOnboarding() => go(AppRoutes.onboarding);
  // void goToOnboardingLanguage() => go(AppRoutes.onboardingLanguage);
  // void goToOnboardingPurpose() => go(AppRoutes.onboardingPurpose);
  void goToHome() => go(AppRoutes.home);
  void goToGenerateStudy() => go(AppRoutes.generateStudy);
  void goToStudyGuide(StudyGuide studyGuide) =>
      go(AppRoutes.studyGuide, extra: studyGuide);
  void goToStudyGuideWithExtra(Map<String, dynamic> extra) =>
      go(AppRoutes.studyGuide, extra: extra);
  void goToSettings() => go(AppRoutes.settings);
  void goToSaved() => go(AppRoutes.saved);
  void goToStudyTopics() => go(AppRoutes.studyTopics);
  void goToTokenManagement() => go(AppRoutes.tokenManagement);
  void goToLogin() => go(AppRoutes.login);
  void goToAuthCallback() => go(AppRoutes.authCallback);
  void goToError(String error) => go(AppRoutes.error, extra: error);
}
