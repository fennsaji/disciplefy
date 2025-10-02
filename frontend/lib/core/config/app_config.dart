import 'package:flutter/foundation.dart';

/// Application configuration based on environment
/// References: Technical Architecture Document, Security Design Plan
class AppConfig {
  // Supabase Configuration (Primary Backend)
  // CRITICAL FIX: Use explicit environment variable without conditional defaultValue
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  // App URL - Used as fallback when dynamic origin detection fails
  static const String appUrl = String.fromEnvironment('APP_URL');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  // OAuth Configuration
  static const String googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID');

  // Apple OAuth not implemented yet - placeholder for future
  static const String appleClientId = 'com.disciplefy.bible_study';

  // App Configuration
  static const String appVersion = '1.0.0';
  static const String apiVersion = 'v1';
  static const String packageName = 'com.disciplefy.bible_study';

  // OAuth Redirect URLs - SECURITY FIX: Use compile-time constants
  // CRITICAL: These MUST be set via --dart-define at build time
  static const String webOAuthRedirectUrl = String.fromEnvironment(
    'WEB_OAUTH_REDIRECT_URL',
  );

  static const String mobileOAuthRedirectScheme = String.fromEnvironment(
    'MOBILE_OAUTH_REDIRECT_SCHEME',
    defaultValue: 'com.disciplefy.bible_study_app',
  );

  /// Get OAuth redirect URL (compile-time constant, not runtime)
  /// Build examples:
  /// - Development: flutter run --dart-define=WEB_OAUTH_REDIRECT_URL=http://localhost:3000/auth/callback
  /// - Production: flutter build web --dart-define=WEB_OAUTH_REDIRECT_URL=https://disciplefy.com/auth/callback
  static String get authRedirectUrl {
    if (kIsWeb) {
      // SECURITY FIX: Use pre-configured URL from build time, not runtime Uri.base
      if (webOAuthRedirectUrl.isEmpty) {
        // In development, fall back to localhost for convenience
        if (isDevelopment) {
          return 'http://localhost:3000/auth/callback';
        }

        // In production, this is a CRITICAL configuration error
        throw Exception(
            'CRITICAL SECURITY ERROR: WEB_OAUTH_REDIRECT_URL not configured.\n'
            'OAuth redirect URL MUST be set via --dart-define at build time.\n'
            'Example: flutter build web --dart-define=WEB_OAUTH_REDIRECT_URL=https://your-domain.com/auth/callback');
      }
      return webOAuthRedirectUrl;
    }

    // Mobile uses deep link scheme
    return '$mobileOAuthRedirectScheme://auth/callback';
  }

  // OAuth redirect schemes for deep linking
  static const List<String> oauthRedirectSchemes = [
    'com.disciplefy.bible_study',
    'io.supabase.flutter',
  ];

  // Auth endpoints
  static const String authSessionEndpoint = '/auth-session';
  static const String googleOAuthCallbackEndpoint = '/auth-google-callback';

  // Rate Limiting (from API Contract Documentation)
  // Note: These are hardcoded as they're client-side limits, not server configuration
  static const int anonymousRateLimit = 3; // guides per hour
  static const int authenticatedRateLimit = 10; // guides per hour
  static const int apiRequestLimit = 100; // requests per hour for authenticated

  // Security Configuration
  static const int sessionTimeoutHours = 24;
  static const int anonymousSessionTimeoutHours = 24;
  static const int maxInputLength = 500;

  // Supported Languages (from PRD)
  static const List<String> supportedLanguages = ['en', 'hi', 'ml'];
  static const String defaultLanguage = 'en';

  // Offline Strategy Configuration
  static const int maxCachedStudyGuides = 50;
  static const int maxCachedBibleVerses = 500;
  static const int cacheRetentionDays = 30;
  static const String maxOfflineStorageSize = '100MB';

  // Cache Refresh Configuration
  static const int dailyVerseCacheRefreshHours =
      1; // Refresh daily verse cache after 1 hour

  // Environment Detection - Fixed for production builds
  // CRITICAL FIX: Use FLUTTER_ENV dart-define instead of kDebugMode
  // kDebugMode is unreliable in production builds and causes wrong Supabase URL selection
  static const String _flutterEnv =
      String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');

  static bool get isProduction => _flutterEnv == 'production';
  static bool get isDevelopment => _flutterEnv == 'development';
  static String get environment => _flutterEnv;

  // Feature Flags
  static bool get enableOfflineMode => true;
  static bool get enableAnalytics => isProduction;
  static bool get enableCrashReporting => isProduction;
  static bool get enablePerformanceMonitoring => true;

  // API Base URLs
  static String get baseApiUrl => '$supabaseUrl/functions/v1';
  static String get studyGenerationUrl => '$baseApiUrl/study/generate';
  static String get feedbackUrl => '$baseApiUrl/feedback';
  static String get donationsUrl => '$baseApiUrl/donations';

  // Validation
  static bool get isConfigValid =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isOAuthConfigValid {
    return (kIsWeb && googleClientId.isNotEmpty) ||
        (!kIsWeb); // Mobile gets config from platform-specific files
  }

  /// Validates that all required configuration values are present
  /// Throws detailed exceptions for missing critical configuration
  static void validateConfiguration() {
    final List<String> missingConfigs = [];

    if (supabaseUrl.isEmpty) {
      missingConfigs.add('SUPABASE_URL');
    }

    if (supabaseAnonKey.isEmpty) {
      missingConfigs.add('SUPABASE_ANON_KEY');
    }

    if (kIsWeb && googleClientId.isEmpty) {
      missingConfigs.add('GOOGLE_CLIENT_ID (required for web)');
    }

    // SECURITY FIX: Validate OAuth redirect URL configuration
    if (kIsWeb && !isDevelopment && webOAuthRedirectUrl.isEmpty) {
      missingConfigs
          .add('WEB_OAUTH_REDIRECT_URL (required for production web builds)');
    }

    if (missingConfigs.isNotEmpty) {
      throw Exception(
          'Missing required environment variables: ${missingConfigs.join(', ')}. '
          'Please set these environment variables before running the application.');
    }

    // Validate format of critical URLs
    if (!supabaseUrl.startsWith('http')) {
      throw Exception('SUPABASE_URL must be a valid HTTP/HTTPS URL');
    }

    // SECURITY FIX: Validate OAuth redirect URL format
    if (kIsWeb) {
      try {
        final redirectUri = Uri.parse(authRedirectUrl);
        if (!redirectUri.isScheme('https') && !redirectUri.isScheme('http')) {
          throw Exception('OAuth redirect URL must use HTTP or HTTPS scheme');
        }

        // In production, enforce HTTPS
        if (isProduction && !redirectUri.isScheme('https')) {
          throw Exception('Production OAuth redirect URL MUST use HTTPS');
        }
      } catch (e) {
        throw Exception('Invalid OAuth redirect URL format: $e');
      }
    }

    if (isDevelopment) {
      print('✅ Configuration validation passed');
    }
  }

  static void logConfiguration() {
    if (isDevelopment) {
      print('🔧 App Configuration:');
      print(
          '  - Environment: $environment (${isDevelopment ? "Development" : "Production"})');
      print('  - FLUTTER_ENV: $_flutterEnv');
      print('  - Supabase URL: $supabaseUrl');
      print('  - Google Client ID: $googleClientId');
      print(
          '  - Google OAuth: ${isOAuthConfigValid ? "✅ Configured" : "❌ Missing"}');
      print('  - Platform: ${kIsWeb ? "Web" : "Mobile"}');
      if (kIsWeb) {
        print('  - Configured OAuth Redirect: $webOAuthRedirectUrl');
      }
      print('  - Auth Redirect URL: $authRedirectUrl');
      print('  - Package Name: $packageName');
    }
  }
}
