import 'package:flutter/material.dart';
import 'app_colors.dart';
// Note: Using bundled fonts directly from pubspec.yaml instead of GoogleFonts
// to avoid AssetManifest.json issues when allowRuntimeFetching = false

/// Application theme following Disciplefy brand guidelines.
///
/// All color values are sourced exclusively from [AppColors].
/// To change a color, edit [AppColors] — never add inline hex values here.
class AppTheme {
  // ── Legacy aliases (kept for backward compatibility during migration) ──────
  // New code should reference AppColors directly.
  static const Color primaryColor = AppColors.brandPrimary;
  static const Color primaryLightColor = AppColors.brandPrimaryLight;
  static const Color secondaryPurple = AppColors.brandSecondary;
  static const Color secondaryColor = AppColors.brandHighlight;
  static const Color accentColor = AppColors.brandAccent;
  static const Color backgroundColor = AppColors.lightBackground;
  static const Color textPrimary = AppColors.lightTextPrimary;
  static const Color errorColor = AppColors.error;
  static const Color warningColor = AppColors.warning;
  static const Color successColor = AppColors.success;
  static const Color surfaceColor = AppColors.lightSurface;
  static const Color onSurfaceVariant = AppColors.lightTextSecondary;
  static const Color highlightColor = AppColors.brandHighlight;
  static const Color textSecondary = AppColors.lightTextSecondary;
  static const Color textSecondaryDark = AppColors.darkTextSecondary;
  static const Color usageHistoryColor = Color(0xFF14B8A6); // Teal-500

  /// Primary gradient — references AppColors so it stays in sync.
  static LinearGradient get primaryGradient => AppColors.primaryGradient;

  // ── Light Theme ──────────────────────────────────────────────────────────

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandPrimary,
          primary: AppColors.brandPrimary,
          onPrimary: AppColors.onGradient,
          error: AppColors.error,
          secondary: AppColors.brandHighlight,
          onSecondary: AppColors.lightTextPrimary,
          tertiary: AppColors.brandSecondary,
          onTertiary: AppColors.onGradient,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          onSurfaceVariant: AppColors.lightTextSecondary,
        ),
        scaffoldBackgroundColor: AppColors.lightScaffold,
        textTheme: TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: AppColors.brandPrimary,
          ),
          displayMedium: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: AppColors.brandPrimary,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppColors.brandPrimary,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppColors.brandPrimary,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          titleMedium: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            height: 1.5,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            height: 1.5,
          ),
          bodySmall: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.4,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          labelMedium: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
          labelSmall: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
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
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: false,
          titleSpacing: NavigationToolbar.kMiddleSpacing,
          backgroundColor: AppColors.lightSurface,
          foregroundColor: AppColors.lightTextPrimary,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextPrimary,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );

  // ── Dark Theme ───────────────────────────────────────────────────────────

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandPrimary,
          brightness: Brightness.dark,
          primary: AppColors
              .brandPrimaryLight, // #A78BFA — 6.5:1 on dark (was #6A4FB6, 2.7:1)
          onPrimary: AppColors.onGradient,
          secondary: AppColors.brandHighlight,
          onSecondary: AppColors.lightTextPrimary,
          tertiary: AppColors
              .brandPrimaryLight, // lighter purple for gradient pairs in dark
          onTertiary: AppColors.onGradient,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          onSurfaceVariant: AppColors.darkTextSecondary,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.darkScaffold,
        textTheme: TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: AppColors.brandPrimaryLight,
          ),
          displayMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
            color: AppColors.brandPrimaryLight,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppColors.brandPrimaryLight,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppColors.brandPrimaryLight,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: AppColors.darkTextPrimary,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: AppColors.darkTextPrimary,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            height: 1.5,
            color: AppColors.darkTextPrimary,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            height: 1.5,
            color: AppColors.darkTextPrimary,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.4,
            color: AppColors.darkTextSecondary,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            color: AppColors.darkTextPrimary,
          ),
          labelMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: AppColors.darkTextSecondary,
          ),
          labelSmall: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: AppColors.darkTextSecondary,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(120, 48),
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.onGradient,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.brandPrimary),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          fillColor: AppColors.darkInputFill,
          filled: true,
          labelStyle: TextStyle(color: AppColors.darkTextSecondary),
          hintStyle: TextStyle(color: AppColors.darkHintText),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: false,
          titleSpacing: NavigationToolbar.kMiddleSpacing,
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkTextPrimary,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextPrimary,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}
