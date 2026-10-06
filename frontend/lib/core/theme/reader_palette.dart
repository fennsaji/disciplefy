import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';

/// Colours of the editorial "reader" surfaces (study guide, its follow-up
/// chat and end-of-guide blocks) in the Scripture-hero design.
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

  /// Tertiary text, placeholders and hints. Still clears 4.5:1 on the page,
  /// the card and the raised fill.
  final Color dim;

  /// Accent for icons (lavender on dark, indigo on light).
  final Color accentIcon;

  /// Gold for eyebrows, section numbers and progress.
  final Color gold;

  /// Text and icons placed on a [gold] fill (white on the deep light-theme
  /// gold, dark ink on the bright dark-theme gold).
  final Color onGold;

  /// Fill and label of a disabled primary action. The label keeps 3:1 on
  /// the fill so the action stays legible while reading as unavailable.
  final Color disabledFill;
  final Color disabledInk;

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
    required this.onGold,
    required this.disabledFill,
    required this.disabledInk,
    required this.ctaFill,
    required this.ctaInk,
  });

  static const Color _darkCard = Color(0xFF17171C);
  static const Color _darkRaised = Color(0xFF1F1F27);
  static const Color _darkText = Color(0xFFF2F2F4);
  static const Color _darkMuted = Color(0xFF9CA3AF);
  static const Color _darkDim = Color(0xFF86868E);
  static const Color _darkAccent = Color(0xFFA9A6F5);
  static const Color _darkOnGold = Color(0xFF1B1608);

  static const Color _lightInk = Color(0xFF16161D);
  static const Color _lightRaised = Color(0xFFEEEEF4);
  static const Color _lightMuted = Color(0xFF5B6070);
  static const Color _lightDim = Color(0xFF716C64);

  /// Selected-state fill (both themes); everything on it is white.
  static const Color selectedFill = AppColors.brandPrimary;

  factory ReaderPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    return ReaderPalette.resolve(
      isDark: theme.brightness == Brightness.dark,
      page: theme.scaffoldBackgroundColor,
    );
  }

  /// Palette for a brightness without a [BuildContext], for building theme
  /// data. [page] is the scaffold background of that theme.
  factory ReaderPalette.resolve({required bool isDark, required Color page}) {
    if (isDark) {
      return ReaderPalette._(
        isDark: true,
        page: page,
        card: _darkCard,
        raised: _darkRaised,
        hairline: Colors.white.withValues(alpha: 0.07),
        outline: Colors.white.withValues(alpha: 0.14),
        text: _darkText,
        muted: _darkMuted,
        dim: _darkDim,
        accentIcon: _darkAccent,
        gold: AppColors.brandGold,
        onGold: _darkOnGold,
        disabledFill: Colors.white.withValues(alpha: 0.10),
        disabledInk: _darkDim,
        ctaFill: Colors.white,
        ctaInk: AppColors.brandPrimaryInk,
      );
    }
    return ReaderPalette._(
      isDark: false,
      page: page,
      card: Colors.white,
      raised: _lightRaised,
      hairline: _lightInk.withValues(alpha: 0.08),
      outline: _lightInk.withValues(alpha: 0.14),
      text: _lightInk,
      muted: _lightMuted,
      dim: _lightDim,
      accentIcon: AppColors.brandPrimary,
      gold: AppColors.brandGoldDeep,
      onGold: Colors.white,
      disabledFill: _lightInk.withValues(alpha: 0.08),
      disabledInk: _lightDim,
      ctaFill: AppColors.brandPrimary,
      ctaInk: Colors.white,
    );
  }
}
