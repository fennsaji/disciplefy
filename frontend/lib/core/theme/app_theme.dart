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
            shape: const StadiumBorder(),
            minimumSize: const Size(120, 48),
            textStyle: _buttonLabel,
          ),
        ),
        filledButtonTheme: _filledButtonTheme,
        outlinedButtonTheme: _outlinedButtonTheme(isDark: false),
        textButtonTheme: _textButtonTheme(isDark: false),
        snackBarTheme: _snackBarTheme(isDark: false),
        dialogTheme: _dialogTheme(isDark: false),
        bottomSheetTheme: _bottomSheetTheme(isDark: false),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: BorderSide(color: AppColors.lightBorderStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: BorderSide(color: AppColors.lightBorderStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: BorderSide(color: AppColors.brandPrimary, width: 1.5),
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
          seedColor: AppColors.brandSecondary,
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
            shape: const StadiumBorder(),
            minimumSize: const Size(120, 48),
            backgroundColor: AppColors.brandSecondary,
            foregroundColor: AppColors.onGradient,
            textStyle: _buttonLabel,
          ),
        ),
        filledButtonTheme: _filledButtonTheme,
        outlinedButtonTheme: _outlinedButtonTheme(isDark: true),
        textButtonTheme: _textButtonTheme(isDark: true),
        snackBarTheme: _snackBarTheme(isDark: true),
        dialogTheme: _dialogTheme(isDark: true),
        bottomSheetTheme: _bottomSheetTheme(isDark: true),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: BorderSide(color: AppColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: BorderSide(color: AppColors.brandSecondary),
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

  // ── Shared component themes ──────────────────────────────────────────────
  //
  // Defaults for raw Material widgets that have not been rebuilt on the
  // redesigned popups/pills yet, so they sit close to the ReaderPalette look:
  // pill buttons, card-coloured dialogs and sheets, floating snackbars and
  // 14px inputs. Widgets that pass their own style still win.

  static const double _inputRadius = 14;

  static const TextStyle _buttonLabel = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static FilledButtonThemeData get _filledButtonTheme => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: _buttonLabel,
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme({required bool isDark}) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: _buttonLabel,
          foregroundColor:
              isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          side: BorderSide(
            color: isDark
                ? AppColors.onGradient.withValues(alpha: 0.14)
                : AppColors.lightTextPrimary.withValues(alpha: 0.14),
          ),
        ),
      );

  static TextButtonThemeData _textButtonTheme({required bool isDark}) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: _buttonLabel.copyWith(fontSize: 14),
          foregroundColor:
              isDark ? AppColors.brandPrimaryLight : AppColors.brandPrimary,
        ),
      );

  /// Matches [showAppSnackBar]: dark surface in both themes, Inter text,
  /// 16 radius. Floating snackbars are placed above the shell's dock by the
  /// root Scaffold, so the inset only needs the side gutter.
  static SnackBarThemeData _snackBarTheme({required bool isDark}) =>
      SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor:
            isDark ? AppColors.darkSurfaceVariant : AppColors.lightTextPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.35,
          color: AppColors.onGradient,
        ),
        actionTextColor: AppColors.brandGold,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark
              ? BorderSide(
                  color: AppColors.onGradient.withValues(alpha: 0.14),
                )
              : BorderSide.none,
        ),
      );

  static DialogThemeData _dialogTheme({required bool isDark}) =>
      DialogThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? AppColors.onGradient.withValues(alpha: 0.07)
                : AppColors.lightTextPrimary.withValues(alpha: 0.08),
          ),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 19,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color:
              isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14.5,
          height: 1.5,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      );

  static BottomSheetThemeData _bottomSheetTheme({required bool isDark}) =>
      BottomSheetThemeData(
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        modalBackgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: isDark
            ? AppColors.onGradient.withValues(alpha: 0.2)
            : AppColors.lightTextPrimary.withValues(alpha: 0.2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      );
}
