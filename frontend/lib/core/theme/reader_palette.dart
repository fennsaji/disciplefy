import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';

/// Colours of the editorial "reader" surfaces (study guide, its follow-up
/// chat and end-of-guide blocks) in the V2 Scripture-hero design.
///
/// One place for the handful of values the design uses beyond [AppColors],
/// resolved per theme so call sites never branch on brightness themselves.
@immutable
class ReaderPalette {
  final bool isDark;

  /// Page background: the theme scaffold, which the hero photo fades into.
  final Color page;

  /// Input/card fill (#17171C dark, white light).
  final Color card;

  /// Raised fill for chips, shimmer lines and the notes field.
  final Color raised;

  /// 1px separators between sections.
  final Color hairline;

  /// Outline for pills and inputs — a notch stronger than [hairline].
  final Color outline;

  final Color text;
  final Color muted;
  final Color dim;

  /// Accent for icons (lavender on dark, indigo on light).
  final Color accentIcon;

  /// Gold for eyebrows, section numbers and progress.
  final Color gold;

  /// Primary call-to-action fill and the ink placed on it.
  final Color ctaFill;
  final Color ctaInk;

  const ReaderPalette._({
    required this.isDark,
    required this.page,
    required this.card,
    required this.raised,
    required this.hairline,
    required this.outline,
    required this.text,
    required this.muted,
    required this.dim,
    required this.accentIcon,
    required this.gold,
    required this.ctaFill,
    required this.ctaInk,
  });

  static const Color _darkCard = Color(0xFF17171C);
  static const Color _darkRaised = Color(0xFF1F1F27);
  static const Color _darkText = Color(0xFFF2F2F4);
  static const Color _darkMuted = Color(0xFF9CA3AF);
  static const Color _darkDim = Color(0xFF6B6B75);
  static const Color _darkAccent = Color(0xFFA9A6F5);

  static const Color _lightInk = Color(0xFF16161D);
  static const Color _lightRaised = Color(0xFFEEEEF4);
  static const Color _lightMuted = Color(0xFF5B6070);
  static const Color _lightDim = Color(0xFF8A8F9C);

  /// Selected-state fill (both themes); everything on it is white.
  static const Color selectedFill = AppColors.brandPrimary;

  factory ReaderPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (isDark) {
      return ReaderPalette._(
        isDark: true,
        page: theme.scaffoldBackgroundColor,
        card: _darkCard,
        raised: _darkRaised,
        hairline: Colors.white.withValues(alpha: 0.07),
        outline: Colors.white.withValues(alpha: 0.14),
        text: _darkText,
        muted: _darkMuted,
        dim: _darkDim,
        accentIcon: _darkAccent,
        gold: AppColors.brandGold,
        ctaFill: Colors.white,
        ctaInk: AppColors.brandPrimaryInk,
      );
    }
    return ReaderPalette._(
      isDark: false,
      page: theme.scaffoldBackgroundColor,
      card: Colors.white,
      raised: _lightRaised,
      hairline: _lightInk.withValues(alpha: 0.08),
      outline: _lightInk.withValues(alpha: 0.14),
      text: _lightInk,
      muted: _lightMuted,
      dim: _lightDim,
      accentIcon: AppColors.brandPrimary,
      gold: AppColors.brandGoldDeep,
      ctaFill: AppColors.brandPrimary,
      ctaInk: Colors.white,
    );
  }
}
