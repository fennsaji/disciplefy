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

  /// Accent for icons: the theme's gold (bright on dark, deep on light).
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

  /// Primary call-to-action fill and the ink placed on it: a white pill
  /// with ink text on dark, an ink pill with white text on light.
  final Color ctaFill;
  final Color ctaInk;

  /// Selected-state fill (chosen chip, segment, option) and the ink on it.
  /// Gold in both themes with dark ink, as the design's depth chips.
  final Color selectedFill;
  final Color onSelected;

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
    required this.selectedFill,
    required this.onSelected,
  });

  static const Color _darkCard = Color(0xFF17171C);
  static const Color _darkRaised = Color(0xFF1F1F27);
  static const Color _darkText = Color(0xFFF2F2F4);
  static const Color _darkMuted = Color(0xFF9CA3AF);
  static const Color _darkDim = Color(0xFF86868E);

  /// Ink of the design: light-theme text and primary pill, and the label on
  /// the white dark-theme pill and on gold fills.
  static const Color ink = Color(0xFF1A1917);

  static const Color _lightRaised = Color(0xFFEEEBE3);

  /// Design secondary is #6F6B61; it measures 4.46:1 on the warm raised fill,
  /// so it is nudged one step darker to clear 4.5:1 there.
  static const Color _lightMuted = Color(0xFF6E6A5F);

  /// Design dim is #8A857A (3.5:1 on the page). Hints must stay readable on
  /// the raised fill too, so dim shares the nudged secondary value.
  static const Color _lightDim = Color(0xFF6E6A5F);

  /// Design gold fill on light surfaces.
  static const Color _lightGoldFill = AppColors.brandHighlightDark;

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
        accentIcon: AppColors.brandGold,
        gold: AppColors.brandGold,
        onGold: ink,
        disabledFill: Colors.white.withValues(alpha: 0.10),
        disabledInk: _darkDim,
        ctaFill: Colors.white,
        ctaInk: ink,
        selectedFill: AppColors.brandGold,
        onSelected: ink,
      );
    }
    return ReaderPalette._(
      isDark: false,
      page: page,
      card: Colors.white,
      raised: _lightRaised,
      hairline: ink.withValues(alpha: 0.08),
      outline: ink.withValues(alpha: 0.14),
      text: ink,
      muted: _lightMuted,
      dim: _lightDim,
      accentIcon: AppColors.brandGoldDeep,
      gold: AppColors.brandGoldDeep,
      onGold: Colors.white,
      disabledFill: ink.withValues(alpha: 0.08),
      disabledInk: _lightDim,
      ctaFill: ink,
      ctaInk: Colors.white,
      selectedFill: _lightGoldFill,
      onSelected: ink,
    );
  }
}
