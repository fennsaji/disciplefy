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
  static const Color backgroundColor = Color(0xFFF9F8F3); // Background
  static const Color textPrimary = Color(0xFF1E1E1E); // Text Primary

  // Supporting Colors
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color successColor = Color(0xFF10B981); // Emerald
  static const Color surfaceColor = Color(0xFFFFFFFF); // White
  static const Color onSurfaceVariant = Color(0xFF6B7280); // Gray text

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
        ),

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
            fontSize: 16,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
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
          error: errorColor,
          // Override specific colors to ensure proper contrast in dark mode
          secondary: secondaryColor,
          onSecondary: textPrimary,
          surface: const Color.fromARGB(255, 73, 71, 54),
          onSurface: Colors.white,
        ),

        // Text theme with proper dark mode colors
        textTheme: lightTheme.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        elevatedButtonTheme: lightTheme.elevatedButtonTheme,
        inputDecorationTheme: lightTheme.inputDecorationTheme,
        cardTheme: lightTheme.cardTheme,
        appBarTheme: lightTheme.appBarTheme,
      );
}
