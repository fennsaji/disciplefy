import 'package:flutter/material.dart';

/// Centralized color system for the Disciplefy app.
///
/// **Single source of truth** — every color in the app must originate here.
/// Changing a value in this file propagates to the entire app.
///
/// ## Structure
/// - Brand palette: core brand colors (change for a full rebrand)
/// - Light / Dark palettes: theme-specific backgrounds, surfaces, text, borders
/// - Semantic tokens: success, error, warning, info
/// - Feature colors: tier badges, difficulty, mastery, categories, medals, etc.
///
/// ## Admin-web readiness
/// All values are plain `Color` constants. To later allow admin-driven theming,
/// replace static constants with instance fields on a `ValueNotifier<AppColors>`
/// loaded from the API via [AppColors.fromJson]. The [toJson] stub is already
/// provided.
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════════
  // BRAND PALETTE
  // Change these values for a full app rebrand.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Main brand indigo — used for primary buttons, active tabs, highlights.
  /// Indigo-600: 5.7:1 on white (WCAG AA), more vibrant than previous purple.
  static const Color brandPrimary = Color(0xFF4F46E5);

  /// Lighter brand indigo — for dark-mode primary & hover/focus states.
  /// Indigo-300: 8.1:1 on dark surfaces (WCAG AAA).
  static const Color brandPrimaryLight = Color(0xFFA5B4FC);

  /// Gradient end indigo — used with [brandPrimary] in gradient pairs.
  /// Indigo-500: slightly lighter, creates a vibrant blue-indigo gradient.
  static const Color brandSecondary = Color(0xFF6366F1);

  /// Deep indigo — for high-contrast / pressed states.
  static const Color brandPrimaryDeep = Color(0xFF4338CA);

  /// Gold highlight — secondary brand color, highlights, verse containers.
  static const Color brandHighlight = Color(0xFFFFEEC0);

  /// Dark gold — for richer gradient pairs with [brandHighlight].
  static const Color brandHighlightDark = Color(0xFFB8860B);

  /// Coral accent — action/alert, destructive-action confirmation.
  static const Color brandAccent = Color(0xFFFF6B6B);

  /// Warm white — background for content cards (e.g. voice bubbles).
  static const Color warmWhite = Color(0xFFFAF8F5);

  /// Primary gradient (top-left → bottom-right).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [brandPrimary, brandSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME PALETTE
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color lightBackground = Color(0xFFFAF8F5);
  static const Color lightScaffold = Color(0xFFFAF8F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF3F0FF); // lavender tint
  static const Color lightTextPrimary = Color(0xFF1E1E1E);
  static const Color lightTextSecondary =
      Color(0xFF4B5563); // Gray-600 — 7.4:1 on white (was #6B7280, 4.6:1)
  static const Color lightTextTertiary =
      Color(0xFF6B7280); // Gray-500 — 4.6:1 on white (was #9CA3AF, 2.3:1)
  static const Color lightBorder = Color(0xFFE5E7EB); // Gray-200
  static const Color lightBorderStrong = Color(0xFFD1D5DB); // Gray-300
  static const Color lightDivider = Color(0xFFE5E7EB);
  static const Color lightInputFill = Color(0xFFFFFFFF);

  // Splash / loading screen background (light mode)
  static const Color splashBackgroundLight = Color(0xFFFBEDD9);

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME PALETTE
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkScaffold = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceVariant = Color(0xFF1E1E2E); // dark purple tint
  static const Color darkSurfaceElevated = Color(0xFF1F2937); // Gray-800 equiv
  static const Color darkSurfaceHigh = Color(0xFF2A2A2A);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextTertiary = Color(
      0xFF9CA3AF); // Gray-400 — 6.4:1 on dark surface (was #808080, 4.2:1)
  static const Color darkBorder = Color(0xFF404040);
  static const Color darkBorderStrong = Color(0xFF555555);
  static const Color darkDivider = Color(0xFF2A2A2A);
  static const Color darkInputFill = Color(0xFF2A2A2A);
  static const Color darkInputBorder = Color(0xFF404040);
  static const Color darkHintText = Color(0xFF808080);

  // Splash / loading screen background (dark mode)
  static const Color splashBackgroundDark = Color(0xFF0F1012);

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS (theme-independent)
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color success = Color(0xFF10B981); // Emerald-500
  static const Color successLight = Color(0xFFD1FAE5); // Emerald-100
  static const Color successDark =
      Color(0xFF047857); // Emerald-700 — 5.0:1 on white (was #059669, 3.4:1)

  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color errorLight = Color(0xFFFEE2E2); // Red-100
  static const Color errorDark =
      Color(0xFFB91C1C); // Red-700 — 6.6:1 on white (was #DC2626, 4.7:1)

  static const Color warning = Color(0xFFF59E0B); // Amber-500
  static const Color warningLight = Color(0xFFFEF3C7); // Amber-100
  static const Color warningDark =
      Color(0xFFB45309); // Amber-700 — 4.8:1 on white (was #D97706, 3.1:1)

  static const Color info =
      Color(0xFF3B82F6); // Blue-500 — 3.9:1 on white (icon/bg use)
  static const Color infoLight = Color(0xFFDBEAFE); // Blue-100
  static const Color infoDark =
      Color(0xFF1D4ED8); // Blue-700 — 7.5:1 on white (text on light bg)

  // ═══════════════════════════════════════════════════════════════════════════
  // ON-GRADIENT
  // Colors for text / icons rendered ON a gradient or colored surface.
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color onGradient = Colors.white;
  static const Color onGradientMuted = Color(0xCCFFFFFF); // white 80%
  static const Color onGradientSubtle = Color(0x99FFFFFF); // white 60%
  static const Color onGradientFaint = Color(0x66FFFFFF); // white 40%

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBSCRIPTION TIER COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color tierFree = Color(0xFF6B7280); // Gray-500
  static const Color tierStandard = brandPrimary; // matches brand indigo
  static const Color tierPlus = Color(0xFF7C3AED); // Violet-600
  static const Color tierPremium = Color(0xFF7C4DFF); // Violet-500
  static const Color tierGold = Color(0xFFF59E0B); // Amber = warning

  // Light tint backgrounds for tier badges (use with BorderRadius cards)
  static const Color tierStandardTint = Color(0xFFF3E8FF);
  static const Color tierStandardBorder = Color(0xFFD8B4FE);

  // ═══════════════════════════════════════════════════════════════════════════
  // DIFFICULTY COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color difficultyEasy = Color(0xFF10B981); // = success
  static const Color difficultyMedium = Color(0xFFF59E0B); // = warning
  static const Color difficultyHard = Color(0xFFEF4444); // = error

  // ═══════════════════════════════════════════════════════════════════════════
  // MASTERY LEVEL COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color masteryBeginner = Color(0xFF10B981); // green
  static const Color masteryIntermediate = Color(0xFF3B82F6); // blue
  static const Color masteryAdvanced = Color(0xFF8B5CF6); // purple
  static const Color masteryExpert = Color(0xFFFF5722); // deepOrange
  static const Color masteryMaster = Color(0xFFF59E0B); // amber

  // ═══════════════════════════════════════════════════════════════════════════
  // CATEGORY COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color categoryApologetics = Color(0xFF1565C0);
  static const Color categoryChristianLife = Color(0xFF2E7D32);
  static const Color categoryChurch = Color(0xFFE65100);
  static const Color categoryDiscipleship = Color(0xFF7B1FA2);
  static const Color categoryFamily = Color(0xFFD32F2F);
  static const Color categoryFoundations = Color(0xFF5D4037);
  static const Color categoryMission = Color(0xFF455A64);
  static const Color categorySpiritualDisciplines = Color(0xFF00695C);

  // ═══════════════════════════════════════════════════════════════════════════
  // MEDAL / ACHIEVEMENT COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color medalGold = Color(0xFFFFD700);
  static const Color medalSilver = Color(0xFFC0C0C0);
  static const Color medalBronze = Color(0xFFCD7F32);

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE-SPECIFIC COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  // Streaks & gamification
  static const Color streakFlame = Color(0xFFFF9800); // orange
  static const Color streakGlow = Color(0xFFFF5722); // deepOrange
  static const Color xpGold = Color(0xFFFFC107); // amber

  // Voice & audio
  static const Color voiceBlue = Color(0xFF2196F3);
  static const Color voiceBluePastel = Color(0xFF64B5F6);
  static const Color voiceBlueLight = Color(0xFF90CAF9);
  static const Color voiceBlueSurface = Color(0xFFE3F2FD);

  // Memory verse heat map (GitHub-style intensity)
  static const Color heatMapLow = Color(0xFF9BE9A8);
  static const Color heatMapMid = Color(0xFF40C463);
  static const Color heatMapHigh = Color(0xFF30A14E);

  // PDF / print preview
  static const Color pdfBackground = Color(0xFFFAFAFA);
  static const Color pdfTextPrimary = Color(0xFF333333);
  static const Color pdfTextSecondary = Color(0xFF888888);

  // ═══════════════════════════════════════════════════════════════════════════
  // OVERLAY / SHADOW / SCRIM
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color shadowLight = Color(0x0F000000); // 6%
  static const Color shadowMedium = Color(0x1A000000); // 10%
  static const Color overlayLight = Color(0x1A000000); // 10%
  static const Color overlayDark = Color(0xBF000000); // 75%
  static const Color scrim = Color(0x8A000000); // 54%

  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY ALIASES (keep until all call-sites are migrated)
  // ═══════════════════════════════════════════════════════════════════════════

  /// @deprecated Use [brandPrimary]
  static Color get primary => brandPrimary;

  /// @deprecated Use [brandHighlight]
  static Color get secondary => brandHighlight;

  /// @deprecated Use [brandPrimary]
  static Color get primaryPurple => brandPrimary;

  /// @deprecated Use [brandHighlight]
  static Color get highlightGold => brandHighlight;

  /// @deprecated Use [lightTextPrimary]
  static Color get textPrimary => lightTextPrimary;

  /// @deprecated Use [lightTextSecondary]
  static Color get textSecondary => lightTextSecondary;

  /// @deprecated Use [lightBorder]
  static Color get divider => lightBorder;

  /// @deprecated Use [lightTextTertiary]
  static Color get disabled => lightTextTertiary;

  /// @deprecated Use [success]
  static Color get successGreen => success;

  /// @deprecated Use [error]
  static Color get errorRed => error;

  // ═══════════════════════════════════════════════════════════════════════════
  // ADMIN-WEB READINESS
  // Stub for future API-driven theming. Expand to full fromJson when needed.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns a JSON-serializable map of all brand palette values.
  /// Useful for exporting the current theme to the admin dashboard.
  static Map<String, String> toJson() {
    return {
      'brandPrimary': _hex(brandPrimary),
      'brandPrimaryLight': _hex(brandPrimaryLight),
      'brandSecondary': _hex(brandSecondary),
      'brandHighlight': _hex(brandHighlight),
      'brandHighlightDark': _hex(brandHighlightDark),
      'brandAccent': _hex(brandAccent),
      'success': _hex(success),
      'error': _hex(error),
      'warning': _hex(warning),
      'info': _hex(info),
      'tierStandard': _hex(tierStandard),
      'tierPlus': _hex(tierPlus),
      'tierPremium': _hex(tierPremium),
    };
  }

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}

/// Convenience extension for resolving light/dark color variants
/// based on the current [BuildContext] theme brightness.
extension AppColorsTheme on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get appBackground =>
      _isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get appScaffold =>
      _isDark ? AppColors.darkScaffold : AppColors.lightScaffold;
  Color get appSurface =>
      _isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get appSurfaceVariant =>
      _isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
  Color get appTextPrimary =>
      _isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get appTextSecondary =>
      _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get appTextTertiary =>
      _isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
  Color get appBorder => _isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get appDivider =>
      _isDark ? AppColors.darkDivider : AppColors.lightDivider;
  Color get appInputFill =>
      _isDark ? AppColors.darkInputFill : AppColors.lightInputFill;
}
