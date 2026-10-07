import 'package:flutter/material.dart';
import 'contrast.dart';

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

  /// The design has no indigo or lavender. Primary actions are an ink pill on
  /// light and a white pill on dark ([ReaderPalette.ctaFill]); selected
  /// states, progress, links and accent icons are gold ([brandGold] on dark,
  /// [brandGoldDeep] / [brandHighlightDark] on light).

  /// Gold highlight — secondary brand color, highlights, verse containers.
  static const Color brandHighlight = Color(0xFFFFEEC0);

  /// Dark gold — for richer gradient pairs with [brandHighlight].
  static const Color brandHighlightDark = Color(0xFFD4A23A);

  /// Coral accent — action/alert, destructive-action confirmation.
  static const Color brandAccent = Color(0xFFFF6B6B);

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME PALETTE
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color lightBackground = Color(0xFFFAF8F5);
  static const Color lightScaffold = Color(0xFFFAF8F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEEBE3); // warm raised
  static const Color lightTextPrimary = Color(0xFF1A1917); // design ink
  /// Design secondary text — 5.0:1 on the page, 5.3:1 on white.
  static const Color lightTextSecondary = Color(0xFF6F6B61);

  /// Warm tertiary text. The design dim (#8A857A) is 3.5:1 on the page, so
  /// text keeps this darker warm value (4.9:1); #8A857A is icons only.
  static const Color lightTextTertiary = Color(0xFF716C64);
  static const Color lightBorder = Color(0xFFE6E3DD); // warm hairline
  static const Color lightBorderStrong = Color(0xFFD6D2CA); // warm outline
  static const Color lightDivider = Color(0xFFE6E3DD);
  static const Color lightInputFill = Color(0xFFFFFFFF);

  // Splash / loading screen background (light mode)
  // Brand black — the splash is gold-on-black in both themes, matching the
  // native launch screen so there is no colour flash on handover.
  /// Brand gold — the Disciplefy symbol. See brand/README.md.
  static const Color brandGold = Color(0xFFE3B154);

  /// Brand gold for light surfaces.
  ///
  /// #E3B154 is tuned for the near-black splash and dark theme; on the light
  /// page it measures 1.85:1 and simply disappears. This deeper gold keeps the
  /// hue but clears AA on both the page (4.5:1) and white cards (4.8:1),
  /// and white text on it as a fill measures 4.8:1.
  static const Color brandGoldDeep = Color(0xFF986910);

  /// Brand gold for icons, hairlines and washes on light surfaces.
  /// Same hue and saturation as the logo, darkened only until it clears the
  /// 3:1 graphics minimum on the page (3.02:1). [brandGoldDeep] has to go
  /// much darker to reach 4.5:1 for text and stops looking like the logo;
  /// this one still does. Never use it for text.
  static const Color brandGoldMark = Color(0xFFBC851F);

  /// Gold for labels on a gold-tinted pill on light surfaces. [brandGoldDeep]
  /// measures about 4:1 on its own 12–16% tint; this deeper gold keeps the
  /// hue and reads 5.9:1 on a 16% tint over the page (7.2:1 on the page).
  static const Color brandGoldInk = Color(0xFF704D0F);

  static const Color splashBackgroundLight = Color(0xFF0B0B0B);

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME PALETTE
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkScaffold = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF17171C); // design card
  static const Color darkSurfaceVariant = Color(0xFF1F1F27); // design raised
  static const Color darkTextPrimary = Color(0xFFF2F2F4); // design text
  static const Color darkTextSecondary = Color(0xFF9CA3AF); // design secondary
  /// Design icons / nav labels — 5.2:1 on the card.
  static const Color darkTextTertiary = Color(0xFF8A8A95);
  static const Color darkBorder = Color(0xFF34343C); // white 14% on the page
  static const Color darkBorderStrong = Color(0xFF45454E);
  static const Color darkDivider = Color(0xFF26262F);
  static const Color darkInputFill = Color(0xFF1F1F27);

  /// 4.5:1 on [darkInputFill] (was #808080, 3.6:1).
  static const Color darkHintText = Color(0xFF919191);

  // Splash / loading screen background (dark mode)
  static const Color splashBackgroundDark = Color(0xFF0B0B0B);

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS (theme-independent)
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color success = Color(0xFF10B981); // Emerald-500
  static const Color successLight = Color(0xFFD1FAE5); // Emerald-100
  static const Color successLighter =
      Color(0xFF34D399); // design success on dark surfaces
  /// Emerald-800 — light-theme success text and fills: 7.7:1 on white and
  /// 5.9:1 or more on its own 10–14% tint (Emerald-700 was 4.7–5.0:1 there).
  static const Color successDark = Color(0xFF065F46);

  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color errorLighter =
      Color(0xFFF87171); // design error on dark surfaces
  /// Red-800 — light-theme error text and fills: 8.3:1 on white, 6.6:1 on a
  /// 14% error tint over the page (Red-700 was 5.2:1 there).
  static const Color errorDark = Color(0xFF991B1B);

  static const Color warning = Color(0xFFF59E0B); // Amber-500
  static const Color warningLighter =
      Color(0xFFFCD34D); // Amber-300 — dark mode badge text
  /// Amber-800 — light-theme warning text: 7.1:1 on white, 6.0:1 on a 14%
  /// warning tint over the page (Amber-700 was 4.3:1 there).
  static const Color warningDark = Color(0xFF92400E);

  static const Color info =
      Color(0xFF3B82F6); // Blue-500 — 3.9:1 on white (icon/bg use)
  static const Color infoLighter =
      Color(0xFF93C5FD); // Blue-300 — dark mode badge text
  static const Color infoDark =
      Color(0xFF1D4ED8); // Blue-700 — 7.5:1 on white (text on light bg)

  // ═══════════════════════════════════════════════════════════════════════════
  // ON-GRADIENT
  // Colors for text / icons rendered ON a gradient or colored surface.
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color onGradient = Colors.white;

  /// Amber for warning marks sitting on a coloured gradient.
  /// Amber-200: the darker warning tokens are tuned for light/dark page
  /// grounds and drop to 3.10:1 on the gradient's light end, so the gradient
  /// gets its own value. Icons only — see [onGradient] for text.
  static const Color onGradientWarning = Color(0xFFFFE082);

  // ═══════════════════════════════════════════════════════════════════════════
  // SUBSCRIPTION TIER COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color tierStandard = brandGoldDeep; // design: plans are gold
  /// The recommended Plus plan is outlined in gold in the design, like the
  /// rest of the plan cards (deep gold on light surfaces).
  static const Color tierPlus = brandGoldDeep;

  /// [tierPlus] on dark surfaces: the bright gold.
  static const Color tierPlusOnDark = brandGold;

  // ═══════════════════════════════════════════════════════════════════════════
  // DIFFICULTY COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color difficultyEasy = Color(0xFF10B981); // = success
  static const Color difficultyMedium = Color(0xFFF59E0B); // = warning
  static const Color difficultyHard = Color(0xFFEF4444); // = error

  // ═══════════════════════════════════════════════════════════════════════════
  // MASTERY LEVEL COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color masteryExpert = Color(0xFFFF5722); // deepOrange

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
  // FEATURE-SPECIFIC COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  // Streaks & gamification — the brand-gold family.
  //
  // These were three unrelated warm colours (orange, deep orange, amber) which,
  // together with the Material amber used on the verse card, meant progress UI
  // spoke in four different accents and none of them matched the brand gold in
  // the logo. They now share one hue so streaks, XP and milestones read as a
  // single system and the gold mark in the header belongs to it.
  static const Color streakGlow = Color(0xFFC8922F); // deeper gold, for glows

  // ═══════════════════════════════════════════════════════════════════════════
  // OVERLAY / SHADOW / SCRIM
  // ═══════════════════════════════════════════════════════════════════════════

  static const Color scrim = Color(0x8A000000); // 54%

  // ═══════════════════════════════════════════════════════════════════════════
  // ADMIN-WEB READINESS
  // Stub for future API-driven theming. Expand to full fromJson when needed.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns a JSON-serializable map of all brand palette values.
  /// Useful for exporting the current theme to the admin dashboard.
  static Map<String, String> toJson() {
    return {
      'brandGold': _hex(brandGold),
      'brandGoldDeep': _hex(brandGoldDeep),
      'brandHighlight': _hex(brandHighlight),
      'brandHighlightDark': _hex(brandHighlightDark),
      'brandAccent': _hex(brandAccent),
      'success': _hex(success),
      'error': _hex(error),
      'warning': _hex(warning),
      'info': _hex(info),
      'tierStandard': _hex(tierStandard),
      'tierPlus': _hex(tierPlus),
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

  /// Brand gold, for the streak / XP / milestone family.
  ///
  /// Gold is the brand colour but appeared only in the header logo, so it read
  /// as a sticker rather than part of the system. Giving it one recurring job
  /// — progress and achievement — makes the logo belong, and replaces the
  /// Material `Colors.amber` that was standing in for it.
  ///
  Color get appStreakAccent =>
      _isDark ? AppColors.brandGold : AppColors.brandGoldDeep;

  /// Gold for non-text marks: icons, 1px rules, pill washes and borders.
  /// Closer to the logo than [appStreakAccent] on light, because graphics only
  /// need 3:1. Text must keep using [appStreakAccent].
  Color get appGoldMark =>
      _isDark ? AppColors.brandGold : AppColors.brandGoldMark;

  /// Semantic accents resolved for the current theme.
  ///
  /// The base tokens (success #10B981, warning #F59E0B) are fill colours.
  /// Used as text or icons they fail WCAG on one theme: warning is 2.2:1 on
  /// white and success 2.5:1 on white. The palette already carries the right
  /// variants for each theme — these pick them so call sites do not have to.
  Color get appSuccess =>
      _isDark ? AppColors.successLighter : AppColors.successDark;
  Color get appWarning =>
      _isDark ? AppColors.warningLighter : AppColors.warningDark;
  Color get appError => _isDark ? AppColors.errorLighter : AppColors.errorDark;
  Color get appInfo => _isDark ? AppColors.infoLighter : AppColors.infoDark;

  /// The design's accent for links, selected text and accent icons: gold.
  Color get appAccent =>
      _isDark ? AppColors.brandGold : AppColors.brandGoldDeep;

  /// Adjusts [accent] so it is readable as text on the current theme's
  /// surface.
  ///
  /// The brand and semantic accents are chosen as fills. Used directly as a
  /// text colour many of them fail WCAG AA on one theme or the other —
  /// success is 2.5:1 on white, warning 2.2:1. This keeps the hue and lifts it only as far as
  /// needed.
  ///
  /// Pass [minRatio] `kMinContrastLargeText` for icons and large headings.
  Color readable(Color accent, {double minRatio = kMinContrastNormalText}) =>
      ensureContrast(accent, appSurface, minRatio: minRatio);

  /// As [readable], but against the scaffold/background rather than a card.
  Color readableOnBackground(Color accent,
          {double minRatio = kMinContrastNormalText}) =>
      ensureContrast(accent, appBackground, minRatio: minRatio);

  /// Theme-aware primary brand color — adapts to light/dark mode automatically.
  Color get appPrimary => Theme.of(this).colorScheme.primary;

  /// Theme-aware primary brand color with opacity.
  Color appPrimaryWith(double opacity) =>
      Theme.of(this).colorScheme.primary.withValues(alpha: opacity);
}
