import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application theme following Disciplefy brand guidelines.
///
/// Based on Figma design specifications with colors, typography,
/// and component styling that reflects the spiritual nature of the app.
class AppTheme {
  // Disciplefy Brand Colors (Exact from Figma)
  static const Color primaryColor = Color(0xFF6A4FB6); // Spiritual Lavender
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
          error: errorColor,
          // Override specific colors to ensure proper contrast
          secondary: secondaryColor,
          onSecondary: textPrimary,
          surface: surfaceColor,
          onSurface: textPrimary,
          background: backgroundColor,
          onBackground: textPrimary,
        ),
        scaffoldBackgroundColor: backgroundColor,

        // Typography following Disciplefy brand guidelines
        textTheme: TextTheme(
          // Headings use Playfair Display
          displayLarge: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: primaryColor,
          ),
          displayMedium: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: primaryColor,
          ),
          headlineLarge: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: primaryColor,
          ),
          headlineMedium: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: primaryColor,
          ),

          // Titles use Inter for better readability
          titleLarge: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),

          // Body text uses Inter
          bodyLarge: GoogleFonts.inter(
            fontSize: 18,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 16,
            height: 1.5,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 14,
            height: 1.4,
          ),

          // Labels and buttons use Inter
          labelLarge: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          labelMedium: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          labelSmall: GoogleFonts.inter(
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
          // Improved dark theme colors for better UX
          primary: const Color(0xFF8B7AC7), // Lighter lavender for dark
          secondary: const Color(0xFF4A3B7A), // Darker purple for secondary
          surface: const Color(0xFF1A1A1A), // Dark gray instead of brown
          onSurface: const Color(0xFFE0E0E0), // Light gray text
          onSurfaceVariant:
              textSecondaryDark, // WCAG AA compliant secondary text
          background: const Color(0xFF121212), // True dark background
          onBackground:
              const Color(0xFFE0E0E0), // Light text on dark background
          onSecondary: const Color(0xFFE0E0E0), // Light text on secondary
          error: errorColor,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),

        // Typography with improved dark theme colors
        textTheme: TextTheme(
          // Headings use Playfair Display with light colors for dark theme
          displayLarge: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: const Color(0xFF8B7AC7), // Lighter primary for dark theme
          ),
          displayMedium: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: const Color(0xFF8B7AC7),
          ),
          headlineLarge: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: const Color(0xFF8B7AC7),
          ),
          headlineMedium: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: const Color(0xFF8B7AC7),
          ),

          // Titles use Inter for better readability in dark theme
          titleLarge: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: const Color(0xFFE0E0E0),
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: const Color(0xFFE0E0E0),
          ),

          // Body text uses Inter with proper dark theme colors
          bodyLarge: GoogleFonts.inter(
            fontSize: 18,
            height: 1.5,
            color: const Color(0xFFE0E0E0),
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 16,
            height: 1.5,
            color: const Color(0xFFE0E0E0),
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 14,
            height: 1.4,
            color: const Color(0xFFB0B0B0),
          ),

          // Labels and buttons use Inter with appropriate contrast
          labelLarge: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            color: const Color(0xFFE0E0E0),
          ),
          labelMedium: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: const Color(0xFFB0B0B0),
          ),
          labelSmall: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: const Color(0xFFB0B0B0),
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
            backgroundColor:
                const Color(0xFF8B7AC7), // Primary color for dark theme
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
            borderSide: const BorderSide(color: Color(0xFF8B7AC7)),
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
