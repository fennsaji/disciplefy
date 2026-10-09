import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// The app's colours against the owner-approved design
/// (docs/ux/design-final/colour-tokens.md and the PNGs beside it).
///
/// Every expectation is the design value unless the token is listed in
/// [_deviations], where the app is deliberately stricter than the design to
/// keep text at WCAG AA (4.5:1). Each deviation is the smallest nudge that
/// passes; nothing is pushed toward pure black or white.

/// Design values, exactly as read from design-v2.pen.
abstract final class _Design {
  // Dark
  static const darkPage = Color(0xFF121212);
  static const darkCard = Color(0xFF17171C);
  static const darkRaised = Color(0xFF1F1F27);
  static const darkText = Color(0xFFF2F2F4);
  static const darkSecondary = Color(0xFF9CA3AF);
  static const darkIcons = Color(0xFF8A8A95);
  static const darkGold = Color(0xFFE3B154);
  static const darkSuccess = Color(0xFF34D399);
  static const darkError = Color(0xFFF87171);

  // Light
  static const lightPage = Color(0xFFFAF8F5);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightRaised = Color(0xFFEEEBE3);
  static const lightInk = Color(0xFF1A1917);
  static const lightSecondary = Color(0xFF6F6B61);
  static const lightGoldFill = Color(0xFFD4A23A);
}

/// Places the app is stricter than the design, and why. Reviewers: this is
/// the complete list; a token not named here must equal the design value.
const Map<String, String> _deviations = {
  'dark dim (#6B6B75 → #86868E)':
      'design dim measures 3.6:1 on the page; hints and tertiary text need '
          '4.5:1 on the page, card and raised fill.',
  'light secondary in ReaderPalette (#6F6B61 → #6E6A5F)':
      'design secondary measures 4.46:1 on the warm raised fill #EEEBE3; one '
          'step darker reaches 4.53:1. AppColors.lightTextSecondary keeps the '
          'exact #6F6B61 (5.0:1 on the page, 5.3:1 on white).',
  'light dim in ReaderPalette (#8A857A → #6E6A5F)':
      'design dim is 3.5:1 on the page; as text it shares the nudged '
          'secondary value so it also clears the raised fill.',
  'light tertiary text in AppColors (#8A857A → #716C64)':
      'design dim is 3.5:1 on the page; #716C64 is 4.9:1 on the page and '
          'white. #8A857A stays an icon-only value in the design.',
  'light gold text (#9A6B10 → #986910)':
      'design gold text measures 4.42:1 on the page; #986910 is 4.54:1.',
  'dark hint on inputs (#6B6B75 → #919191)':
      'placeholder text on the dark input fill needs 4.5:1.',
  'Generate field placeholder (#B5B0A4 → #7B766D)':
      'design placeholder is 2.1:1 on the white field.',
  'light selected-chip gold (#B8860B → #D4A23A)':
      'ink on the design fill measured 5.4:1 and read as muddy; #D4A23A is '
          '7.6:1. Secondary text on it is ink at 85% (5.8:1), not 80%.',
  'light switch track, radio, slider and progress (gold fill → #986910)':
      'the lighter selected fill is 2.2:1 on the page, under the 3:1 '
          'graphics minimum; the deep gold is 4.5:1 and white on it 4.8:1. '
          'Dark keeps the gold track with an ink thumb (white was 1.9:1).',
  'light input focus ring (gold fill → #BC851F)':
      'the selected fill is 2.3:1 on the white field; the gold mark is 3.2:1.',
  'gold label on a gold tint (light #986910 → #704D0F)':
      'deep gold is about 4:1 on its own 12–16% tint; #704D0F is 5.9:1 on a '
          '16% tint over the page.',
  'light status text (Emerald/Amber/Red-700 → -800)':
      'the -700 values fell to 4.3–5.2:1 on their own tinted chips; -800 '
          'clears 5.5:1 there and keeps white fills above 7:1.',
  'light hairline at 8% ink (design 14%)':
      'separators use 8% and outlines 14%: subtler than the design, never '
          'heavier.',
};

void main() {
  final dark =
      ReaderPalette.resolve(isDark: true, page: AppColors.darkScaffold);
  final light =
      ReaderPalette.resolve(isDark: false, page: AppColors.lightScaffold);

  test('every deviation from the design is documented', () {
    expect(_deviations, isNotEmpty);
    for (final reason in _deviations.values) {
      expect(reason.length, greaterThan(20));
    }
  });

  group('ReaderPalette matches the design (dark)', () {
    final cases = <String, (Color, Color)>{
      'page': (dark.page, _Design.darkPage),
      'card': (dark.card, _Design.darkCard),
      'raised': (dark.raised, _Design.darkRaised),
      'text': (dark.text, _Design.darkText),
      'muted': (dark.muted, _Design.darkSecondary),
      'gold': (dark.gold, _Design.darkGold),
      'accentIcon': (dark.accentIcon, _Design.darkGold),
      'selectedFill': (dark.selectedFill, _Design.darkGold),
      'onSelected': (dark.onSelected, _Design.lightInk),
      'onGold': (dark.onGold, _Design.lightInk),
      'ctaFill (white pill)': (dark.ctaFill, Colors.white),
      'ctaInk': (dark.ctaInk, _Design.lightInk),
      'hairline (white 7%)': (
        dark.hairline,
        Colors.white.withValues(alpha: 0.07)
      ),
      'outline (white 14%)': (
        dark.outline,
        Colors.white.withValues(alpha: 0.14)
      ),
      // Deviation: see _deviations.
      'dim (nudged)': (dark.dim, const Color(0xFF86868E)),
    };
    cases.forEach((name, pair) {
      test(name, () => expect(pair.$1, pair.$2));
    });
  });

  group('ReaderPalette matches the design (light)', () {
    final cases = <String, (Color, Color)>{
      'page': (light.page, _Design.lightPage),
      'card': (light.card, _Design.lightCard),
      'raised': (light.raised, _Design.lightRaised),
      'text': (light.text, _Design.lightInk),
      'selectedFill (gold fill)': (light.selectedFill, _Design.lightGoldFill),
      'onSelected': (light.onSelected, _Design.lightInk),
      'ctaFill (ink pill)': (light.ctaFill, _Design.lightInk),
      'ctaInk': (light.ctaInk, Colors.white),
      'outline (ink 14%)': (
        light.outline,
        _Design.lightInk.withValues(alpha: 0.14)
      ),
      // Deviations: see _deviations.
      'muted (nudged)': (light.muted, const Color(0xFF6E6A5F)),
      'dim (nudged)': (light.dim, const Color(0xFF6E6A5F)),
      'gold text (nudged)': (light.gold, const Color(0xFF986910)),
      'accentIcon (deep gold)': (light.accentIcon, const Color(0xFF986910)),
      'hairline (ink 8%)': (
        light.hairline,
        _Design.lightInk.withValues(alpha: 0.08)
      ),
    };
    cases.forEach((name, pair) {
      test(name, () => expect(pair.$1, pair.$2));
    });
  });

  group('AppColors matches the design', () {
    final cases = <String, (Color, Color)>{
      'darkScaffold': (AppColors.darkScaffold, _Design.darkPage),
      'darkSurface': (AppColors.darkSurface, _Design.darkCard),
      'darkSurfaceVariant': (AppColors.darkSurfaceVariant, _Design.darkRaised),
      'darkTextPrimary': (AppColors.darkTextPrimary, _Design.darkText),
      'darkTextSecondary': (AppColors.darkTextSecondary, _Design.darkSecondary),
      'darkTextTertiary': (AppColors.darkTextTertiary, _Design.darkIcons),
      'brandGold': (AppColors.brandGold, _Design.darkGold),
      'success on dark': (AppColors.successLighter, _Design.darkSuccess),
      'error on dark': (AppColors.errorLighter, _Design.darkError),
      'lightScaffold': (AppColors.lightScaffold, _Design.lightPage),
      'lightSurface': (AppColors.lightSurface, _Design.lightCard),
      'lightSurfaceVariant': (
        AppColors.lightSurfaceVariant,
        _Design.lightRaised
      ),
      'lightTextPrimary': (AppColors.lightTextPrimary, _Design.lightInk),
      'lightTextSecondary': (
        AppColors.lightTextSecondary,
        _Design.lightSecondary
      ),
      'brandHighlightDark (gold fill)': (
        AppColors.brandHighlightDark,
        _Design.lightGoldFill
      ),
    };
    cases.forEach((name, pair) {
      test(name, () => expect(pair.$1, pair.$2));
    });
  });

  for (final isDark in [true, false]) {
    final name = isDark ? 'dark' : 'light';
    final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
    final palette = isDark ? dark : light;
    const none = <WidgetState>{};
    const selected = {WidgetState.selected};

    group('Material theme ($name)', () {
      test('scaffold and card surfaces', () {
        expect(theme.scaffoldBackgroundColor,
            isDark ? _Design.darkPage : _Design.lightPage);
        expect(theme.colorScheme.surface,
            isDark ? _Design.darkCard : _Design.lightCard);
      });

      test('primary is gold, never indigo', () {
        expect(theme.colorScheme.primary,
            isDark ? _Design.darkGold : const Color(0xFF986910));
        expect(theme.colorScheme.onPrimary,
            isDark ? _Design.lightInk : Colors.white);
        expect(theme.colorScheme.tertiary, theme.colorScheme.primary);
      });

      test('FilledButton is the primary pill', () {
        final style = theme.filledButtonTheme.style!;
        expect(style.backgroundColor!.resolve(none),
            isDark ? Colors.white : _Design.lightInk);
        expect(style.foregroundColor!.resolve(none),
            isDark ? _Design.lightInk : Colors.white);
      });

      test('ElevatedButton and FAB follow the primary pill', () {
        final style = theme.elevatedButtonTheme.style!;
        expect(style.backgroundColor!.resolve(none), palette.ctaFill);
        expect(
            theme.floatingActionButtonTheme.backgroundColor, palette.ctaFill);
      });

      test('TextButton links are gold', () {
        expect(theme.textButtonTheme.style!.foregroundColor!.resolve(none),
            isDark ? _Design.darkGold : const Color(0xFF986910));
      });

      test('switch, checkbox, radio, slider and progress are gold', () {
        final gold = isDark ? _Design.darkGold : _Design.lightGoldFill;
        // Graphics that carry state use the accent gold (deep on light) so
        // they clear 3:1 on the page; see _deviations.
        final mark = isDark ? _Design.darkGold : const Color(0xFF986910);
        expect(theme.switchTheme.trackColor!.resolve(selected), mark);
        expect(theme.switchTheme.thumbColor!.resolve(selected),
            isDark ? _Design.lightInk : Colors.white);
        expect(theme.checkboxTheme.fillColor!.resolve(selected), gold);
        expect(theme.radioTheme.fillColor!.resolve(selected), mark);
        expect(theme.sliderTheme.activeTrackColor, mark);
        expect(theme.progressIndicatorTheme.color, mark);
        expect(theme.chipTheme.selectedColor, gold);
      });

      test('input focus and text selection are gold', () {
        final focused = theme.inputDecorationTheme.focusedBorder!;
        expect(focused.borderSide.color,
            isDark ? _Design.darkGold : AppColors.brandGoldMark);
        expect(theme.textSelectionTheme.cursorColor, palette.gold);
      });
    });
  }

  test('no indigo creeps back into lib/', () {
    // Retired indigo/lavender/violet tokens and their raw values, as Color
    // ints (0xFF…) or as '#RRGGBB' strings (defaults, checkout themes). Data
    // that arrives from the API (a path's own colour) is not in lib/.
    const retired = '4F46E5|6366F1|5B4FE9|4338CA|A9A6F5|A5B4FC|F3F0FF|'
        '1E1B4B|3730A3|EEF0FE|EEEEFD|2E28A3|7C3AED|A78BFA|7C4DFF|D8B4FE|'
        'F3E8FF|6D28D9|6A4FB6';
    final banned = RegExp(
      'brandPrimary|brandSecondary|primaryGradient|appBrandAccent|'
      r'appInteractive|AppTheme\.(primaryColor|primaryLightColor|'
      r'secondaryPurple)|(0x[Ff]{2}|#)'
      '($retired)'
      r'\b|Colors\.(indigo|deepPurple|blue)\b',
      caseSensitive: false,
    );
    // Lines that may keep a listed value, with why. The logo and splash are
    // gold on ink and never used the indigo tokens.
    const allowlist = <String, String>{
      // learning-paths.png shows purple path tiles (Growing in Discipleship,
      // The Local Church): the disciple-level tile gradient.
      'lib/features/study_topics/presentation/widgets/path_level_style.dart':
          'static const _disciple =',
    };

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final allowed = allowlist.entries
          .where((e) => entity.path.endsWith(e.key))
          .map((e) => e.value)
          .firstOrNull;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (allowed != null && lines[i].contains(allowed)) continue;
        if (banned.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use ReaderPalette roles (ctaFill/ctaInk, selectedFill/'
            'onSelected, gold, accentIcon) instead:\n${offenders.join('\n')}');
  });
}
