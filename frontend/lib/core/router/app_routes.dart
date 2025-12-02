/// App route constants for consistent navigation
class AppRoutes {
  // ANDROID FIX: Loading screen during session restoration
  static const String appLoading = '/loading';

  static const String onboarding = '/onboarding';
  static const String languageSelection = '/language-selection';
  // static const String onboardingLanguage = '/onboarding/language';
  // static const String onboardingPurpose = '/onboarding/purpose';
  static const String home = '/';
  static const String generateStudy = '/generate-study';
  static const String studyGuide = '/study-guide';
  static const String studyGuideV2 = '/study-guide-v2';
  static const String settings = '/settings';
  static const String notificationSettings = '/notification-settings';
  static const String saved = '/saved';
  static const String studyTopics = '/study-topics';
  static const String tokenManagement = '/token-management';
  static const String purchaseHistory = '/token-management/purchase-history';
  static const String premiumUpgrade = '/premium-upgrade';
  static const String subscriptionManagement = '/subscription-management';
  static const String login = '/login';
  static const String phoneAuth = '/phone-auth';
  static const String phoneAuthVerify = '/phone-auth/verify';
  static const String emailAuth = '/email-auth';
  static const String passwordReset = '/password-reset';
  static const String profileSetup = '/profile-setup';
  static const String authCallback = '/auth/callback';
  static const String error = '/error';

  // Memory Verses
  static const String memoryVerses = '/memory-verses';
  static const String verseReview = '/memory-verse-review';

  // Voice Buddy
  static const String voiceConversation = '/voice-conversation';
  static const String voicePreferences = '/voice-preferences';

  // Personalization
  static const String personalizationQuestionnaire =
      '/personalization-questionnaire';

  // Learning Paths
  static const String learningPathDetail = '/learning-path/:pathId';

  // Leaderboard
  static const String leaderboard = '/leaderboard';
}
