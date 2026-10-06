import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/contrast.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/simple/language_pill.dart';

/// Composites a possibly translucent [top] over an opaque [bottom].
Color _over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

void _expectRatio(Color fg, Color bg, double min, String role) {
  final ratio = contrastRatio(_over(fg, bg), bg);
  expect(ratio, greaterThanOrEqualTo(min),
      reason: '$role measures ${ratio.toStringAsFixed(2)}:1, needs $min:1');
}

void main() {
  const pages = {
    'light': AppColors.lightScaffold,
    'dark': AppColors.darkScaffold,
  };

  for (final entry in pages.entries) {
    final isDark = entry.key == 'dark';
    final palette = ReaderPalette.resolve(isDark: isDark, page: entry.value);
    final surfaces = {
      'page': palette.page,
      'card': palette.card,
      'raised': palette.raised,
    };

    group('ReaderPalette ${entry.key}', () {
      for (final surface in surfaces.entries) {
        test('text roles are readable on ${surface.key}', () {
          const min = kMinContrastNormalText;
          _expectRatio(palette.text, surface.value, min, 'text');
          _expectRatio(palette.muted, surface.value, min, 'muted');
          _expectRatio(palette.dim, surface.value, min, 'dim (hint)');
        });
      }

      test('gold text is readable on the page and the card', () {
        _expectRatio(
            palette.gold, palette.page, kMinContrastNormalText, 'gold on page');
        _expectRatio(
            palette.gold, palette.card, kMinContrastNormalText, 'gold on card');
      });

      test('on-gold text is readable on the gold fill', () {
        _expectRatio(palette.onGold, palette.gold, kMinContrastNormalText,
            'onGold on gold');
      });

      test('primary action label is readable on its fill', () {
        _expectRatio(palette.ctaInk, palette.ctaFill, kMinContrastNormalText,
            'ctaInk on ctaFill');
      });

      test('selected-fill label is readable', () {
        _expectRatio(Colors.white, ReaderPalette.selectedFill,
            kMinContrastNormalText, 'white on selectedFill');
      });

      test('disabled action label keeps 3:1 on its fill', () {
        final fill = _over(palette.disabledFill, palette.page);
        _expectRatio(palette.disabledInk, fill, kMinContrastLargeText,
            'disabledInk on disabledFill');
      });
    });
  }

  group('AppColors text roles', () {
    test('light text roles on the light page and surface', () {
      for (final bg in [AppColors.lightScaffold, AppColors.lightSurface]) {
        _expectRatio(AppColors.lightTextPrimary, bg, 4.5, 'lightTextPrimary');
        _expectRatio(
            AppColors.lightTextSecondary, bg, 4.5, 'lightTextSecondary');
        _expectRatio(AppColors.lightTextTertiary, bg, 4.5, 'lightTextTertiary');
        _expectRatio(AppColors.brandGoldDeep, bg, 4.5, 'brandGoldDeep');
      }
    });

    test('dark text roles on the dark page and surface', () {
      for (final bg in [AppColors.darkScaffold, AppColors.darkSurface]) {
        _expectRatio(AppColors.darkTextPrimary, bg, 4.5, 'darkTextPrimary');
        _expectRatio(AppColors.darkTextSecondary, bg, 4.5, 'darkTextSecondary');
        _expectRatio(AppColors.darkTextTertiary, bg, 4.5, 'darkTextTertiary');
        _expectRatio(AppColors.brandGold, bg, 4.5, 'brandGold');
      }
    });

    test('field placeholders are readable on their fills', () {
      _expectRatio(
          AppColors.darkHintText, AppColors.darkInputFill, 4.5, 'darkHintText');
      _expectRatio(AppColors.lightTextTertiary, AppColors.lightInputFill, 4.5,
          'light hint');
      _expectRatio(
          SearchFieldColors.hint, Colors.white, 4.5, 'Generate field hint');
    });
  });
}
