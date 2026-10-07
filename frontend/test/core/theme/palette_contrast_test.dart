import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/contrast.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_post_card.dart';
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
        _expectRatio(palette.onSelected, palette.selectedFill,
            kMinContrastNormalText, 'onSelected on selectedFill');
      });

      test('selected chip label reads clearly (7:1)', () {
        _expectRatio(palette.onSelected, palette.selectedFill, 7.0,
            'onSelected on selectedFill');
      });

      test('secondary text on a selected chip clears the chip floor', () {
        _expectRatio(palette.onSelectedMuted, palette.selectedFill,
            kMinContrastChipLabel, 'onSelectedMuted on selectedFill');
      });

      test('primary action label reads clearly (7:1)', () {
        _expectRatio(palette.ctaInk, palette.ctaFill, 7.0, 'ctaInk on ctaFill');
      });

      test('gold label on a gold tint clears the chip floor', () {
        for (final alpha in [0.08, 0.12, 0.14, 0.16]) {
          for (final surface in surfaces.entries) {
            if (surface.key == 'raised') continue;
            final tint =
                _over(palette.gold.withValues(alpha: alpha), surface.value);
            _expectRatio(palette.goldOnTint, tint, kMinContrastChipLabel,
                'goldOnTint on gold ${alpha * 100}% over ${surface.key}');
          }
        }
        _expectRatio(palette.goldOnTint, palette.raised, kMinContrastChipLabel,
            'goldOnTint on raised');
      });

      test('gold graphics clear 3:1 on the page, card and raised fill', () {
        for (final surface in surfaces.values) {
          _expectRatio(palette.accentIcon, surface, kMinContrastLargeText,
              'accentIcon (radio, slider, progress, switch track)');
        }
      });

      test('switch thumb keeps 3:1 on the selected track', () {
        final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
        const on = {WidgetState.selected};
        _expectRatio(
            theme.switchTheme.thumbColor!.resolve(on)!,
            theme.switchTheme.trackColor!.resolve(on)!,
            kMinContrastLargeText,
            'switch thumb on track');
      });

      test('chip labels on tinted accents clear the chip floor', () {
        final accents = <Color>[
          palette.gold,
          palette.accentIcon,
          for (final type in [
            'prayer',
            'praise',
            'question',
            'study_note',
            'shared_guide',
            'daily',
            'general'
          ])
            postTypeAccentColor(type, isDark: isDark),
        ];
        for (final accent in accents) {
          for (final alpha in [0.10, 0.14]) {
            final ink = palette.onTint(accent, alpha: alpha);
            final fill = _over(accent.withValues(alpha: alpha), palette.card);
            _expectRatio(ink, fill, kMinContrastChipLabel,
                'onTint(${accent.toARGB32().toRadixString(16)}) at $alpha');
          }
        }
      });

      test('status labels on their own tint clear the chip floor', () {
        final status = isDark
            ? {
                AppColors.success: AppColors.successLighter,
                AppColors.error: AppColors.errorLighter,
                AppColors.warning: AppColors.warningLighter,
              }
            : {
                AppColors.success: AppColors.successDark,
                AppColors.error: AppColors.errorDark,
                AppColors.warning: AppColors.warningDark,
              };
        status.forEach((base, ink) {
          for (final surface in surfaces.entries) {
            final alpha = isDark ? 0.14 : 0.10;
            final label = palette.onTint(ink,
                tint: base, alpha: alpha, ground: surface.value);
            _expectRatio(
                label,
                _over(base.withValues(alpha: alpha), surface.value),
                kMinContrastChipLabel,
                'status ${ink.toARGB32().toRadixString(16)} on tint over '
                '${surface.key}');
          }
          // Light status text as-is on the page and card (no helper).
          if (!isDark) {
            _expectRatio(ink, palette.page, kMinContrastChipLabel,
                'status ${ink.toARGB32().toRadixString(16)} on page');
            _expectRatio(
                _over(ink, palette.card),
                _over(base.withValues(alpha: 0.14), palette.page),
                kMinContrastChipLabel,
                'status ${ink.toARGB32().toRadixString(16)} on 14% tint');
          }
        });
      });

      test('disabled action label keeps 3:1 on its fill', () {
        final fill = _over(palette.disabledFill, palette.page);
        _expectRatio(palette.disabledInk, fill, kMinContrastLargeText,
            'disabledInk on disabledFill');
      });
    });
  }

  group('Fills with white or ink labels', () {
    test('white on the solid status fills', () {
      for (final fill in [
        AppColors.successDark,
        AppColors.errorDark,
        AppColors.warningDark,
      ]) {
        _expectRatio(Colors.white, fill, 7.0,
            'white on ${fill.toARGB32().toRadixString(16)}');
      }
    });

    test('ink on the bright gold fills', () {
      for (final fill in [AppColors.brandGold, AppColors.brandHighlightDark]) {
        _expectRatio(ReaderPalette.ink, fill, 7.0,
            'ink on ${fill.toARGB32().toRadixString(16)}');
      }
    });

    test('white on the deep gold clears AA (icons and large text only)', () {
      _expectRatio(
          Colors.white, AppColors.brandGoldDeep, 4.5, 'white on deep gold');
    });

    test('Official pill label on the cream fill', () {
      _expectRatio(AppColors.brandGoldInk, AppColors.brandHighlight,
          kMinContrastChipLabel, 'brandGoldInk on brandHighlight');
    });

    test('light input focus ring clears 3:1 on the white field', () {
      _expectRatio(AppColors.brandGoldMark, AppColors.lightSurface,
          kMinContrastLargeText, 'focus ring');
    });
  });

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
