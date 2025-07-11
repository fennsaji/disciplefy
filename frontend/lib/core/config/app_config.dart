import 'package:flutter/foundation.dart';

/// Application configuration based on environment
/// References: Technical Architecture Document, Security Design Plan
class AppConfig {
  // Supabase Configuration (Primary Backend)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: kDebugMode 
      ? 'http://127.0.0.1:54321'
      : 'https://wzdcwxvyjuxjgzpnukvm.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: kDebugMode 
      ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
      : 'your-prod-anon-key',
  );
  
  // OAuth Configuration
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: kIsWeb 
      ? '587108000155-af542dhgo9rmp5hvsm1vepgqsgil438d.apps.googleusercontent.com'
      : '', // Android gets this from google-services.json, iOS uses separate client ID
  );
  
  static const String appleClientId = String.fromEnvironment(
    'APPLE_CLIENT_ID', 
    defaultValue: 'com.disciplefy.bible_study',
  );

  // Payment Configuration (Razorpay)
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: kDebugMode ? 'rzp_test_key' : 'rzp_live_key',
  );
  
  // App Configuration
  static const String appVersion = '1.0.0';
  static const String apiVersion = 'v1';
  static const String packageName = 'com.disciplefy.bible_study';
  
  // OAuth Redirect URLs
  static String get authRedirectUrl {
    if (kIsWeb) {
      // Use localhost callback for development, Supabase callback for production
      if (isDevelopment) {
        return 'http://localhost:59641/auth/callback';
      }
      return '$supabaseUrl/auth/v1/callback';
    }
    // Use deep link scheme for mobile apps (both development and production)
    return 'com.disciplefy.bible_study_app://auth/callback';
  }
  
  // Rate Limiting (from API Contract Documentation)
  static const int anonymousRateLimit = 3; // guides per hour
  static const int authenticatedRateLimit = 30; // guides per hour
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
  
  // Environment Detection
  static bool get isProduction => !kDebugMode;
  static bool get isDevelopment => kDebugMode;
  
  // Feature Flags
  static bool get enableOfflineMode => true;
  static bool get enableAnalytics => isProduction;
  static bool get enableCrashReporting => isProduction;
  static bool get enablePerformanceMonitoring => true;
  
  // API Base URLs
  static String get baseApiUrl => '$supabaseUrl/functions/v1';
  static String get studyGenerationUrl => '$baseApiUrl/study/generate';
  static String get jeffReedTopicsUrl => '$baseApiUrl/topics/jeffreed';
  static String get feedbackUrl => '$baseApiUrl/feedback';
  static String get donationsUrl => '$baseApiUrl/donations';
  
  // Validation
  static bool get isConfigValid => supabaseUrl.isNotEmpty &&
           supabaseAnonKey.isNotEmpty;
  
  static bool get isOAuthConfigValid {
    return (kIsWeb && googleClientId.isNotEmpty) || 
           (!kIsWeb); // Mobile gets config from platform-specific files
  }
  
  static void validateConfiguration() {
    if (!isConfigValid) {
      throw Exception(
        'Invalid configuration: Missing required environment variables. '
        'Check SUPABASE_URL and SUPABASE_ANON_KEY.'
      );
    }
  }
  
  static void logConfiguration() {
    if (kDebugMode) {
      print('🔧 App Configuration:');
      print('  - Environment: ${isDevelopment ? "Development" : "Production"}');
      print('  - Supabase URL: $supabaseUrl');
      print('  - Google OAuth: ${isOAuthConfigValid ? "✅ Configured" : "❌ Missing"}');
      print('  - Platform: ${kIsWeb ? "Web" : "Mobile"}');
      print('  - Redirect URL: $authRedirectUrl');
      print('  - Package Name: $packageName');
    }
  }
}