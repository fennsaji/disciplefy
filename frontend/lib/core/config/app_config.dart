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

  // OAuth Redirect URLs
  static String get authRedirectUrl {
    if (kIsWeb) {
      // DYNAMIC FIX: Use current origin for OAuth redirects to handle localhost correctly
      final currentOrigin = _getCurrentWebOrigin();
      return '$currentOrigin/auth/callback';
    }
    // Use deep link scheme for mobile apps (both development and production)
    return 'com.disciplefy.bible_study_app://auth/callback';
  }

  /// Get the current web origin dynamically
  /// This ensures OAuth redirects work correctly in both development and production
  /// Uses Uri.base which is safe and doesn't rely on deprecated dart:html
  static String _getCurrentWebOrigin() {
    if (kIsWeb) {
      try {
        // Use Uri.base to get the current origin - this is the modern, safe approach
        final baseUri = Uri.base;
        final origin =
            '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';

        if (isDevelopment) {
          print('🔧 [AppConfig] Dynamic web origin detected: $origin');
        }
        return origin;
      } catch (e) {
        if (isDevelopment) {
          print(
              '🔧 [AppConfig] ⚠️ Failed to get dynamic origin, falling back to appUrl: $e');
        }
      }

      // Fallback to configured appUrl if dynamic detection fails
      if (isDevelopment) {
        print('🔧 [AppConfig] Using fallback appUrl: $appUrl');
      }
      return appUrl;
    }
    return appUrl;
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

    if (missingConfigs.isNotEmpty) {
      throw Exception(
          'Missing required environment variables: ${missingConfigs.join(', ')}. '
          'Please set these environment variables before running the application.');
    }

    // Validate format of critical URLs
    if (!supabaseUrl.startsWith('http')) {
      throw Exception('SUPABASE_URL must be a valid HTTP/HTTPS URL');
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
        print('  - Current Origin (Dynamic): ${_getCurrentWebOrigin()}');
        print('  - Static App URL: $appUrl');
      }
      print('  - Auth Redirect URL (Dynamic): $authRedirectUrl');
      print('  - Package Name: $packageName');
    }
  }
}
