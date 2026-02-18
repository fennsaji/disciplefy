import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../navigation/route_observer.dart';
import '../animations/page_transitions.dart';
import '../screens/maintenance_screen.dart';
import '../services/system_config_service.dart';
import '../../features/onboarding/presentation/pages/onboarding_screen.dart';
import '../../features/onboarding/presentation/pages/language_selection_screen.dart';
import '../../features/onboarding/presentation/pages/onboarding_language_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_purpose_page.dart';
import '../../features/study_generation/presentation/pages/study_guide_screen_v2.dart';
import '../../features/study_generation/domain/entities/study_mode.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/phone_number_input_screen.dart';
import '../../features/auth/presentation/pages/otp_verification_screen.dart';
import '../../features/auth/presentation/pages/email_auth_screen.dart';
import '../../features/auth/presentation/pages/password_reset_screen.dart';
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
import '../../features/tokens/presentation/pages/token_purchase_page.dart';
import '../../features/tokens/presentation/pages/purchase_history_page.dart';
import '../../features/tokens/presentation/pages/token_usage_history_page.dart';
import '../../features/tokens/domain/entities/token_status.dart';
import '../../features/subscription/presentation/pages/premium_upgrade_page.dart';
import '../../features/subscription/presentation/pages/plus_upgrade_page.dart';
import '../../features/subscription/presentation/pages/standard_upgrade_page.dart';
import '../../features/subscription/presentation/pages/subscription_management_page.dart';
import '../../features/subscription/presentation/pages/subscription_payment_history_page.dart';
import '../../features/subscription/presentation/pages/my_plan_page.dart';
import '../../features/subscription/presentation/pages/pricing_page.dart';
import '../../core/services/platform_detection_service.dart';
import '../../features/subscription/data/datasources/subscription_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/subscription/presentation/bloc/subscription_bloc.dart';
import '../../features/memory_verses/presentation/pages/memory_verses_home_page.dart';
import '../../features/memory_verses/presentation/pages/verse_review_page.dart';
import '../../features/memory_verses/presentation/pages/practice_mode_selection_page.dart';
import '../../features/memory_verses/presentation/pages/word_bank_practice_page.dart';
import '../../features/memory_verses/presentation/pages/cloze_review_page.dart';
import '../../features/memory_verses/presentation/pages/first_letter_hints_page.dart';
import '../../features/memory_verses/presentation/pages/progressive_reveal_practice_page.dart';
import '../../features/memory_verses/presentation/pages/word_scramble_practice_page.dart';
import '../../features/memory_verses/presentation/pages/memory_champions_page.dart';
import '../../features/memory_verses/presentation/pages/memory_stats_page.dart';
import '../../features/memory_verses/presentation/pages/audio_practice_page.dart';
import '../../features/memory_verses/presentation/pages/type_it_out_practice_page.dart';
import '../../features/memory_verses/presentation/pages/practice_results_page.dart';
import '../../features/memory_verses/domain/entities/practice_result_params.dart';
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
import '../widgets/locked_feature_wrapper.dart';
import '../../features/study_topics/presentation/bloc/leaderboard_bloc.dart';
import '../../features/gamification/presentation/pages/stats_dashboard_page.dart';
import '../../features/gamification/presentation/bloc/gamification_bloc.dart';
import '../../features/study_generation/presentation/pages/reflection_journal_screen.dart';
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
    observers: [
      appRouteObserver, // Track navigation events for background API handling
    ],
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

      // SYSTEM CONFIG: Maintenance mode screen
      GoRoute(
        path: AppRoutes.maintenance,
        name: 'maintenance',
        builder: (context, state) => MaintenanceScreen(
          configService: sl<SystemConfigService>(),
        ),
      ),

      // Onboarding Flow (outside app shell)
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => fadeTransitionPage(
          child: const OnboardingScreen(),
          state: state,
        ),
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
        pageBuilder: (context, state) {
          // Parse tab parameter from query string
          final tabParam = state.uri.queryParameters['tab'];
          final sourceParam = state.uri.queryParameters['source'];
          int? initialTabIndex;
          if (tabParam == 'recent') {
            initialTabIndex = 1; // Recent tab
          } else if (tabParam == 'saved') {
            initialTabIndex = 0; // Saved tab
          }
          return slideRightTransitionPage(
            child: SavedScreen(
              initialTabIndex: initialTabIndex,
              navigationSource: sourceParam,
            ),
            state: state,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => slideUpTransitionPage(
          child: const SettingsScreen(),
          state: state,
        ),
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
        path: AppRoutes.tokenPurchase,
        name: 'token_purchase',
        builder: (context, state) {
          final tokenStatus = state.extra as TokenStatus?;
          if (tokenStatus == null) {
            return const Scaffold(
              body: Center(child: Text('Error: Missing token status')),
            );
          }
          return TokenPurchasePage(
            tokenStatus: tokenStatus,
            userEmail: Supabase.instance.client.auth.currentUser?.email ?? '',
            userPhone: Supabase.instance.client.auth.currentUser?.phone ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.purchaseHistory,
        name: 'purchase_history',
        builder: (context, state) => const PurchaseHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.usageHistory,
        name: 'usage_history',
        builder: (context, state) => const TokenUsageHistoryPage(),
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
        path: AppRoutes.plusUpgrade,
        name: 'plus_upgrade',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<SubscriptionBloc>(),
          child: const PlusUpgradePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.standardUpgrade,
        name: 'standard_upgrade',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<SubscriptionBloc>(),
          child: const StandardUpgradePage(),
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
      GoRoute(
        path: AppRoutes.myPlan,
        name: 'my_plan',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<SubscriptionBloc>(),
          child: const MyPlanPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.subscriptionPaymentHistory,
        name: 'subscription_payment_history',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<SubscriptionBloc>(),
          child: const SubscriptionPaymentHistoryPage(),
        ),
      ),

      // Memory Verses Routes (outside app shell)
      GoRoute(
        path: AppRoutes.memoryVerses,
        name: 'memory_verses',
        pageBuilder: (context, state) => slideRightTransitionPage(
          child: LockedFeatureWrapper(
            featureKey: 'memory_verses',
            child: BlocProvider(
              create: (context) => sl<MemoryVerseBloc>(),
              child: const MemoryVersesHomePage(),
            ),
          ),
          state: state,
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
      // Practice results route must come BEFORE the wildcard :verseId route
      GoRoute(
        path: AppRoutes.practiceResults,
        name: 'practice_results',
        redirect: (context, state) {
          // Redirect to memory verses if params are missing (e.g., page refresh on web)
          if (state.extra == null) {
            return AppRoutes.memoryVerses;
          }
          return null;
        },
        builder: (context, state) {
          final params = state.extra as PracticeResultParams;
          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: PracticeResultsPage(params: params),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.practiceModeSelection,
        name: 'practice_mode_selection',
        builder: (context, state) {
          final verseId = state.pathParameters['verseId'] ?? '';
          final lastMode = state.uri.queryParameters['lastMode'];
          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: PracticeModeSelectionPage(
              verseId: verseId,
              lastPracticeMode: lastMode,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.wordBankPractice,
        name: 'word_bank_practice',
        builder: (context, state) {
          final verseId = state.pathParameters['verseId'] ?? '';
          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: WordBankPracticePage(verseId: verseId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.clozePractice,
        name: 'cloze_practice',
        builder: (context, state) {
          final verseId = state.pathParameters['verseId'] ?? '';
          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: ClozeReviewPage(verseId: verseId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.firstLetterPractice,
        name: 'first_letter_practice',
        builder: (context, state) {
          final verseId = state.pathParameters['verseId'] ?? '';
          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: FirstLetterHintsPage(verseId: verseId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.progressivePractice,
        name: 'progressive_practice',
        builder: (context, state) {
          final verseId = state.pathParameters['verseId'] ?? '';
          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: ProgressiveRevealPracticePage(verseId: verseId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.wordScramblePractice,
        name: 'word_scramble_practice',
        builder: (context, state) {
          final verseId = state.pathParameters['verseId'] ?? '';
          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: WordScramblePracticePage(verseId: verseId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.audioPractice,
        name: 'audio_practice',
        builder: (context, state) {
          final verseId = state.pathParameters['verseId'] ?? '';
          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: AudioPracticePage(verseId: verseId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.typeItOutPractice,
        name: 'type_it_out_practice',
        builder: (context, state) {
          final verseId = state.pathParameters['verseId'] ?? '';
          return BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: TypeItOutPracticePage(verseId: verseId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.memoryChampions,
        name: 'memory_champions',
        pageBuilder: (context, state) => slideRightTransitionPage(
          child: const MemoryChampionsPage(),
          state: state,
        ),
      ),
      GoRoute(
        path: AppRoutes.memoryStats,
        name: 'memory_stats',
        pageBuilder: (context, state) => slideRightTransitionPage(
          child: BlocProvider(
            create: (context) => sl<MemoryVerseBloc>(),
            child: const MemoryStatsPage(),
          ),
          state: state,
        ),
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

          return LockedFeatureWrapper(
            featureKey: 'ai_discipler',
            child: VoiceConversationPage(
              studyGuideId: studyGuideId,
              relatedScripture: relatedScripture,
              conversationType: conversationType,
            ),
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
        path: AppRoutes.learningPathDetail,
        name: 'learning_path_detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final pathId = state.pathParameters['pathId'] ?? '';
          final source = state.uri.queryParameters['source'];
          return LockedFeatureWrapper(
            featureKey: 'learning_paths',
            child: BlocProvider(
              create: (context) => sl<LearningPathsBloc>(),
              child: LearningPathDetailPage(pathId: pathId, source: source),
            ),
          );
        },
      ),

      // Leaderboard Route
      GoRoute(
        path: AppRoutes.leaderboard,
        name: 'leaderboard',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => LockedFeatureWrapper(
          featureKey: 'leaderboard',
          child: BlocProvider(
            create: (context) => sl<LeaderboardBloc>(),
            child: const LeaderboardPage(),
          ),
        ),
      ),

      // Stats Dashboard (My Progress) Route
      GoRoute(
        path: AppRoutes.statsDashboard,
        name: 'stats_dashboard',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => LockedFeatureWrapper(
          featureKey: 'leaderboard',
          child: BlocProvider.value(
            value: sl<GamificationBloc>(),
            child: const StatsDashboardPage(),
          ),
        ),
      ),

      // Reflection Journal Route
      GoRoute(
        path: AppRoutes.reflectionJournal,
        name: 'reflection_journal',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => slideRightTransitionPage(
          child: LockedFeatureWrapper(
            featureKey: 'reflections',
            child: const ReflectionJournalScreen(),
          ),
          state: state,
        ),
      ),

      // Public Pricing Page (accessible without authentication)
      GoRoute(
        path: AppRoutes.pricing,
        name: 'pricing',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => PricingPage(
          platformService: PlatformDetectionService(),
          dataSource: SubscriptionRemoteDataSourceImpl(
            supabaseClient: Supabase.instance.client,
          ),
        ),
      ),

      // Authentication Routes (outside app shell)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => fadeTransitionPage(
          child: const LoginScreen(),
          state: state,
        ),
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
        path: AppRoutes.emailAuth,
        name: 'email_auth',
        builder: (context, state) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.passwordReset,
        name: 'password_reset',
        builder: (context, state) => const PasswordResetScreen(),
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
      // Study Guide Screen - Unified route using V2 implementation
      // Supports both query parameters and extra data for backward compatibility
      GoRoute(
        path: AppRoutes.studyGuide,
        name: 'study_guide',
        pageBuilder: (context, state) {
          // Parse query parameters (for v2-style navigation)
          final topicId = state.uri.queryParameters['topic_id'];
          String? input = state.uri.queryParameters['input'];
          String? type = state.uri.queryParameters['type'];
          final description = state.uri.queryParameters['description'];
          String? language = state.uri.queryParameters['language'];
          final sourceString = state.uri.queryParameters['source'];
          final modeString = state.uri.queryParameters['mode'];

          // Handle extra data (for saved/recent guides with existing content)
          Map<String, dynamic>? existingGuideData;
          if (state.extra is Map<String, dynamic>) {
            final extraData = state.extra as Map<String, dynamic>;
            final studyGuideData =
                extraData['study_guide'] as Map<String, dynamic>?;

            if (studyGuideData != null) {
              existingGuideData = studyGuideData;

              // Extract data from study_guide map for parameters
              input ??= studyGuideData['verse_reference'] ??
                  studyGuideData['topic_name'] ??
                  studyGuideData['title'];
              type ??= studyGuideData['type'];
              language ??= 'en'; // Default language

              // Extract study mode if available
              final guideMode = studyGuideData['study_mode'] as String?;
              if (guideMode != null && modeString == null) {
                // Use the saved study mode
              }
            }
          }

          // Parse navigation source
          final navigationSource =
              sl<StudyNavigator>().parseNavigationSource(sourceString);

          // Parse study mode (default to standard)
          final studyMode = studyModeFromString(
                  modeString ?? existingGuideData?['study_mode']) ??
              StudyMode.standard;

          return slideRightTransitionPage(
            child: StudyGuideScreenV2(
              topicId: topicId,
              input: input,
              type: type,
              description: description,
              language: language,
              navigationSource: navigationSource,
              studyMode: studyMode,
              existingGuideData: existingGuideData,
            ),
            state: state,
          );
        },
      ),

      // Study Guide V2 - Dynamic generation from query parameters
      GoRoute(
        path: AppRoutes.studyGuideV2,
        name: 'study_guide_v2',
        pageBuilder: (context, state) {
          // Parse query parameters
          final topicId = state.uri.queryParameters['topic_id'];
          final input = state.uri.queryParameters['input'];
          final type = state.uri.queryParameters['type'];
          final description = state.uri.queryParameters['description'];
          final language = state.uri.queryParameters['language'];
          final sourceString = state.uri.queryParameters['source'];
          final modeString = state.uri.queryParameters['mode'];

          // Parse navigation source
          final navigationSource =
              sl<StudyNavigator>().parseNavigationSource(sourceString);

          // Parse study mode (default to standard)
          final studyMode =
              studyModeFromString(modeString) ?? StudyMode.standard;

          return slideRightTransitionPage(
            child: StudyGuideScreenV2(
              topicId: topicId,
              input: input,
              type: type,
              description: description,
              language: language,
              navigationSource: navigationSource,
              studyMode: studyMode,
            ),
            state: state,
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
  void goToStudyGuideWithExtra(Map<String, dynamic> extra) =>
      go(AppRoutes.studyGuide, extra: extra);
  void goToSettings() => go(AppRoutes.settings);
  void goToSaved() => go(AppRoutes.saved);
  void goToStudyTopics() => go(AppRoutes.studyTopics);

  /// Navigates to the token management page where users can view balance, purchase tokens, and manage payment methods.
  void goToTokenManagement() => go(AppRoutes.tokenManagement);

  /// Navigates to the token purchase page where users can purchase additional tokens.
  void goToTokenPurchase(TokenStatus tokenStatus) =>
      go(AppRoutes.tokenPurchase, extra: tokenStatus);

  /// Navigates to the purchase history page where users can view their past token purchases.
  void goToPurchaseHistory() => go(AppRoutes.purchaseHistory);

  /// Navigates to the unified My Plan page showing plan details, billing, and history.
  void goToMyPlan() => go(AppRoutes.myPlan);

  /// Navigates to the subscription payment history page where users can view their subscription invoices.
  void goToSubscriptionPaymentHistory() =>
      go(AppRoutes.subscriptionPaymentHistory);
  void goToLogin() => go(AppRoutes.login);
  void goToPhoneAuth() => go(AppRoutes.phoneAuth);
  void goToEmailAuth() => go(AppRoutes.emailAuth);
  void goToPasswordReset() => go(AppRoutes.passwordReset);
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

  /// Navigates to the practice mode selection page.
  ///
  /// [verseId] - Required ID of the verse to practice
  void goToPracticeModeSelection(String verseId) =>
      go('/memory-verses/practice/$verseId');

  /// Navigates to the word bank practice page.
  ///
  /// [verseId] - Required ID of the verse to practice
  void goToWordBankPractice(String verseId) =>
      go('/memory-verses/practice/word-bank/$verseId');

  /// Navigates to the cloze deletion practice page.
  ///
  /// [verseId] - Required ID of the verse to practice
  void goToClozePractice(String verseId) =>
      go('/memory-verses/practice/cloze/$verseId');

  /// Navigates to the first letter hints practice page.
  ///
  /// [verseId] - Required ID of the verse to practice
  void goToFirstLetterPractice(String verseId) =>
      go('/memory-verses/practice/first-letter/$verseId');

  void goToProgressivePractice(String verseId) =>
      go('/memory-verses/practice/progressive/$verseId');

  void goToWordScramblePractice(String verseId) =>
      go('/memory-verses/practice/word-scramble/$verseId');

  /// Navigates to the type it out practice page.
  ///
  /// [verseId] - Required ID of the verse to practice
  void goToTypeItOutPractice(String verseId) =>
      go('/memory-verses/practice/type-it-out/$verseId');

  /// Navigates to the memory champions leaderboard page.
  void goToMemoryChampions() => go(AppRoutes.memoryChampions);

  /// Navigates to the memory verses statistics page with heat map.
  void goToMemoryStats() => go(AppRoutes.memoryStats);

  /// Navigates to the practice results page with completion stats.
  ///
  /// [params] - Required practice result parameters containing all stats
  void goToPracticeResults(PracticeResultParams params) =>
      go(AppRoutes.practiceResults, extra: params);

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

  /// Navigates to the stats dashboard (My Progress) page showing gamification stats.
  void goToStatsDashboard() => go(AppRoutes.statsDashboard);

  /// Navigates to the reflection journal page showing past reflections.
  void goToReflectionJournal() => go(AppRoutes.reflectionJournal);
}
