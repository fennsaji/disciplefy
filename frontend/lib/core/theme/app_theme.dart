import 'package:flutter/material.dart';
// Note: Using bundled fonts directly from pubspec.yaml instead of GoogleFonts
// to avoid AssetManifest.json issues when allowRuntimeFetching = false

/// Application theme following Disciplefy brand guidelines.
///
/// Based on Figma design specifications with colors, typography,
/// and component styling that reflects the spiritual nature of the app.
///
/// Primary color (#4F46E5) meets WCAG AA contrast ratio (4.63:1) against white.
/// Verified at: https://webaim.org/resources/contrastchecker/
class AppTheme {
  // Disciplefy Brand Colors
  static const Color primaryColor = Color(0xFF4F46E5); // Indigo-600 (WCAG AA)
  static const Color secondaryPurple =
      Color(0xFF8B5CF6); // Violet-500 (for gradients)

  /// Primary gradient for UI elements (Purple → Indigo)
  /// Use this for consistent gradient styling across the app
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Color secondaryColor = Color(0xFFFFEFC0); // Golden Glow
  static const Color accentColor = Color(0xFFFF6B6B); // Action/Alert
  static const Color backgroundColor = Color(0xFFFFFFFF); // Background
  static const Color textPrimary = Color(0xFF1E1E1E); // Text Primary

  // Supporting Colors
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color successColor = Color(0xFF10B981); // Emerald
  static const Color surfaceColor = Color(0xFFFFFFFF); // White
  static const Color onSurfaceVariant = Color(0xFF6B7280); // Gray text

  // Additional theme properties that widgets expect
  static const Color highlightColor =
      secondaryColor; // Golden Glow for highlights
  static const Color textSecondary =
      Color(0xFF6B7280); // Secondary text color (light theme)
  static const Color textSecondaryDark = Color(
      0xFFB0B0B0); // Secondary text color (dark theme - WCAG AA compliant)

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor, // Indigo-600 (#4F46E5) - WCAG AA compliant
          onPrimary: Colors.white,
          error: errorColor,
          // Override specific colors to ensure proper contrast
          secondary: secondaryColor,
          onSecondary: textPrimary,
          tertiary: secondaryPurple, // Violet-500 for gradients (#8B5CF6)
          onTertiary: Colors.white, // White text on violet tertiary
          surface: surfaceColor,
          onSurface: textPrimary,
          background: backgroundColor,
          onBackground: textPrimary,
        ),
        scaffoldBackgroundColor: backgroundColor,

        // Typography following Disciplefy brand guidelines
        // Using bundled fonts from pubspec.yaml (Inter, Poppins)
        textTheme: const TextTheme(
          // Headings use Poppins
          displayLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: primaryColor,
          ),
          displayMedium: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: primaryColor,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: primaryColor,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: primaryColor,
          ),

          // Titles use Inter for better readability
          titleLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),

          // Body text uses Inter
          bodyLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            height: 1.5,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.4,
          ),

          // Labels and buttons use Inter
          labelLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          labelMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          labelSmall: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),

        // Component themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(120, 48),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),

        // Card theme handled individually in widgets

        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
          // Improved dark theme colors
          primary: primaryColor, // Indigo-600 (#4F46E5) - WCAG AA compliant
          onPrimary: Colors.white,
          secondary:
              secondaryColor, // Golden Glow (consistent with light theme)
          tertiary: secondaryPurple, // Violet-500 for gradients (#8B5CF6)
          surface: const Color(0xFF1A1A1A), // Dark gray instead of brown
          onSurface: const Color(0xFFE0E0E0), // Light gray text
          onSurfaceVariant:
              textSecondaryDark, // WCAG AA compliant secondary text
          background: const Color(0xFF121212), // True dark background
          onBackground:
              const Color(0xFFE0E0E0), // Light text on dark background
          onSecondary: textPrimary, // Dark text on golden secondary
          onTertiary: Colors.white, // White text on indigo tertiary
          error: errorColor,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),

        // Typography with improved dark theme colors
        // Using bundled fonts from pubspec.yaml (Inter, Poppins)
        textTheme: const TextTheme(
          // Headings use Inter with vibrant purple for dark theme
          displayLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: primaryColor, // Vibrant Purple (#7C3AED)
          ),
          displayMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: primaryColor,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: primaryColor,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: primaryColor,
          ),

          // Titles use Inter for better readability in dark theme
          titleLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: Color(0xFFE0E0E0),
          ),
          titleMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: Color(0xFFE0E0E0),
          ),

          // Body text uses Inter with proper dark theme colors
          bodyLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            height: 1.5,
            color: Color(0xFFE0E0E0),
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            height: 1.5,
            color: Color(0xFFE0E0E0),
          ),
          bodySmall: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.4,
            color: Color(0xFFB0B0B0),
          ),

          // Labels and buttons use Inter with appropriate contrast
          labelLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            color: Color(0xFFE0E0E0),
          ),
          labelMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: Color(0xFFB0B0B0),
          ),
          labelSmall: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: Color(0xFFB0B0B0),
          ),
        ),

        // Component themes with dark theme adjustments
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(120, 48),
            backgroundColor: primaryColor, // Vibrant Purple (#7C3AED)
            foregroundColor: Colors.white,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF404040)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF404040)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryColor),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          fillColor: const Color(0xFF2A2A2A),
          filled: true,
          labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
          hintStyle: const TextStyle(color: Color(0xFF808080)),
        ),

        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Color(0xFFE0E0E0),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE0E0E0),
          ),
        ),
      );
}
