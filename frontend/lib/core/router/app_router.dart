import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/pages/onboarding_screen.dart';
import '../../features/onboarding/presentation/pages/language_selection_screen.dart';
import '../../features/onboarding/presentation/pages/onboarding_language_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_purpose_page.dart';
import '../../features/study_generation/presentation/pages/study_guide_screen.dart';
import '../../features/study_generation/presentation/pages/study_guide_screen_v2.dart';
import '../../features/study_generation/domain/entities/study_guide.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/phone_number_input_screen.dart';
import '../../features/auth/presentation/pages/otp_verification_screen.dart';
import '../../features/auth/presentation/pages/auth_callback_page.dart';
import '../../features/profile_setup/presentation/pages/profile_setup_screen.dart';
import '../presentation/widgets/app_shell.dart';
import '../error/error_page.dart';
import '../../features/home/presentation/pages/home_screen.dart';
import '../../features/study_generation/presentation/pages/generate_study_screen.dart';
import '../navigation/study_navigator.dart';
import '../di/injection_container.dart';
import '../../features/saved_guides/presentation/pages/saved_screen.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';
import '../../features/notifications/presentation/pages/notification_settings_screen.dart';
import '../../features/study_topics/presentation/pages/study_topics_screen.dart';
import '../../features/tokens/presentation/pages/token_management_page.dart';
import '../../features/tokens/presentation/pages/purchase_history_page.dart';
import '../../features/subscription/presentation/pages/premium_upgrade_page.dart';
import '../../features/subscription/presentation/pages/subscription_management_page.dart';
import '../../features/subscription/presentation/bloc/subscription_bloc.dart';
import '../../features/memory_verses/presentation/pages/memory_verses_home_page.dart';
import '../../features/memory_verses/presentation/pages/verse_review_page.dart';
import '../../features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import '../../features/voice_buddy/presentation/pages/voice_conversation_page.dart';
import '../../features/voice_buddy/presentation/pages/voice_preferences_page.dart';
import '../../features/voice_buddy/presentation/pages/voice_preferences_page_wrapper.dart';
import '../../features/voice_buddy/presentation/bloc/voice_preferences_bloc.dart';
import '../../features/voice_buddy/presentation/bloc/voice_preferences_event.dart';
import '../../features/voice_buddy/presentation/bloc/voice_preferences_state.dart';
import '../../features/voice_buddy/domain/entities/voice_conversation_entity.dart';
import '../../features/voice_buddy/domain/entities/voice_preferences_entity.dart';
import '../../features/voice_buddy/domain/repositories/voice_buddy_repository.dart';
import '../../features/personalization/presentation/pages/personalization_questionnaire_page.dart';
import '../../features/study_topics/presentation/pages/learning_path_detail_page.dart';
import '../../features/study_topics/presentation/pages/leaderboard_page.dart';
import '../../features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'app_routes.dart';
import 'router_guard.dart';
import 'auth_notifier.dart';
import 'app_loading_screen.dart'; // ANDROID FIX: Loading screen during session restoration

class AppRouter {
  static final AuthNotifier _authNotifier = AuthNotifier();

  /// Root navigator key for routes that should be pushed outside the shell
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/', // Let the redirect logic handle the initial route
    refreshListenable: _authNotifier, // Listen to auth state changes
    redirect: (context, state) async => await RouterGuard.handleRedirect(
      state.uri.path,
      isAuthInitialized:
          _authNotifier.isInitialized, // ANDROID FIX: Pass initialization state
    ),
    routes: [
      // ANDROID FIX: Loading screen shown during session restoration
      GoRoute(
        path: AppRoutes.appLoading,
        name: 'app_loading',
        builder: (context, state) => const AppLoadingScreen(),
      ),

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
      GoRoute(
        path: AppRoutes.profileSetup,
        name: 'profile_setup',
        builder: (context, state) => const ProfileSetupScreen(),
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
          // Study Topics Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studyTopics,
                name: 'study_topics_tab',
                builder: (context, state) {
                  // Extract topic_id from query parameters for notification deep linking
                  final topicId = state.uri.queryParameters['topic_id'];
                  return StudyTopicsScreen(topicId: topicId);
                },
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
        path: AppRoutes.notificationSettings,
        name: 'notification_settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.tokenManagement,
        name: 'token_management',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<SubscriptionBloc>(),
          child: const TokenManagementPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.purchaseHistory,
        name: 'purchase_history',
        builder: (context, state) => const PurchaseHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.premiumUpgrade,
        name: 'premium_upgrade',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<SubscriptionBloc>(),
          child: const PremiumUpgradePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.subscriptionManagement,
        name: 'subscription_management',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<SubscriptionBloc>(),
          child: const SubscriptionManagementPage(),
        ),
      ),

      // Memory Verses Routes (outside app shell)
      GoRoute(
        path: AppRoutes.memoryVerses,
        name: 'memory_verses',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<MemoryVerseBloc>(),
          child: const MemoryVersesHomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.verseReview,
        name: 'verse_review',
        builder: (context, state) {
          // Extract verse ID and optional verse list from extra data
          final Map<String, dynamic> extra;
          if (state.extra is Map<String, dynamic>) {
            extra = state.extra as Map<String, dynamic>;
          } else {
            extra = {};
          }

          final verseId = extra['verseId'] as String? ?? '';
          final verseIds = extra['verseIds'] as List<String>?;

          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: VerseReviewPage(
              verseId: verseId,
              verseIds: verseIds,
            ),
          );
        },
      ),

      // Voice Buddy Routes
      GoRoute(
        path: AppRoutes.voiceConversation,
        name: 'voice_conversation',
        builder: (context, state) {
          // Extract optional parameters from extra data
          final Map<String, dynamic> extra;
          if (state.extra is Map<String, dynamic>) {
            extra = state.extra as Map<String, dynamic>;
          } else {
            extra = {};
          }

          final studyGuideId = extra['studyGuideId'] as String?;
          final relatedScripture = extra['relatedScripture'] as String?;
          final conversationType =
              extra['conversationType'] as ConversationType? ??
                  ConversationType.general;

          return VoiceConversationPage(
            studyGuideId: studyGuideId,
            relatedScripture: relatedScripture,
            conversationType: conversationType,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.voicePreferences,
        name: 'voice_preferences',
        builder: (context, state) => BlocProvider(
          create: (_) => VoicePreferencesBloc(
            repository: sl<VoiceBuddyRepository>(),
          )..add(const LoadVoicePreferences()),
          child: const VoicePreferencesPageWrapper(),
        ),
      ),

      // Personalization Routes
      GoRoute(
        path: AppRoutes.personalizationQuestionnaire,
        name: 'personalization_questionnaire',
        builder: (context, state) {
          // Extract onComplete callback from extra if provided
          VoidCallback? onComplete;
          if (state.extra is Map<String, dynamic>) {
            final extra = state.extra as Map<String, dynamic>;
            onComplete = extra['onComplete'] as VoidCallback?;
          }
          return PersonalizationQuestionnairePage(onComplete: onComplete);
        },
      ),

      // Learning Paths Routes
      GoRoute(
        path: '/learning-path/:pathId',
        name: 'learning_path_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final pathId = state.pathParameters['pathId'] ?? '';
          final source = state.uri.queryParameters['source'];
          return BlocProvider(
            create: (context) => sl<LearningPathsBloc>(),
            child: LearningPathDetailPage(pathId: pathId, source: source),
          );
        },
      ),

      // Leaderboard Route
      GoRoute(
        path: AppRoutes.leaderboard,
        name: 'leaderboard',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LeaderboardPage(),
      ),

      // Authentication Routes (outside app shell)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.phoneAuth,
        name: 'phone_auth',
        builder: (context, state) => const PhoneNumberInputScreen(),
      ),
      GoRoute(
        path: AppRoutes.phoneAuthVerify,
        name: 'phone_auth_verify',
        builder: (context, state) {
          // Safely extract phone auth parameters from extra data
          // Type-safe casting to prevent runtime crashes
          final Map<String, dynamic> extra;
          if (state.extra is Map<String, dynamic>) {
            extra = state.extra as Map<String, dynamic>;
          } else {
            // Graceful degradation: use empty map if extra is not a Map
            extra = {};
          }

          final phoneNumber = extra['phoneNumber'] as String? ?? '';
          final countryCode = extra['countryCode'] as String? ?? '+1';
          final expiresIn = extra['expiresIn'] as int? ?? 60;
          final sentAt = extra['sentAt'] as DateTime? ?? DateTime.now();

          return OTPVerificationScreen(
            phoneNumber: phoneNumber,
            countryCode: countryCode,
            expiresIn: expiresIn,
            sentAt: sentAt,
          );
        },
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

      // Study Guide V2 - Dynamic generation from query parameters
      GoRoute(
        path: AppRoutes.studyGuideV2,
        name: 'study_guide_v2',
        builder: (context, state) {
          // Parse query parameters
          final topicId = state.uri.queryParameters['topic_id'];
          final input = state.uri.queryParameters['input'];
          final type = state.uri.queryParameters['type'];
          final description = state.uri.queryParameters['description'];
          final language = state.uri.queryParameters['language'];
          final sourceString = state.uri.queryParameters['source'];

          // Parse navigation source
          final navigationSource =
              sl<StudyNavigator>().parseNavigationSource(sourceString);

          return StudyGuideScreenV2(
            topicId: topicId,
            input: input,
            type: type,
            description: description,
            language: language,
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

  /// Navigates to the token management page where users can view balance, purchase tokens, and manage payment methods.
  void goToTokenManagement() => go(AppRoutes.tokenManagement);

  /// Navigates to the purchase history page where users can view their past token purchases.
  void goToPurchaseHistory() => go(AppRoutes.purchaseHistory);
  void goToLogin() => go(AppRoutes.login);
  void goToPhoneAuth() => go(AppRoutes.phoneAuth);
  void goToPhoneAuthVerify({
    required String phoneNumber,
    required String countryCode,
    required int expiresIn,
    required DateTime sentAt,
  }) =>
      go(AppRoutes.phoneAuthVerify, extra: {
        'phoneNumber': phoneNumber,
        'countryCode': countryCode,
        'expiresIn': expiresIn,
        'sentAt': sentAt,
      });
  void goToAuthCallback() => go(AppRoutes.authCallback);
  void goToError(String error) => go(AppRoutes.error, extra: error);

  /// Navigates to the memory verses home page where users can view and manage their memorization deck.
  void goToMemoryVerses() => go(AppRoutes.memoryVerses);

  /// Navigates to the verse review page for spaced repetition review.
  ///
  /// [verseId] - Required ID of the verse to review
  /// [verseIds] - Optional list of verse IDs for sequential review
  void goToVerseReview({
    required String verseId,
    List<String>? verseIds,
  }) =>
      go(AppRoutes.verseReview, extra: {
        'verseId': verseId,
        'verseIds': verseIds,
      });

  /// Navigates to the voice conversation page for AI Discipler.
  ///
  /// [studyGuideId] - Optional study guide ID for contextual conversations
  /// [relatedScripture] - Optional scripture reference for focused discussions
  /// [conversationType] - Type of conversation (general, study_guide, scripture_exploration, etc.)
  void goToVoiceConversation({
    String? studyGuideId,
    String? relatedScripture,
    ConversationType conversationType = ConversationType.general,
  }) =>
      go(AppRoutes.voiceConversation, extra: {
        'studyGuideId': studyGuideId,
        'relatedScripture': relatedScripture,
        'conversationType': conversationType,
      });

  /// Navigates to the personalization questionnaire page.
  ///
  /// [onComplete] - Optional callback to execute when questionnaire is completed
  void goToPersonalizationQuestionnaire({VoidCallback? onComplete}) =>
      go(AppRoutes.personalizationQuestionnaire, extra: {
        'onComplete': onComplete,
      });

  /// Navigates to the leaderboard page showing XP rankings.
  void goToLeaderboard() => go(AppRoutes.leaderboard);
}
