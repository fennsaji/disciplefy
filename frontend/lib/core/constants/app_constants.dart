/// Application-wide constants for the Disciplefy Bible Study app.
///
/// This file contains all magic numbers, strings, and configuration
/// values used throughout the application.
class AppConstants {
  AppConstants._();

  // API Configuration
  static const int API_TIMEOUT_SECONDS = 30;
  static const int MAX_RETRY_ATTEMPTS = 3;
  static const int RETRY_DELAY_SECONDS = 2;

  // Rate Limiting
  static const int ANONYMOUS_RATE_LIMIT_PER_HOUR = 3;
  static const int AUTHENTICATED_RATE_LIMIT_PER_HOUR = 30;
  static const int RATE_LIMIT_WINDOW_MINUTES = 60;

  // Study Guide Configuration
  static const int MAX_VERSE_LENGTH = 500;
  static const int MAX_TOPIC_LENGTH = 100;
  static const int MIN_INPUT_LENGTH = 3;
  static const int MAX_STUDY_GUIDES_CACHE = 10;

  // UI Configuration
  static const double DEFAULT_PADDING = 16.0;
  static const double LARGE_PADDING = 24.0;
  static const double SMALL_PADDING = 8.0;
  static const double EXTRA_SMALL_PADDING = 4.0;
  static const double EXTRA_LARGE_PADDING = 32.0;
  static const double CARD_PADDING = 20.0;
  static const double BUTTON_PADDING = 10.0;
  static const double HORIZONTAL_MARGIN = 20.0;
  static const double BORDER_RADIUS = 12.0;
  static const double LARGE_BORDER_RADIUS = 16.0;
  static const double SMALL_BORDER_RADIUS = 4.0;
  static const double CARD_ELEVATION = 2.0;

  // Spacing Configuration
  static const double SPACING_4 = 4.0;
  static const double SPACING_6 = 6.0;
  static const double SPACING_8 = 8.0;
  static const double SPACING_10 = 10.0;
  static const double SPACING_12 = 12.0;
  static const double SPACING_16 = 16.0;
  static const double SPACING_18 = 18.0;
  static const double SPACING_20 = 20.0;

  // Typography Configuration
  static const double FONT_SIZE_12 = 12.0;
  static const double FONT_SIZE_14 = 14.0;
  static const double FONT_SIZE_16 = 16.0;
  static const double FONT_SIZE_18 = 18.0;
  static const double FONT_SIZE_20 = 20.0;
  static const double FONT_SIZE_24 = 24.0;
  static const double FONT_SIZE_28 = 28.0;
  static const double FONT_SIZE_32 = 32.0;

  // Line Heights
  static const double LINE_HEIGHT_1_2 = 1.2;
  static const double LINE_HEIGHT_1_4 = 1.4;
  static const double LINE_HEIGHT_1_6 = 1.6;
  static const double LINE_HEIGHT_1_7 = 1.7;

  // Icon Sizes
  static const double ICON_SIZE_16 = 16.0;
  static const double ICON_SIZE_20 = 20.0;
  static const double ICON_SIZE_24 = 24.0;
  static const double ICON_SIZE_40 = 40.0;
  static const double ICON_SIZE_80 = 80.0;

  // Border Widths
  static const double BORDER_WIDTH_THIN = 1.0;
  static const double BORDER_WIDTH_MEDIUM = 1.5;
  static const double BORDER_WIDTH_THICK = 2.0;

  // Animation Durations
  static const int DEFAULT_ANIMATION_DURATION_MS = 300;
  static const int LOADING_ANIMATION_DURATION_MS = 1000;
  static const int PAGE_TRANSITION_DURATION_MS = 250;

  // Storage Keys
  static const String ONBOARDING_COMPLETED_KEY = 'onboarding_completed';
  static const String SELECTED_LANGUAGE_KEY = 'selected_language';
  static const String SELECTED_THEME_KEY = 'selected_theme';
  static const String USER_PREFERENCES_KEY = 'user_preferences';
  static const String CACHED_STUDIES_KEY = 'cached_studies';

  // Default Values
  static const String DEFAULT_LANGUAGE = 'en';
  static const String DEFAULT_BIBLE_VERSION = 'ESV';
  static const String DEFAULT_DIFFICULTY_LEVEL = 'intermediate';

  // Error Messages
  static const String NETWORK_ERROR_MESSAGE = 'No internet connection available';
  static const String SERVER_ERROR_MESSAGE = 'Server error occurred';
  static const String VALIDATION_ERROR_MESSAGE = 'Please check your input';
  static const String UNKNOWN_ERROR_MESSAGE = 'An unexpected error occurred';

  // Success Messages
  static const String STUDY_GENERATED_MESSAGE = 'Study guide generated successfully';
  static const String SETTINGS_SAVED_MESSAGE = 'Settings saved successfully';

  // Navigation
  static const String HOME_ROUTE = '/';
  static const String ONBOARDING_ROUTE = '/onboarding';
  static const String STUDY_RESULT_ROUTE = '/study-result';
  static const String ERROR_ROUTE = '/error';

  // Feature Flags
  static const bool ENABLE_ANALYTICS = true;
  static const bool ENABLE_CRASH_REPORTING = true;
  static const bool ENABLE_OFFLINE_MODE = true;
  static const bool ENABLE_DARK_THEME = true;

  // Jeff Reed Methodology
  static const List<String> JEFF_REED_STEPS = ['Observation', 'Interpretation', 'Application', 'Prayer'];

  static const int JEFF_REED_TOTAL_STEPS = 4;

  // Study Guide Sections
  static const List<String> STUDY_GUIDE_SECTIONS = [
    'Summary',
    'Context',
    'Related Verses',
    'Reflection Questions',
    'Prayer Points'
  ];

  static const int STUDY_GUIDE_TOTAL_SECTIONS = 5;
}
